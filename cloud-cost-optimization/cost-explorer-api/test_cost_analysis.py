"""Unit tests for the Cost Explorer analysis script (mock mode)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cost_analysis as ca


def _response(num_days=2):
    groups = [
        {
            "Keys": ["Amazon Simple Storage Service"],
            "Metrics": {"UnblendedCost": {"Amount": "10.00", "Unit": "USD"}},
        },
        {
            "Keys": ["AWS Lambda"],
            "Metrics": {"UnblendedCost": {"Amount": "5.50", "Unit": "USD"}},
        },
    ]
    by_time = []
    for i in range(num_days):
        by_time.append(
            {
                "TimePeriod": {
                    "Start": f"2024-01-0{i + 1}",
                    "End": f"2024-01-0{i + 2}",
                },
                "Total": {"UnblendedCost": {"Amount": "15.50", "Unit": "USD"}},
                "Groups": groups,
                "Estimated": False,
            }
        )
    return {"ResultsByTime": by_time}


def test_parse_cost_data_extracts_all_groups():
    costs = ca.parse_cost_data(_response())
    assert len(costs) == 4
    assert {c.service for c in costs} == {
        "Amazon Simple Storage Service",
        "AWS Lambda",
    }
    assert all(isinstance(c.amount, float) for c in costs)


def test_generate_summary_totals_and_breakdown():
    summary = ca.generate_summary(ca.parse_cost_data(_response()))
    assert summary.total_cost == 31.0
    assert summary.currency == "USD"
    assert summary.service_breakdown["AWS Lambda"] == 11.0
    assert summary.service_breakdown["Amazon Simple Storage Service"] == 20.0
    assert summary.period_start == "2024-01-01"
    assert summary.period_end == "2024-01-03"


def test_generate_summary_empty():
    summary = ca.generate_summary([])
    assert summary.total_cost == 0.0
    assert summary.service_breakdown == {}
    assert summary.daily_costs == []


def test_analyze_costs_flags_dominant_service():
    analysis = ca.analyze_costs(ca.parse_cost_data(_response()))
    types = {r["type"] for r in analysis["recommendations"]}
    assert "high_cost_service" in types
    assert analysis["top_services"][0]["service"] == "Amazon Simple Storage Service"


def test_client_mock_endpoints():
    client = ca.CostExplorerClient(use_mock=True)
    assert "ResultsByTime" in client.get_cost_and_usage("2024-01-01", "2024-01-05")
    assert "Total" in client.get_cost_forecast("2024-01-01", "2024-01-31")
    assert "UtilizationsByTime" in client.get_reservation_utilization()
    assert "SavingsPlansUtilizationsByTime" in client.get_savings_plans_utilization()
