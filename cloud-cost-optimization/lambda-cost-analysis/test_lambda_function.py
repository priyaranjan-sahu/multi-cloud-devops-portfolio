"""Unit tests for the cost-optimization Lambda function (mock mode)."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lambda_function as lf


def test_mock_cost_data_shape():
    data = lf.mock_get_cost_data(days=3)
    assert len(data["ResultsByTime"]) == 3
    latest = data["ResultsByTime"][-1]
    assert "Total" in latest
    assert latest["Groups"]


def test_detect_anomalies_returns_list():
    data = lf.mock_get_cost_data(days=30)
    anomalies = lf.detect_anomalies(data)
    assert isinstance(anomalies, list)


def test_check_budget_threshold_exceeded():
    cost_data = {
        "ResultsByTime": [
            {
                "Total": {"UnblendedCost": {"Amount": "9999.00", "Unit": "USD"}},
                "TimePeriod": {"Start": "2024-01-01", "End": "2024-01-02"},
            }
        ]
    }
    original = lf.COST_THRESHOLD
    lf.COST_THRESHOLD = 100.0
    try:
        result = lf.check_budget_threshold(cost_data)
        assert result is not None
        assert result["exceeded_by"] == 9899.0
    finally:
        lf.COST_THRESHOLD = original


def test_check_budget_threshold_within_limit():
    cost_data = {
        "ResultsByTime": [
            {
                "Total": {"UnblendedCost": {"Amount": "1.00", "Unit": "USD"}},
                "TimePeriod": {"Start": "2024-01-01", "End": "2024-01-02"},
            }
        ]
    }
    original = lf.COST_THRESHOLD
    lf.COST_THRESHOLD = 100.0
    try:
        assert lf.check_budget_threshold(cost_data) is None
    finally:
        lf.COST_THRESHOLD = original


def test_generate_report_contains_sections():
    data = lf.mock_get_cost_data(days=5)
    report = lf.generate_report(data, lf.detect_anomalies(data), None)
    assert "AWS COST OPTIMIZATION REPORT" in report
    assert "TOP 5 SERVICES" in report


def test_send_alert_mock_mode():
    original = lf.MOCK_MODE
    lf.MOCK_MODE = True
    try:
        assert lf.send_alert("message", "subject") is True
    finally:
        lf.MOCK_MODE = original


def test_lambda_handler_returns_total_cost():
    """Regression test for the NameError on the previously undefined `latest`."""
    result = lf.lambda_handler({}, None)
    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert "total_cost" in body
    assert body["total_cost"] > 0
    assert body["mock_mode"] is True
