#!/usr/bin/env python3
"""Convert DAO vs DEE diagram HTML to PNG using Chrome headless."""

from html2image import Html2Image
from pathlib import Path
import os

SCRIPT_DIR = Path(__file__).parent.resolve()
HTML_FILE = SCRIPT_DIR / "dao_vs_dee_diagram.html"
OUTPUT_FILE = "dao_vs_dee_diagram.png"

# Read HTML content
html_content = HTML_FILE.read_text(encoding="utf-8")

# Initialize with Chrome
hti = Html2Image(
    browser="chrome",
    browser_executable="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    output_path=str(SCRIPT_DIR),
    size=(1400, 1100),
    custom_flags=[
        "--default-background-color=00000000",
        "--hide-scrollbars",
    ],
)

# Convert
paths = hti.screenshot(
    html_str=html_content,
    save_as=OUTPUT_FILE,
)

output_path = SCRIPT_DIR / OUTPUT_FILE
if output_path.exists():
    size_kb = output_path.stat().st_size / 1024
    print(f"Success: {output_path} ({size_kb:.0f} KB)")
else:
    print("Error: PNG file was not created")
