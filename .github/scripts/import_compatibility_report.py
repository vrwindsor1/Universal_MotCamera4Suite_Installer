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
    elif "untested" in res:
        return "❔", "Untested"
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

    os.makedirs("reports", exist_ok=True)

    device_key = re.sub(r"[^a-zA-Z0-9_-]", "", codename.lower())
    if not device_key or device_key == "—":
        device_key = re.sub(r"[^a-zA-Z0-9_-]", "", device_name.lower())

    device_file = os.path.join("reports", f"{device_key}.md")
    issue_marker = f"[#{issue_number}](" if issue_number else None

    # --- 1. Create or Update reports/{device_key}.md ---
    if os.path.exists(device_file):
        print(f"[INFO] Updating existing report page: {device_file}")
        with open(device_file, "r", encoding="utf-8") as f:
            dev_content = f.read()

        # Extract existing rows
        table_lines = []
        table_found = False
        other_lines = []

        for line in dev_content.splitlines():
            if re.match(r"^\|\s*:?---", line):
                table_found = True
                continue
            if table_found and line.strip().startswith("|"):
                if "*no reports yet*" in line.lower():
                    continue
                if issue_marker and issue_marker in line:
                    continue  # Deduplicate on issue edit / re-run
                table_lines.append(line.strip())

        table_lines.append(new_report_row)
        total_reports = len(table_lines)

        # Update metadata lines
        dev_content = re.sub(
            r"- \*\*Current Overall Status:\*\* .*",
            f"- **Current Overall Status:** {badge_emoji} **{result_cat}**",
            dev_content
        )
        dev_content = re.sub(
            r"- \*\*Total Community Reports:\*\* .*",
            f"- **Total Community Reports:** {total_reports}",
            dev_content
        )

        # If new model was specified and not in models, append it
        if model != "—":
            m_match = re.search(r"- \*\*Model Number\(s\):\*\* (.*)", dev_content)
            if m_match:
                existing_models = m_match.group(1).strip()
                if model not in existing_models:
                    updated_models = f"{existing_models}, `{model}`"
                    dev_content = dev_content.replace(m_match.group(0), f"- **Model Number(s):** {updated_models}")

        # Replace table rows
        parts = dev_content.split("| :--- | :---: | :--- | :--- | :---: | :--- |\n", 1)
        if len(parts) == 2:
            footer_parts = parts[1].split("\n---", 1)
            new_table_content = "\n".join(table_lines) + "\n\n---"
            dev_content = parts[0] + "| :--- | :---: | :--- | :--- | :---: | :--- |\n" + new_table_content + (footer_parts[1] if len(footer_parts) == 2 else "")

        with open(device_file, "w", encoding="utf-8") as f:
            f.write(dev_content)

    else:
        print(f"[INFO] Creating new report page: {device_file}")
        total_reports = 1
        model_val = f"`{model}`" if model != "—" else "—"

        new_dev_content = f"""# Device Report: {device_name} (`{codename}`)

<p align="center">
  <img src="../assets/motcamera4_logo.png" width="96" height="96" alt="MotCamera4 Logo">
  <br>
  <a href="../COMPATIBILITY.md"><img src="https://img.shields.io/badge/⬅%20Back%20to-Compatibility%20Matrix-blue?style=flat-square" alt="Compatibility Matrix"></a>
  <a href="https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Submit-New%20Report-success?style=flat-square&logo=github" alt="Submit Report"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square" alt="License"></a>
</p>

## Device Information

- **Marketing Name:** {device_name}
- **Codename:** `{codename}`
- **Model Number(s):** {model_val}
- **Current Overall Status:** {badge_emoji} **{result_cat}**
- **Total Community Reports:** 1

---

## Community Test Reports

| Report | Compiler | Custom ROM | Stock Firmware | Outcome | Tested Features / Notes |
| :--- | :---: | :--- | :--- | :---: | :--- |
{new_report_row}

---

<p align="center">
  <a href="../COMPATIBILITY.md">⬅ Back to Full Compatibility Matrix</a> &bull; <a href="../README.md">Installer Documentation</a>
</p>
"""
        with open(device_file, "w", encoding="utf-8") as f:
            f.write(new_dev_content)

    # --- 2. Update COMPATIBILITY.md Summary Table ---
    compat_file = "COMPATIBILITY.md"
    if not os.path.exists(compat_file):
        print(f"[ERROR] {compat_file} does not exist.")
        sys.exit(1)

    with open(compat_file, "r", encoding="utf-8") as f:
        compat_content = f.read()

    sum_start_marker = "<!-- SUMMARY_TABLE_START -->"
    sum_end_marker = "<!-- SUMMARY_TABLE_END -->"

    if sum_start_marker not in compat_content or sum_end_marker not in compat_content:
        print(f"[ERROR] Required table markers not found in {compat_file}.")
        sys.exit(1)

    plural_s = "Report" if total_reports == 1 else "Reports"
    rel_device_path = f"reports/{device_key}.md"
    new_summary_row = f"| [**{device_name}**]({rel_device_path}) | `{codename}` | `{model}` | {badge_emoji} {result_cat} | [{total_reports} {plural_s} ➔]({rel_device_path}) |"

    s_parts = compat_content.split(sum_start_marker, 1)
    before_sum = s_parts[0] + sum_start_marker + "\n"
    sum_and_after = s_parts[1].split(sum_end_marker, 1)
    current_sum = sum_and_after[0].strip()
    after_sum = "\n" + sum_end_marker + sum_and_after[1]

    sum_lines = [l for l in current_sum.splitlines() if "*No confirmed reports yet.*" not in l]

    updated_sum_lines = []
    found_in_summary = False
    for l in sum_lines:
        if f"reports/{device_key}.md" in l or f"`{codename}`" in l:
            updated_sum_lines.append(new_summary_row)
            found_in_summary = True
        else:
            updated_sum_lines.append(l)

    if not found_in_summary:
        updated_sum_lines.append(new_summary_row)

    compat_content = before_sum + "\n".join(updated_sum_lines) + after_sum

    with open(compat_file, "w", encoding="utf-8") as f:
        f.write(compat_content)

    print(f"[SUCCESS] Updated {compat_file} table and {device_file} for {device_name} ({codename}).")

if __name__ == "__main__":
    main()
