#!/usr/bin/env python3
"""Turns an Xcode result bundle into a Markdown summary of the tests, for the CI run's page.

    scripts/test-summary.py TestResults.xcresult >> "$GITHUB_STEP_SUMMARY"
"""
import json
import subprocess
import sys

bundle = sys.argv[1] if len(sys.argv) > 1 else "TestResults.xcresult"
output = subprocess.run(
    ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle],
    capture_output=True, text=True, check=True,
).stdout
summary = json.loads(output)

passed, failed, skipped = summary["passedTests"], summary["failedTests"], summary["skippedTests"]
icon = "✅" if failed == 0 else "❌"
print(f"### {icon} Tests: {passed} passed, {failed} failed, {skipped} skipped\n")
for failure in summary.get("testFailures", []):
    name = failure.get("testName", "?")
    text = failure.get("failureText", "").strip().replace("\n", " ")
    print(f"- `{name}`: {text}")
