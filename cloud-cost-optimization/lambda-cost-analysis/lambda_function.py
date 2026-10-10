#!/usr/bin/env python3
"""
AWS Lambda Function - Cost Optimization Analysis
This Lambda function runs periodically to analyze costs and send alerts.
Works with mock data for local testing.
"""

import os
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
MOCK_MODE = os.environ.get("MOCK_MODE", "true").lower() == "true"
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
COST_THRESHOLD = float(os.environ.get("COST_THRESHOLD", "1000"))
ANOMALY_THRESHOLD_PCT = float(os.environ.get("ANOMALY_THRESHOLD_PCT", "20"))


@dataclass
class CostAnomaly:
    """Cost anomaly detection result"""

    service: str
    current_cost: float
    expected_cost: float
    deviation_pct: float
    severity: str
    timestamp: str


def get_cost_explorer_client():
    """Get Cost Explorer client"""
    if MOCK_MODE:
        return None
    return boto3.client("ce", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def get_sns_client():
    """Get SNS client"""
    if MOCK_MODE:
        return None
    return boto3.client("sns", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def mock_get_cost_data(days: int = 30) -> Dict[str, Any]:
    """Generate mock cost data"""
    import random

    random.seed(42)  # Consistent mock data

    services = [
        "Amazon Elastic Compute Cloud - Compute",
        "Amazon Simple Storage Service",
        "Amazon Relational Database Service",
        "Amazon CloudWatch",
        "AWS Lambda",
        "Amazon Elastic Load Balancing",
        "Amazon Virtual Private Cloud",
        "Amazon Route 53",
        "AWS Key Management Service",
        "Amazon CloudFront",
    ]

    results = []
    base_date = datetime.now() - timedelta(days=days)

    for i in range(days):
        date = base_date + timedelta(days=i)
        date_str = date.strftime("%Y-%m-%d")

        groups = []
        for service in services:
            # Add some variation with occasional spikes
            base_amount = random.uniform(5, 100)
            if random.random() < 0.05:  # 5% chance of spike
                base_amount *= random.uniform(2, 5)

            groups.append(
                {
                    "Keys": [service],
                    "Metrics": {
                        "UnblendedCost": {"Amount": f"{base_amount:.2f}", "Unit": "USD"}
                    },
                }
            )

        total = sum(float(g["Metrics"]["UnblendedCost"]["Amount"]) for g in groups)
        results.append(
            {
                "TimePeriod": {
                    "Start": date_str,
                    "End": (date + timedelta(days=1)).strftime("%Y-%m-%d"),
                },
                "Total": {"UnblendedCost": {"Amount": f"{total:.2f}", "Unit": "USD"}},
                "Groups": groups,
                "Estimated": False,
            }
        )

    return {"ResultsByTime": results}


def fetch_cost_data(client, days: int = 30) -> Dict[str, Any]:
    """Fetch cost data from Cost Explorer"""
    end_date = datetime.now().strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

    if MOCK_MODE:
        return mock_get_cost_data(days)

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start_date, "End": end_date},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    return response


def detect_anomalies(cost_data: Dict[str, Any]) -> List[CostAnomaly]:
    """Detect cost anomalies using statistical analysis"""
    anomalies = []

    # Group by service
    service_costs = {}
    for result in cost_data.get("ResultsByTime", []):
        date = result["TimePeriod"]["Start"]
        for group in result.get("Groups", []):
            service = group["Keys"][0]
            cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if service not in service_costs:
                service_costs[service] = []
            service_costs[service].append({"date": date, "cost": cost})

    # Analyze each service
    for service, daily_costs in service_costs.items():
        if len(daily_costs) < 7:
            continue

        costs = [d["cost"] for d in daily_costs]
        recent_cost = costs[-1]
        historical_costs = costs[:-1]

        avg_cost = sum(historical_costs) / len(historical_costs)
        std_dev = (
            sum((c - avg_cost) ** 2 for c in historical_costs) / len(historical_costs)
        ) ** 0.5

        if std_dev == 0:
            continue

        z_score = abs(recent_cost - avg_cost) / std_dev
        deviation_pct = (
            abs(recent_cost - avg_cost) / avg_cost * 100 if avg_cost > 0 else 0
        )

        # Flag if deviation > threshold or z-score > 2
        if deviation_pct > ANOMALY_THRESHOLD_PCT or z_score > 2:
            severity = "HIGH" if deviation_pct > 50 or z_score > 3 else "MEDIUM"
            anomalies.append(
                CostAnomaly(
                    service=service,
                    current_cost=recent_cost,
                    expected_cost=avg_cost,
                    deviation_pct=round(deviation_pct, 1),
                    severity=severity,
                    timestamp=datetime.now().isoformat(),
                )
            )

    return anomalies


def check_budget_threshold(cost_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Check if total cost exceeds threshold"""
    latest = (
        cost_data.get("ResultsByTime", [])[-1]
        if cost_data.get("ResultsByTime")
        else None
    )
    if not latest:
        return None

    total_cost = float(latest["Total"]["UnblendedCost"]["Amount"])
    if total_cost > COST_THRESHOLD:
        return {
            "total_cost": total_cost,
            "threshold": COST_THRESHOLD,
            "exceeded_by": round(total_cost - COST_THRESHOLD, 2),
            "period": latest["TimePeriod"],
        }
    return None


def send_alert(message: str, subject: str) -> bool:
    """Send alert via SNS"""
    if MOCK_MODE:
        logger.info(f"MOCK ALERT: {subject}\n{message}")
        return True

    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not configured")
        return False

    try:
        client = get_sns_client()
        client.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject, Message=message)
        return True
    except Exception as e:
        logger.error(f"Failed to send alert: {e}")
        return False


def generate_report(
    cost_data: Dict[str, Any],
    anomalies: List[CostAnomaly],
    budget_alert: Optional[Dict],
) -> str:
    """Generate human-readable report"""
    latest = (
        cost_data.get("ResultsByTime", [])[-1]
        if cost_data.get("ResultsByTime")
        else None
    )
    if not latest:
        return "No cost data available"

    total_cost = float(latest["Total"]["UnblendedCost"]["Amount"])
    period = latest["TimePeriod"]

    lines = [
        "=" * 50,
        "AWS COST OPTIMIZATION REPORT",
        "=" * 50,
        f"Period: {period['Start']} to {period['End']}",
        f"Total Daily Cost: ${total_cost:.2f}",
        f"Threshold: ${COST_THRESHOLD:.2f}",
        "",
        "ANOMALIES DETECTED:" if anomalies else "No anomalies detected",
        "-" * 30,
    ]

    if anomalies:
        for a in anomalies:
            lines.append(
                f"  [{a.severity}] {a.service}: "
                f"${a.current_cost:.2f} vs expected ${a.expected_cost:.2f} "
                f"({a.deviation_pct:+.1f}%)"
            )
    else:
        lines.append("  None")

    lines.extend(["", "BUDGET CHECK:" if budget_alert else "Budget: OK", "-" * 30])

    if budget_alert:
        lines.append(
            f"  ALERT: Daily cost ${budget_alert['total_cost']:.2f} "
            f"exceeds threshold ${budget_alert['threshold']:.2f} "
            f"by ${budget_alert['exceeded_by']:.2f}"
        )
    else:
        lines.append(f"  Daily cost ${total_cost:.2f} within threshold")

    # Top services
    if latest.get("Groups"):
        top_services = sorted(
            latest["Groups"],
            key=lambda g: float(g["Metrics"]["UnblendedCost"]["Amount"]),
            reverse=True,
        )[:5]

        lines.extend(["", "TOP 5 SERVICES:", "-" * 30])
        for g in top_services:
            service = g["Keys"][0]
            cost = float(g["Metrics"]["UnblendedCost"]["Amount"])
            lines.append(f"  {service}: ${cost:.2f}")

    return "\n".join(lines)


def lambda_handler(event, context):
    """Main Lambda handler"""
    logger.info("Starting cost optimization analysis")

    try:
        # Fetch cost data
        client = get_cost_explorer_client()
        cost_data = fetch_cost_data(client)

        # Detect anomalies
        anomalies = detect_anomalies(cost_data)
        logger.info(f"Detected {len(anomalies)} anomalies")

        # Check budget threshold
        budget_alert = check_budget_threshold(cost_data)

        # Generate report
        report = generate_report(cost_data, anomalies, budget_alert)
        logger.info(report)

        # Send alerts if needed
        alerts_sent = 0
        if anomalies:
            high_severity = [a for a in anomalies if a.severity == "HIGH"]
            if high_severity:
                subject = f"[HIGH] Cost Anomaly Alert - {len(high_severity)} services"
                message = report
                if send_alert(message, subject):
                    alerts_sent += 1

        if budget_alert:
            subject = "[ALERT] Daily Cost Threshold Exceeded"
            message = report
            if send_alert(message, subject):
                alerts_sent += 1

        # Return summary
        results = cost_data.get("ResultsByTime", [])
        latest = results[-1] if results else None
        total_cost = float(latest["Total"]["UnblendedCost"]["Amount"]) if latest else 0

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "timestamp": datetime.now().isoformat(),
                    "total_cost": total_cost,
                    "anomalies_detected": len(anomalies),
                    "high_severity_anomalies": len(
                        [a for a in anomalies if a.severity == "HIGH"]
                    ),
                    "budget_alert": budget_alert is not None,
                    "alerts_sent": alerts_sent,
                    "mock_mode": MOCK_MODE,
                }
            ),
        }

    except Exception as e:
        logger.error(f"Error in cost optimization: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps(
                {"error": str(e), "timestamp": datetime.now().isoformat()}
            ),
        }


# For local testing
if __name__ == "__main__":
    import sys

    os.environ["MOCK_MODE"] = "true"
    os.environ["COST_THRESHOLD"] = "50"
    os.environ["ANOMALY_THRESHOLD_PCT"] = "20"

    class MockContext:
        def __init__(self):
            self.function_name = "cost-optimization"
            self.memory_limit_in_mb = 256
            self.invoked_function_arn = (
                "arn:aws:lambda:us-east-1:123456789:function:cost-optimization"
            )
            self.aws_request_id = "test-request-id"

    result = lambda_handler({}, MockContext())
    print(json.dumps(result, indent=2))
