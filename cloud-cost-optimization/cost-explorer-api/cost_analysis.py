#!/usr/bin/env python3
"""
AWS Cost Explorer API - Cost Analysis Script
This script fetches and analyzes AWS costs using the Cost Explorer API.
Works with mock data for local development.
"""

import os
import json
import boto3
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class CostData:
    """Cost data for a specific period and service"""
    period_start: str
    period_end: str
    service: str
    amount: float
    unit: str
    usage_type: str = ""
    operation: str = ""


@dataclass
class CostSummary:
    """Summary of costs for a period"""
    period_start: str
    period_end: str
    total_cost: float
    currency: str
    service_breakdown: Dict[str, float]
    daily_costs: List[Dict[str, Any]]


class CostExplorerClient:
    """Client for AWS Cost Explorer API with mock support"""

    def __init__(self, use_mock: bool = False, region: str = "us-east-1"):
        self.use_mock = use_mock
        self.region = region
        if not use_mock:
            self.client = boto3.client('ce', region_name=region)
        else:
            self.client = None

    def get_cost_and_usage(
        self,
        start_date: str,
        end_date: str,
        granularity: str = "DAILY",
        metrics: List[str] = None,
        group_by: List[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """Get cost and usage data"""
        if metrics is None:
            metrics = ["UnblendedCost"]
        if group_by is None:
            group_by = [{"Type": "DIMENSION", "Key": "SERVICE"}]

        if self.use_mock:
            return self._mock_cost_data(start_date, end_date, granularity, group_by)

        response = self.client.get_cost_and_usage(
            TimePeriod={"Start": start_date, "End": end_date},
            Granularity=granularity,
            Metrics=metrics,
            GroupBy=group_by
        )
        return response

    def get_cost_forecast(
        self,
        start_date: str,
        end_date: str,
        metric: str = "UNBLENDED_COST",
        granularity: str = "MONTHLY"
    ) -> Dict[str, Any]:
        """Get cost forecast"""
        if self.use_mock:
            return self._mock_forecast(start_date, end_date)

        response = self.client.get_cost_forecast(
            TimePeriod={"Start": start_date, "End": end_date},
            Metric=metric,
            Granularity=granularity
        )
        return response

    def get_reservation_utilization(self) -> Dict[str, Any]:
        """Get RI utilization"""
        if self.use_mock:
            return self._mock_reservation_utilization()

        response = self.client.get_reservation_utilization()
        return response

    def get_savings_plans_utilization(self) -> Dict[str, Any]:
        """Get Savings Plans utilization"""
        if self.use_mock:
            return self._mock_savings_plans_utilization()

        response = self.client.get_savings_plans_utilization()
        return response

    def _mock_cost_data(
        self,
        start_date: str,
        end_date: str,
        granularity: str,
        group_by: List[Dict[str, str]]
    ) -> Dict[str, Any]:
        """Generate mock cost data for local testing"""
        import random

        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
        days = (end - start).days + 1

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
            "Amazon CloudFront"
        ]

        results_by_time = []

        for i in range(days):
            current_date = start + timedelta(days=i)
            date_str = current_date.strftime("%Y-%m-%d")

            groups = []
            for service in services:
                # Random cost between $0.50 and $50 per day per service
                amount = round(random.uniform(0.5, 50.0), 2)
                groups.append({
                    "Keys": [service],
                    "Metrics": {
                        "UnblendedCost": {
                            "Amount": f"{amount:.2f}",
                            "Unit": "USD"
                        }
                    }
                })

            results_by_time.append({
                "TimePeriod": {
                    "Start": date_str,
                    "End": (current_date + timedelta(days=1)).strftime("%Y-%m-%d")
                },
                "Total": {
                    "UnblendedCost": {
                        "Amount": f"{sum(float(g['Metrics']['UnblendedCost']['Amount']) for g in groups):.2f}",
                        "Unit": "USD"
                    }
                },
                "Groups": groups,
                "Estimated": False
            })

        return {
            "ResultsByTime": results_by_time,
            "DimensionValueAttributes": []
        }

    def _mock_forecast(self, start_date: str, end_date: str) -> Dict[str, Any]:
        """Generate mock forecast data"""
        import random
        total = round(random.uniform(1000, 5000), 2)
        return {
            "Total": {
                "Amount": f"{total:.2f}",
                "Unit": "USD"
            },
            "ForecastResultsByTime": [
                {
                    "TimePeriod": {
                        "Start": start_date,
                        "End": end_date
                    },
                    "MeanValue": f"{total:.2f}",
                    "PredictionIntervalLowerBound": f"{total * 0.8:.2f}",
                    "PredictionIntervalUpperBound": f"{total * 1.2:.2f}"
                }
            ]
        }

    def _mock_reservation_utilization(self) -> Dict[str, Any]:
        """Generate mock RI utilization data"""
        return {
            "UtilizationsByTime": [
                {
                    "TimePeriod": {
                        "Start": "2024-01-01",
                        "End": "2024-01-31"
                    },
                    "Groups": [
                        {
                            "Key": "Amazon Elastic Compute Cloud - Compute",
                            "Value": {
                                "UtilizationPercentage": "78.5",
                                "PurchasedHours": "720.0",
                                "TotalActualHours": "565.2",
                                "UnusedHours": "154.8",
                                "NetRISavings": "1250.00",
                                "OnDemandCostOfRIHoursUsed": "2100.00"
                            }
                        }
                    ]
                }
            ],
            "Total": {
                "UtilizationPercentage": "78.5",
                "PurchasedHours": "720.0",
                "TotalActualHours": "565.2",
                "UnusedHours": "154.8",
                "NetRISavings": "1250.00",
                "OnDemandCostOfRIHoursUsed": "2100.00"
            }
        }

    def _mock_savings_plans_utilization(self) -> Dict[str, Any]:
        """Generate mock Savings Plans utilization data"""
        return {
            "SavingsPlansUtilizationsByTime": [
                {
                    "TimePeriod": {
                        "Start": "2024-01-01",
                        "End": "2024-01-31"
                    },
                    "Utilization": {
                        "TotalCommitment": "5000.00",
                        "UsedCommitment": "4200.00",
                        "UnusedCommitment": "800.00",
                        "UtilizationPercentage": "84.0"
                    }
                }
            ],
            "Total": {
                "Utilization": {
                    "TotalCommitment": "5000.00",
                    "UsedCommitment": "4200.00",
                    "UnusedCommitment": "800.00",
                    "UtilizationPercentage": "84.0"
                }
            }
        }


def parse_cost_data(response: Dict[str, Any]) -> List[CostData]:
    """Parse Cost Explorer response into CostData objects"""
    costs = []
    for result in response.get("ResultsByTime", []):
        period_start = result["TimePeriod"]["Start"]
        period_end = result["TimePeriod"]["End"]

        for group in result.get("Groups", []):
            service = group["Keys"][0] if group["Keys"] else "Unknown"
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            unit = group["Metrics"]["UnblendedCost"]["Unit"]

            costs.append(CostData(
                period_start=period_start,
                period_end=period_end,
                service=service,
                amount=amount,
                unit=unit
            ))

    return costs


def generate_summary(costs: List[CostData]) -> CostSummary:
    """Generate cost summary from cost data"""
    if not costs:
        return CostSummary("", "", 0.0, "USD", {}, [])

    period_start = min(c.period_start for c in costs)
    period_end = max(c.period_end for c in costs)

    service_breakdown = defaultdict(float)
    daily_totals = defaultdict(float)

    for cost in costs:
        service_breakdown[cost.service] += cost.amount
        daily_totals[cost.period_start] += cost.amount

    daily_costs = [
        {"date": date, "cost": round(amount, 2)}
        for date, amount in sorted(daily_totals.items())
    ]

    total_cost = sum(c.amount for c in costs)

    return CostSummary(
        period_start=period_start,
        period_end=period_end,
        total_cost=round(total_cost, 2),
        currency="USD",
        service_breakdown={k: round(v, 2) for k, v in service_breakdown.items()},
        daily_costs=daily_costs
    )


def analyze_costs(costs: List[CostData]) -> Dict[str, Any]:
    """Analyze costs and generate recommendations"""
    summary = generate_summary(costs)

    # Top services by cost
    top_services = sorted(
        summary.service_breakdown.items(),
        key=lambda x: x[1],
        reverse=True
    )[:5]

    # Daily trend
    daily_costs = summary.daily_costs
    if len(daily_costs) >= 2:
        recent_avg = sum(d["cost"] for d in daily_costs[-3:]) / 3
        earlier_avg = sum(d["cost"] for d in daily_costs[:3]) / 3
        trend = "increasing" if recent_avg > earlier_avg else "decreasing"
        trend_pct = abs((recent_avg - earlier_avg) / earlier_avg * 100) if earlier_avg > 0 else 0
    else:
        trend = "unknown"
        trend_pct = 0

    # Recommendations
    recommendations = []

    # Check for high-cost services
    for service, cost in top_services:
        if cost > summary.total_cost * 0.3:
            recommendations.append({
                "type": "high_cost_service",
                "priority": "high",
                "service": service,
                "cost": cost,
                "percentage": round(cost / summary.total_cost * 100, 1),
                "recommendation": f"Review {service} usage - consider reserved instances or savings plans"
            })

    # Check RI utilization
    if summary.service_breakdown.get("Amazon Elastic Compute Cloud - Compute", 0) > 100:
        recommendations.append({
            "type": "ri_optimization",
            "priority": "medium",
            "recommendation": "EC2 costs are significant - review Reserved Instance coverage"
        })

    # Check trend
    if trend == "increasing" and trend_pct > 20:
        recommendations.append({
            "type": "cost_trend",
            "priority": "high",
            "recommendation": f"Costs increasing by {trend_pct:.1f}% - investigate recent changes"
        })

    return {
        "summary": asdict(summary),
        "top_services": [{"service": s, "cost": c} for s, c in top_services],
        "trend": {"direction": trend, "percentage": round(trend_pct, 1)},
        "recommendations": recommendations
    }


def print_report(analysis: Dict[str, Any], output_format: str = "text"):
    """Print cost analysis report"""
    if output_format == "json":
        print(json.dumps(analysis, indent=2))
        return

    summary = analysis["summary"]
    print("=" * 60)
    print("AWS COST ANALYSIS REPORT")
    print("=" * 60)
    print(f"Period: {summary['period_start']} to {summary['period_end']}")
    print(f"Total Cost: ${summary['total_cost']:.2f} {summary['currency']}")
    print(f"Trend: {analysis['trend']['direction']} ({analysis['trend']['percentage']:.1f}%)")
    print()

    print("TOP 5 SERVICES BY COST:")
    print("-" * 40)
    for i, item in enumerate(analysis["top_services"], 1):
        pct = (item["cost"] / summary["total_cost"] * 100) if summary["total_cost"] > 0 else 0
        print(f"{i}. {item['service']}: ${item['cost']:.2f} ({pct:.1f}%)")
    print()

    print("SERVICE BREAKDOWN:")
    print("-" * 40)
    for service, cost in sorted(summary["service_breakdown"].items(), key=lambda x: x[1], reverse=True):
        pct = (cost / summary["total_cost"] * 100) if summary["total_cost"] > 0 else 0
        print(f"  {service}: ${cost:.2f} ({pct:.1f}%)")
    print()

    print("RECOMMENDATIONS:")
    print("-" * 40)
    for rec in analysis["recommendations"]:
        print(f"  [{rec['priority'].upper()}] {rec['recommendation']}")
        if "service" in rec:
            print(f"    Service: {rec['service']} (${rec['cost']:.2f}, {rec['percentage']:.1f}%)")
    print()

    print("DAILY COSTS (Last 7 days):")
    print("-" * 40)
    for day in summary["daily_costs"][-7:]:
        print(f"  {day['date']}: ${day['cost']:.2f}")


def main():
    parser = argparse.ArgumentParser(description="AWS Cost Explorer Analysis")
    parser.add_argument("--start-date", help="Start date (YYYY-MM-DD)", default=(datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d"))
    parser.add_argument("--end-date", help="End date (YYYY-MM-DD)", default=datetime.now().strftime("%Y-%m-%d"))
    parser.add_argument("--region", help="AWS region", default="us-east-1")
    parser.add_argument("--mock", action="store_true", help="Use mock data for local testing")
    parser.add_argument("--output", choices=["text", "json"], default="text", help="Output format")
    parser.add_argument("--granularity", choices=["DAILY", "MONTHLY"], default="DAILY", help="Granularity")
    args = parser.parse_args()

    print(f"Fetching cost data from {args.start_date} to {args.end_date}...")
    if args.mock:
        print("Using MOCK data for local development")

    client = CostExplorerClient(use_mock=args.mock, region=args.region)

    response = client.get_cost_and_usage(
        start_date=args.start_date,
        end_date=args.end_date,
        granularity=args.granularity
    )

    costs = parse_cost_data(response)
    analysis = analyze_costs(costs)

    print_report(analysis, args.output)

    # Also fetch forecast
    print("\nFetching forecast...")
    forecast = client.get_cost_forecast(
        start_date=datetime.now().strftime("%Y-%m-%d"),
        end_date=(datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d")
    )

    if args.output == "json":
        print(json.dumps({"forecast": forecast}, indent=2))
    else:
        total = forecast.get("Total", {})
        print(f"Forecasted cost for next 30 days: ${total.get('Amount', 'N/A')} {total.get('Unit', 'USD')}")


if __name__ == "__main__":
    main()