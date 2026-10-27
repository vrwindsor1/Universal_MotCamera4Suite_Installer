#!/usr/bin/env python3
import os
import re
import sys

def clean_cell(text: str) -> str:
    """Sanitize text for markdown table cells."""
    if not text or text.strip() in ("_No response_", "None", "n/a", "N/A"):
        return "—"
    # Replace newlines with spaces and escape pipe characters
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

def determine_category(result_text: str) -> str:
    """Map result text to category heading in COMPATIBILITY.md."""
    res = result_text.lower()
    if "works perfectly" in res:
        return "### 🟢 Works Perfectly"
    elif "mostly working" in res:
        return "### 🟡 Mostly Working"
    elif "app crashes" in res:
        return "### 🔴 App Crashes"
    elif "app missing" in res:
        return "### ⚪ App Missing"
    elif "won't boot" in res or "wont boot" in res:
        return "### ⛔ Won't Boot"
    return ""

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
    custom_rom = clean_cell(fields.get("Custom ROM & Android Version", ""))
    stock_fw = clean_cell(fields.get("Stock Firmware Source / Build", ""))

    if not device_name or device_name == "—":
        print("[ERROR] Device Marketing Name missing.")
        sys.exit(1)

    category_heading = determine_category(result_raw)
    if not category_heading:
        print(f"[ERROR] Could not determine category from result: {result_raw}")
        sys.exit(1)

    # Format reporter & notes with link to the issue
    reporter_str = f"[@{issue_author}](https://github.com/{issue_author})" if issue_author else "Community"
    if issue_number and issue_url:
        notes = f"{reporter_str} in [#{issue_number}]({issue_url})"
    elif issue_number:
        notes = f"{reporter_str} in #{issue_number}"
    else:
        notes = reporter_str

    # Format codename & model nicely with backticks
    codename_fmt = f"`{codename}`" if codename != "—" and not codename.startswith("`") else codename
    model_fmt = f"`{model}`" if model != "—" and not model.startswith("`") else model

    new_row = f"| **{device_name}** | {codename_fmt} | {model_fmt} | {compiler} | {custom_rom} | {stock_fw} | {notes} |"
    print("New Row to insert:")
    print(new_row)

    compat_file = "COMPATIBILITY.md"
    if not os.path.exists(compat_file):
        print(f"[ERROR] {compat_file} does not exist.")
        sys.exit(1)

    with open(compat_file, "r", encoding="utf-8") as f:
        content = f.read()

    if category_heading not in content:
        print(f"[ERROR] Category heading '{category_heading}' not found in {compat_file}.")
        sys.exit(1)

    # Split content around category
    parts = content.split(category_heading, 1)
    before_cat = parts[0] + category_heading
    after_cat = parts[1]

    # Find the next section boundary (next '---' or '### ')
    m = re.search(r"\n---\n", after_cat)
    if m:
        section_content = after_cat[:m.start()]
        remainder = after_cat[m.start():]
    else:
        section_content = after_cat
        remainder = ""

    lines = section_content.splitlines()
    filtered_lines = [l for l in lines if "*No confirmed reports yet.*" not in l]

    # Find the last table row line index
    last_table_line_idx = -1
    for i, l in enumerate(filtered_lines):
        if l.strip().startswith("|"):
            last_table_line_idx = i

    if last_table_line_idx != -1:
        filtered_lines.insert(last_table_line_idx + 1, new_row)
    else:
        filtered_lines.append(new_row)

    updated_section_content = "\n".join(filtered_lines)
    updated_full_content = before_cat + updated_section_content + remainder

    with open(compat_file, "w", encoding="utf-8") as f:
        f.write(updated_full_content)

    print(f"[SUCCESS] Successfully updated {compat_file} with report for {device_name} ({codename}).")

if __name__ == "__main__":
    main()
