#!/usr/bin/env python3
"""Fetch the app-embedded font without redistributing it in the public repository."""
import hashlib
import io
from pathlib import Path
import subprocess

try:
    from fontTools.ttLib import TTFont
except ImportError:
    raise SystemExit('Install dependencies: python3 -m pip install "fonttools[woff]==4.63.0"')

URL = "https://cdn.jsdelivr.net/gh/projectnoonnu/2508-2@1.0/OkDanDan-Bold.woff2"
SOURCE_SHA256 = "ad0931ddd19f106c6f1f3b065b924b03b47a6e7263ddbf941764318568f5343e"
OUTPUT_SHA256 = "0b28e6bb4b24da2f2d66510c538ecb79f4124fa482a58a51eff5a1f17a1b2f05"
destination = Path(__file__).resolve().parents[1] / "Reffi/Resources/Fonts/OkDanDan-Bold.ttf"

if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == OUTPUT_SHA256:
    print("OKDandan font is ready.")
else:
    data = subprocess.run(
        ["curl", "--fail", "--location", "--silent", "--show-error", "--max-time", "60", URL],
        check=True, capture_output=True,
    ).stdout
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise SystemExit("Font source checksum changed; review the source before building.")
    font = TTFont(io.BytesIO(data), recalcTimestamp=False)
    font.flavor = None
    output = io.BytesIO()
    font.save(output)
    if hashlib.sha256(output.getvalue()).hexdigest() != OUTPUT_SHA256:
        raise SystemExit("Unexpected font conversion output; use fontTools 4.63.0.")
    temporary = destination.with_suffix(".tmp")
    temporary.write_bytes(output.getvalue())
    temporary.replace(destination)
    print("OKDandan downloaded and prepared for app embedding.")
