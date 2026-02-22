#!/usr/bin/env python3
"""Capture tvOS screenshots using XCUITest and xcresulttool."""

import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────
SCHEME = "ImmichLens"
PROJECT = "ImmichLens.xcodeproj"
SIMULATOR_NAME = "Apple TV 4K (3rd generation) (at 1080p)"
TEST_PLAN = "ImmichLensScreenshots.xctestplan"
RESULT_BUNDLE = "screenshots.xcresult"
OUTPUT_DIR = "screenshots"
SCHEME_PATH = Path(PROJECT) / "xcshareddata" / "xcschemes" / "ImmichLens.xcscheme"

REPO_ROOT = Path(__file__).resolve().parent.parent
os.chdir(REPO_ROOT)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, **kwargs)


def fatal(msg: str) -> None:
    print(f"✗ {msg}", file=sys.stderr)
    sys.exit(1)


# ── Validate env vars ─────────────────────────────────────────
server_url = os.environ.get("IMMICH_TEST_SERVER_URL")
email = os.environ.get("IMMICH_TEST_EMAIL")
password = os.environ.get("IMMICH_TEST_PASSWORD")
if not server_url or not email or not password:
    fatal("Set IMMICH_TEST_SERVER_URL, IMMICH_TEST_EMAIL, and IMMICH_TEST_PASSWORD environment variables")


# ── Generate test plan with credentials ────────────────────────
test_plan = {
    "configurations": [
        {"id": "9A3C1B2D-E4F5-6789-ABCD-EF0123456789", "name": "Configuration 1", "options": {}}
    ],
    "defaultOptions": {
        "environmentVariableEntries": [
            {"key": "IMMICH_TEST_SERVER_URL", "value": server_url},
            {"key": "IMMICH_TEST_EMAIL", "value": email},
            {"key": "IMMICH_TEST_PASSWORD", "value": password},
        ],
        "targetForVariableExpansion": {
            "containerPath": f"container:{PROJECT}",
            "identifier": "7B913997CEB430EA198332F7",
            "name": "ImmichLensUITests",
        },
    },
    "testTargets": [
        {
            "target": {
                "containerPath": f"container:{PROJECT}",
                "identifier": "7B913997CEB430EA198332F7",
                "name": "ImmichLensUITests",
            }
        }
    ],
    "version": 1,
}

Path(TEST_PLAN).write_text(json.dumps(test_plan, indent=2) + "\n")
print(f"✓ Generated {TEST_PLAN}")


# ── Patch scheme to use test plans ─────────────────────────────
scheme_backup = SCHEME_PATH.read_text()


def restore_scheme():
    SCHEME_PATH.write_text(scheme_backup)
    print("✓ Restored scheme")


# Restore scheme on any exit (crash, Ctrl-C, fatal(), etc.)
atexit.register(restore_scheme)

tree = ET.parse(SCHEME_PATH)
root = tree.getroot()
test_action = root.find("TestAction")

# Remove existing <Testables> (replaced by test plan)
for testables in test_action.findall("Testables"):
    test_action.remove(testables)

# Add <TestPlans> referencing our generated plan
test_plans = ET.SubElement(test_action, "TestPlans")
plan_ref = ET.SubElement(test_plans, "TestPlanReference")
plan_ref.set("reference", f"container:{TEST_PLAN}")
plan_ref.set("default", "YES")

tree.write(SCHEME_PATH, xml_declaration=True, encoding="UTF-8")
print("✓ Patched scheme to use test plan")


# ── Boot simulator ─────────────────────────────────────────────
result = run(["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True)
devices = json.loads(result.stdout)

device_id = None
boot_state = None
for runtime, device_list in devices["devices"].items():
    for d in device_list:
        if d["name"] == SIMULATOR_NAME and d["isAvailable"]:
            device_id = d["udid"]
            boot_state = d["state"]
            break
    if device_id:
        break

if not device_id:
    result = run(["xcrun", "simctl", "list", "devices", "available"], capture_output=True, text=True)
    tvos_lines = [l for l in result.stdout.splitlines() if "tv" in l.lower()]
    fatal(f"Simulator '{SIMULATOR_NAME}' not found. Available tvOS simulators:\n" + "\n".join(tvos_lines))

if boot_state != "Booted":
    print(f"Booting simulator {SIMULATOR_NAME}...")
    run(["xcrun", "simctl", "boot", device_id])
    time.sleep(5)

print(f"✓ Simulator ready ({device_id})")


# ── Clean previous results ─────────────────────────────────────
shutil.rmtree(RESULT_BUNDLE, ignore_errors=True)
shutil.rmtree(OUTPUT_DIR, ignore_errors=True)


# ── Run tests ──────────────────────────────────────────────────
print("Running UI tests...")
test_plan_name = Path(TEST_PLAN).stem
test_result = subprocess.run(
    [
        "xcodebuild", "test",
        "-project", PROJECT,
        "-scheme", SCHEME,
        "-testPlan", test_plan_name,
        "-destination", f"platform=tvOS Simulator,id={device_id}",
        "-resultBundlePath", RESULT_BUNDLE,
        "-skipPackagePluginValidation",
    ],
    capture_output=True,
    text=True,
)

if test_result.returncode != 0:
    # Print last 30 lines of output for diagnosis
    lines = (test_result.stdout + test_result.stderr).splitlines()
    print("\n".join(lines[-30:]))
    fatal("xcodebuild test failed")

print("✓ Tests complete")


# ── Extract attachments ────────────────────────────────────────
export_dir = tempfile.mkdtemp()
run([
    "xcrun", "xcresulttool", "export", "attachments",
    "--path", RESULT_BUNDLE,
    "--output-path", export_dir,
    "--type", "png",
])
print(f"✓ Extracted attachments to {export_dir}")


# ── Rename UUID files to human names ───────────────────────────
manifest_path = Path(export_dir) / "manifest.json"
if not manifest_path.exists():
    fatal("No manifest.json found — no screenshots captured?")

manifest = json.loads(manifest_path.read_text())
output = Path(OUTPUT_DIR)
output.mkdir(exist_ok=True)

for test_entry in manifest:
    for att in test_entry.get("attachments", []):
        exported = att.get("exportedFileName", "")
        if not exported.endswith(".png"):
            continue

        source = Path(export_dir) / exported
        if not source.exists():
            continue

        # suggestedHumanReadableName looks like "01_Photos_0_8843E7BB-...-288126A6EEBC.png"
        # Strip the trailing "_0_{UUID}" to get "01_Photos.png"
        suggested = att.get("suggestedHumanReadableName", exported)
        dest_name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}\.png$", ".png", suggested)

        shutil.copy2(source, output / dest_name)
        print(f"  {dest_name}")

print(f"✓ Screenshots saved to {OUTPUT_DIR}/")


# ── Cleanup ────────────────────────────────────────────────────
Path(TEST_PLAN).unlink(missing_ok=True)
shutil.rmtree(RESULT_BUNDLE, ignore_errors=True)
shutil.rmtree(export_dir, ignore_errors=True)
print("✓ Cleaned up temporary files")

for f in sorted(output.iterdir()):
    size = f.stat().st_size
    print(f"  {f.name}  ({size:,} bytes)")
