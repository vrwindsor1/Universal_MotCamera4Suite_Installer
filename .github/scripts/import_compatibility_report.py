#!/usr/bin/env python3
import os
import re
import sys

def clean_cell(text: str) -> str:
    """Sanitize text for markdown table cells."""
    if not text or text.strip() in ("_No response_", "None", "n/a", "N/A"):
        return "—"
    cleaned = text.strip().replace("\r", "").replace("\n", " ")
    cleaned = cleaned.replace("|", "\\|")
    return cleaned

def parse_compiler_method(method_raw: str) -> str:
    method_clean = clean_cell(method_raw)
    if ".sh" in method_clean:
        return "`.sh`"
    elif ".ps1" in method_clean:
        return "`.ps1`"
    elif ".bat" in method_clean:
        return "`.bat`"
    return method_clean

def parse_issue_form(body: str) -> dict:
    """Parse GitHub Issue Form markdown body into key-value pairs."""
    fields = {}
    current_key = None
    current_lines = []

    for line in body.splitlines():
        if line.startswith("### "):
            if current_key:
                fields[current_key] = "\n".join(current_lines).strip()
            current_key = line[4:].strip()
            current_lines = []
        else:
            if current_key:
                current_lines.append(line)

    if current_key:
        fields[current_key] = "\n".join(current_lines).strip()

    return fields

def parse_sensor_summary(breakdown_raw: str) -> str:
    """Extract working and failing sensors into a clean one-line summary."""
    if not breakdown_raw or breakdown_raw.strip() in ("_No response_", "None", "n/a", "N/A"):
        return "—"

    working = []
    not_working = []

    for line in breakdown_raw.splitlines():
        line_clean = line.strip()
        if not line_clean.startswith("- "):
            continue
        parts = line_clean[2:].split(":", 1)
        if len(parts) != 2:
            continue
        feat_name = parts[0].strip()
        feat_name = feat_name.replace(" (Photo)", "").replace(" (Selfie) Camera", " Selfie").replace(" Recording (1080p / 4K)", " 4K").replace(" Mode", "")
        status = parts[1].strip().lower()

        if "not working" in status:
            not_working.append(feat_name)
        elif "working" in status:
            working.append(feat_name)

    parts_summary = []
    if working:
        parts_summary.append("Working: " + ", ".join(working))
    if not_working:
        parts_summary.append("Fails: " + ", ".join(not_working))

    if not parts_summary:
        return clean_cell(breakdown_raw[:80])
    return "; ".join(parts_summary)

def determine_badge(result_text: str) -> tuple[str, str]:
    """Return badge emoji and standardized result category."""
    res = result_text.lower()
    if "works perfectly" in res:
        return "🟢", "Works Perfectly"
    elif "mostly working" in res:
        return "🟡", "Mostly Working"
    elif "app crashes" in res:
        return "🔴", "App Crashes"
    elif "app missing" in res:
        return "⚪", "App Missing"
    elif "won't boot" in res or "wont boot" in res:
        return "⛔", "Won't Boot"
    return "⚪", clean_cell(result_text)

def main():
    issue_body = os.environ.get("ISSUE_BODY", "")
    issue_number = os.environ.get("ISSUE_NUMBER", "")
    issue_author = os.environ.get("ISSUE_AUTHOR", "")
    issue_url = os.environ.get("ISSUE_URL", "")

    if not issue_body:
        print("[ERROR] ISSUE_BODY is empty. Exiting.")
        sys.exit(1)

    fields = parse_issue_form(issue_body)
    print("Parsed Fields:", list(fields.keys()))

    device_name = clean_cell(fields.get("Device Marketing Name", ""))
    codename = clean_cell(fields.get("Device Codename", ""))
    model = clean_cell(fields.get("Device Model Number", ""))
    compiler_raw = fields.get("Compiler Method", "")
    compiler = parse_compiler_method(compiler_raw)
    result_raw = fields.get("Test Result", "")
    badge_emoji, result_cat = determine_badge(result_raw)
    custom_rom = clean_cell(fields.get("Custom ROM & Android Version", ""))
    stock_fw = clean_cell(fields.get("Stock Firmware Source / Build", ""))
    sensor_raw = fields.get("Sensor & Feature Breakdown", "")
    features_summary = clean_cell(parse_sensor_summary(sensor_raw))

    if not device_name or device_name == "—":
        print("[ERROR] Device Marketing Name missing.")
        sys.exit(1)

    # Format reporter & issue link
    reporter_str = f"[@{issue_author}](https://github.com/{issue_author})" if issue_author else "Community"
    report_link = f"[#{issue_number}]({issue_url})" if issue_number and issue_url else f"#{issue_number}"

    # Build report table row
    new_report_row = f"| {report_link} by {reporter_str} | {compiler} | {custom_rom} | {stock_fw} | {badge_emoji} {result_cat} | {features_summary} |"
    print("New Report Row:", new_report_row)

    compat_file = "COMPATIBILITY.md"
    reports_file = "REPORTS.md"

    if not os.path.exists(compat_file):
        print(f"[ERROR] {compat_file} does not exist.")
        sys.exit(1)
    if not os.path.exists(reports_file):
        print(f"[ERROR] {reports_file} does not exist.")
        sys.exit(1)

    with open(compat_file, "r", encoding="utf-8") as f:
        compat_content = f.read()

    with open(reports_file, "r", encoding="utf-8") as f:
        reports_content = f.read()

    # Anchor markers
    sum_start_marker = "<!-- SUMMARY_TABLE_START -->"
    sum_end_marker = "<!-- SUMMARY_TABLE_END -->"
    reports_start_marker = "<!-- DEVICE_REPORTS_START -->"
    reports_end_marker = "<!-- DEVICE_REPORTS_END -->"

    if sum_start_marker not in compat_content or sum_end_marker not in compat_content:
        print(f"[ERROR] Required table markers not found in {compat_file}.")
        sys.exit(1)

    if reports_start_marker not in reports_content or reports_end_marker not in reports_content:
        print(f"[ERROR] Required reports markers not found in {reports_file}.")
        sys.exit(1)

    device_key = re.sub(r"[^a-zA-Z0-9_-]", "", codename.lower())
    if not device_key or device_key == "—":
        device_key = re.sub(r"[^a-zA-Z0-9_-]", "", device_name.lower())

    anchor = device_key
    device_start_marker = f"<!-- DEVICE: {anchor} -->"
    device_end_marker = f"<!-- /DEVICE: {anchor} -->"
    issue_marker = f"[#{issue_number}](" if issue_number else None

    # --- 1. Update/Add in REPORTS.md ---
    if device_start_marker in reports_content and device_end_marker in reports_content:
        print(f"[INFO] Device '{anchor}' already has reports in {reports_file}. Updating section...")
        r_parts = reports_content.split(device_start_marker, 1)
        before_dev = r_parts[0]
        dev_and_rest = r_parts[1].split(device_end_marker, 1)
        dev_block = dev_and_rest[0]
        after_dev = dev_and_rest[1]

        # Extract existing rows from table
        lines = dev_block.strip().splitlines()
        existing_report_rows = []
        table_found = False

        for l in lines:
            if re.match(r"^\|\s*:?---", l):
                table_found = True
                continue
            if table_found and l.strip().startswith("|"):
                if issue_marker and issue_marker in l:
                    continue  # Deduplicate on re-run / edit
                existing_report_rows.append(l.strip())

        existing_report_rows.append(new_report_row)
        total_reports = len(existing_report_rows)
        plural_s = "Report" if total_reports == 1 else "Reports"
        model_str = f" / `{model}`" if model != "—" else ""

        new_dev_block = f"""
<a id="{anchor}"></a>
### 📱 {device_name} (`{codename}`{model_str})

**Overall Status:** {badge_emoji} **{result_cat}** &bull; **Total Reports:** {total_reports}

| Report | Compiler | Custom ROM | Stock Firmware | Outcome | Tested Features / Notes |
| :--- | :---: | :--- | :--- | :---: | :--- |
""" + "\n".join(existing_report_rows) + "\n"

        reports_content = before_dev + device_start_marker + new_dev_block + device_end_marker + after_dev
    else:
        print(f"[INFO] Adding new device section in {reports_file} for '{device_name}' ({codename})...")
        total_reports = 1
        plural_s = "Report"
        model_str = f" / `{model}`" if model != "—" else ""

        new_dev_block = f"""{device_start_marker}
<a id="{anchor}"></a>
### 📱 {device_name} (`{codename}`{model_str})

**Overall Status:** {badge_emoji} **{result_cat}** &bull; **Total Reports:** 1

| Report | Compiler | Custom ROM | Stock Firmware | Outcome | Tested Features / Notes |
| :--- | :---: | :--- | :--- | :---: | :--- |
{new_report_row}
{device_end_marker}
"""
        r_parts = reports_content.split(reports_start_marker, 1)
        before_reports = r_parts[0] + reports_start_marker + "\n"
        reports_and_after = r_parts[1].split(reports_end_marker, 1)
        current_reports = reports_and_after[0].strip()
        after_reports = "\n" + reports_end_marker + reports_and_after[1]

        updated_reports = current_reports + "\n\n" + new_dev_block if current_reports else new_dev_block
        reports_content = before_reports + updated_reports.strip() + after_reports

    with open(reports_file, "w", encoding="utf-8") as f:
        f.write(reports_content)

    # --- 2. Update/Add in COMPATIBILITY.md SUMMARY_TABLE ---
    s_parts = compat_content.split(sum_start_marker, 1)
    before_sum = s_parts[0] + sum_start_marker + "\n"
    sum_and_after = s_parts[1].split(sum_end_marker, 1)
    current_sum = sum_and_after[0].strip()
    after_sum = "\n" + sum_end_marker + sum_and_after[1]

    sum_lines = [l for l in current_sum.splitlines() if "*No confirmed reports yet.*" not in l]

    new_summary_row = f"| [**{device_name}**](REPORTS.md#{anchor}) | `{codename}` | `{model}` | {badge_emoji} {result_cat} | [{total_reports} {plural_s} ➔](REPORTS.md#{anchor}) |"

    updated_sum_lines = []
    found_in_summary = False
    for l in sum_lines:
        if f"REPORTS.md#{anchor}" in l or f"(#{anchor})" in l:
            updated_sum_lines.append(new_summary_row)
            found_in_summary = True
        else:
            updated_sum_lines.append(l)

    if not found_in_summary:
        updated_sum_lines.append(new_summary_row)

    compat_content = before_sum + "\n".join(updated_sum_lines) + after_sum

    with open(compat_file, "w", encoding="utf-8") as f:
        f.write(compat_content)

    print(f"[SUCCESS] Updated {compat_file} table and {reports_file} details for {device_name} ({codename}).")

if __name__ == "__main__":
    main()
