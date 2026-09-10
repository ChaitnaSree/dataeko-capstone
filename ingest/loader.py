"""
CSV -> Postgres loader.

Reads data/orders.csv, validates each row, inserts the good ones and writes the
bad ones to evidence/rejected.csv with a reason.

The file has deliberately malformed rows. It must NOT crash on them.
"""
import csv
import sys
from pathlib import Path
from datetime import datetime

import requests


def fetch_reference(url):
    """Fetch the drinks reference list from the running API."""
    # DEFECT: no timeout. Week 2 told you what happens on the day the
    # server accepts the connection and then says nothing at all.
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()


def read_rows(path):
    """Yield one dictionary for each CSV row."""
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        yield from reader


def validate(row):
    """Return (True, "") for valid rows or (False, reason) for invalid rows."""
    required_fields = [
        "order_id",
        "customer_id",
        "drink_id",
        "store_id",
        "qty",
        "ordered_at",
        "status",
    ]
    if None in row:
        return False, "row has extra fields"

    for field in required_fields:
        if not (row.get(field) or "").strip():
            return False, f"{field} is required"

    try:
        int(row["order_id"])
        int(row["customer_id"])
        int(row["drink_id"])
        int(row["store_id"])
    except ValueError:
        return False, "IDs must be integers"

    drink_id = int(row["drink_id"])
    if not 1 <= drink_id <= 15:
        return False, "drink_id must be between 1 and 15"

    try:
        qty = int(row["qty"])
    except ValueError:
        return False, "qty must be an integer"

    if qty <= 0:
        return False, "qty must be greater than 0"

    try:
        datetime.fromisoformat(row["ordered_at"])
    except ValueError:
        return False, "ordered_at must be a valid ISO datetime"

    allowed_statuses = {"placed", "ready", "collected", "cancelled"}

    if row["status"] not in allowed_statuses:
        return False, f"invalid status: {row['status']}"

    return True, ""


def load(path):
    """TODO (Phase 1): insert good rows, write rejects, print a summary."""
    raise NotImplementedError("Phase 1: implement load")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python ingest/loader.py <csv-path>", file=sys.stderr)
        sys.exit(2)
    load(Path(sys.argv[1]))
