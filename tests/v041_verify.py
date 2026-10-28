#!/usr/bin/env python3
"""Repeatable production checks. Does not open or change the player's save."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs/v041/verification"
SUITES = [
    "v041_meal_retirement", "v041_save_balance", "v041_guidance_contract", "v041_combat_roles",
    "v039_encounter_contract", "v039_shop_advisor", "v039_boss_contract",
    "v039_review_logic", "v039_review_carrier", "v038_shop_contract", "v038_migration",
    "v038_cinema_contract", "v035_fixed_bosses", "v035_cat_contract",
    "v034_toys", "v034_toys_reward_migration", "v036_stage_art",
    "v040_locale_contract", "v040_audio_assets", "v041_audio_loops",
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true", help="Also render and exercise native windows")
    opts = parser.parse_args()
    engine = shutil.which("godot")
    if not engine:
        raise SystemExit("Godot executable not found")
    OUT.mkdir(parents=True, exist_ok=True)
    reports = []

    def run(name, args, timeout=180):
        start = time.monotonic()
        command = [engine, "--path", str(ROOT), *args]
        try:
            proc = subprocess.run(command, text=True, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            captured = exc.stdout or ""
            if isinstance(captured, bytes):
                captured = captured.decode("utf-8", errors="replace")
            proc = subprocess.CompletedProcess(command, 124, captured, "ERROR: Test exceeded its timeout\n")
        log = proc.stdout + proc.stderr
        (OUT / f"{name}.log").write_text(log)
        errors = re.findall(r"^.*(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL ).*$", log, re.M)
        result = {"name": name, "exit_code": proc.returncode, "errors": errors, "seconds": round(time.monotonic()-start, 2)}
        reports.append(result)
        print(json.dumps(result, ensure_ascii=False), flush=True)

    run("editor-import", ["--headless", "--editor", "--quit"])
    for name in SUITES:
        run(name, ["--headless", "--script", f"res://tests/{name}.gd"])
    run("v041-ui-input", ["--headless", "res://tests/v041_ui_contract.tscn"])
    run("v041-guidance-input", ["--headless", "res://tests/v041_guidance_native.tscn"])
    for difficulty in ["easy", "hard"]:
        run("v041-earned-campaign-" + difficulty, ["--headless", "--script", "res://tests/v041_combat_campaign.gd", "--", "--mode=" + difficulty])
    if opts.native:
        run("native-ui", ["res://tests/v041_ui_contract.tscn"])
        run("native-guidance", ["res://tests/v041_guidance_native.tscn"])
    report = {"engine": engine, "native": opts.native, "reports": reports,
              "ok": all(r["exit_code"] == 0 and not r["errors"] for r in reports)}
    (OUT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)

if __name__ == "__main__":
    main()
