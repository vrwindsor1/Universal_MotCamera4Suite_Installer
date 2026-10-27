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
    if not os.path.exists(compat_file):
        print(f"[ERROR] {compat_file} does not exist.")
        sys.exit(1)

    with open(compat_file, "r", encoding="utf-8") as f:
        content = f.read()

    # Anchor markers
    list_start_marker = "<!-- DEVICE_LIST_START -->"
    list_end_marker = "<!-- DEVICE_LIST_END -->"

    if list_start_marker not in content or list_end_marker not in content:
        print(f"[ERROR] Anchor markers {list_start_marker} or {list_end_marker} not found in {compat_file}.")
        sys.exit(1)

    device_key = re.sub(r"[^a-zA-Z0-9_-]", "", codename.lower())
    if not device_key or device_key == "—":
        device_key = re.sub(r"[^a-zA-Z0-9_-]", "", device_name.lower())

    device_start_marker = f"<!-- DEVICE: {device_key} -->"
    device_end_marker = f"<!-- /DEVICE: {device_key} -->"

    issue_marker = f"[#{issue_number}](" if issue_number else None

    # Check if this device section already exists
    if device_start_marker in content and device_end_marker in content:
        print(f"[INFO] Device '{device_key}' already exists. Updating existing accordion...")
        dev_parts = content.split(device_start_marker, 1)
        before_dev = dev_parts[0]
        dev_and_rest = dev_parts[1].split(device_end_marker, 1)
        dev_block = dev_and_rest[0]
        after_dev = dev_and_rest[1]

        # Extract existing rows from the table in dev_block
        lines = dev_block.strip().splitlines()
        existing_report_rows = []
        table_found = False

        for l in lines:
            if re.match(r"^\|\s*:?---", l):
                table_found = True
                continue
            if table_found and l.strip().startswith("|"):
                # If this issue was previously imported, skip it to avoid duplicate on edit
                if issue_marker and issue_marker in l:
                    continue
                existing_report_rows.append(l.strip())

        # Append new report row
        existing_report_rows.append(new_report_row)
        total_reports = len(existing_report_rows)
        plural_s = "report" if total_reports == 1 else "reports"

        # Rebuild device block
        model_str = f" ({model})" if model != "—" else ""
        new_dev_block = f"""
<details>
<summary><b>{device_name}</b> &nbsp;•&nbsp; <code>{codename}</code>{model_str} &nbsp;•&nbsp; {badge_emoji} <b>{result_cat}</b> &nbsp;<i>({total_reports} {plural_s})</i></summary>
<br>

| Report | Compiler | Custom ROM | Stock Firmware | Outcome | Tested Features / Notes |
| :--- | :---: | :--- | :--- | :---: | :--- |
""" + "\n".join(existing_report_rows) + "\n\n</details>\n"

        content = before_dev + device_start_marker + new_dev_block + device_end_marker + after_dev

    else:
        print(f"[INFO] Adding new device accordion for '{device_name}' ({codename})...")
        model_str = f" ({model})" if model != "—" else ""
        new_dev_block = f"""{device_start_marker}
<details>
<summary><b>{device_name}</b> &nbsp;•&nbsp; <code>{codename}</code>{model_str} &nbsp;•&nbsp; {badge_emoji} <b>{result_cat}</b> &nbsp;<i>(1 report)</i></summary>
<br>

| Report | Compiler | Custom ROM | Stock Firmware | Outcome | Tested Features / Notes |
| :--- | :---: | :--- | :--- | :---: | :--- |
{new_report_row}

</details>
{device_end_marker}
"""
        # Find directory list block
        list_parts = content.split(list_start_marker, 1)
        before_list = list_parts[0] + list_start_marker + "\n"
        list_and_after = list_parts[1].split(list_end_marker, 1)
        current_list = list_and_after[0].strip()
        after_list = "\n" + list_end_marker + list_and_after[1]

        # Remove placeholder if present
        if "*No confirmed reports yet.*" in current_list:
            current_list = ""

        updated_list = current_list + "\n\n" + new_dev_block if current_list else new_dev_block
        content = before_list + updated_list.strip() + after_list

    with open(compat_file, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"[SUCCESS] Successfully updated {compat_file} for {device_name} ({codename}).")

if __name__ == "__main__":
    main()
