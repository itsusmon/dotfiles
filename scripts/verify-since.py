#!/usr/bin/env python3
"""Run with: python3 scripts/verify-since.py"""

import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import time
from datetime import datetime


script = Path(__file__).parent / "bin" / "since"
loader = importlib.machinery.SourceFileLoader("since", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
since = importlib.util.module_from_spec(spec)
loader.exec_module(since)
now = datetime(2026, 10, 5, 13, 34, 56)

cases = {
    "06-10-2026": "1 day",
    "6-10-2026": "1 day",
    "6-10-26": "1 day",
    "6/10/26": "1 day",
    "6.10.2026": "1 day",
    "6 10 26": "1 day",
    "2026-10-06": "1 day",
    "6 Oct 2026": "1 day",
    "October 6th, 26": "1 day",
    "on 6-Oct-26": "1 day",
    "6 Oct": "1 day",
    "6/10": "1 day",
    "today": "0 days",
    "yesterday": "1 day",
    "tomorrow": "1 day",
    "4-10-26 12:34": "1 day, 1 hour",
    "4-10-26 12:34:55": "1 day, 1 hour, 1 second",
    "6-10-26 12:34": "22 hours, 59 minutes",
    "2026-10-04T12:34:55": "1 day, 1 hour, 1 second",
    "4 Oct 2026 at 1:34pm": "1 day",
    "October 4th, 2026, at 1:34 p.m.": "1 day",
    "4/10/26 12.34": "1 day, 1 hour",
    "4/10/26 1234": "1 day, 1 hour",
    "4/10/26 123455": "1 day, 1 hour, 1 second",
    "today 1:2 pm": "32 minutes",
    "today 12am": "13 hours, 34 minutes",
    "today 12pm": "1 hour, 34 minutes",
    "12:34": "1 hour",
    "1pm": "34 minutes",
    "today 13": "34 minutes",
    "now": "0 minutes",
    "29-2-2024": "949 days",
}
for value, expected in cases.items():
    actual = since.difference(value, now)
    assert actual == expected, (value, actual, expected)

invalid = (
    "", "nonsense", "31-2-26", "29-2-25", "6-13-26", "0-10-26",
    "6-10-123", "6-10-26 25:00", "6-10-26 12:60", "6-10-26 12:34:60",
    "6-10-26 0pm", "6-10-26 13pm", "6-10-26 2560", "6-10-26 123460",
    "6-10-26 12:34 junk",
)
for value in invalid:
    try:
        since.difference(value, now)
    except ValueError:
        pass
    else:
        raise AssertionError(f"Accepted invalid input: {value!r}")

# Calendar days and elapsed hours differ across a daylight-saving transition.
if hasattr(time, "tzset"):
    original_zone = os.environ.get("TZ")
    try:
        os.environ["TZ"] = "America/New_York"
        time.tzset()
        spring_now = datetime(2026, 3, 9)
        assert since.difference("8-3-26", spring_now) == "1 day"
        assert since.difference("8-3-26 00:00", spring_now) == "23 hours"
        try:
            since.difference("8-3-26 02:30", spring_now)
        except ValueError:
            pass
        else:
            raise AssertionError("Accepted a nonexistent local time")
    finally:
        if original_zone is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = original_zone
        time.tzset()

# Exercise the actual terminal entry point, including unquoted arguments and errors.
for arguments, expected_code, expected_output in (
    (["today"], 0, "0 days"),
    (["yesterday"], 0, "1 day"),
    (["6", "Oct", "2026", "at", "12:34"], 0, None),
    (["31-2-26"], 2, None),
    ([], 2, None),
    (["--help"], 0, None),
):
    result = subprocess.run([sys.executable, str(script), *arguments], capture_output=True, text=True)
    assert result.returncode == expected_code, result
    assert "Traceback" not in result.stderr, result.stderr
    if expected_output is not None:
        assert result.stdout.strip() == expected_output, result.stdout

print(f"Passed {len(cases)} date/time cases, {len(invalid)} invalid inputs, DST checks, and 6 CLI checks.")
