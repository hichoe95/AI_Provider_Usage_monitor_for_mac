#!/usr/bin/env python3
"""Generate an app icon image using Gemini API.

Usage:
  GOOGLE_GENERATIVE_AI_API_KEY=... python3 Scripts/generate_icon_with_gemini.py \
    --output Assets/icon-gemini-raw.png
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_PROMPT = (
    "Create a macOS app icon illustration, 1024x1024, cute colorful coding mascot, "
    "wearing a beanie, friendly smile, bright expressive eyes, looking at a glowing "
    "monitor in a dark navy scene. Keep shapes bold and readable at small sizes. "
    "No text, no watermark, centered composition, clear silhouette."
)

MODEL_CANDIDATES = [
    "gemini-2.0-flash-preview-image-generation",
    "gemini-2.0-flash-exp-image-generation",
    "gemini-2.0-flash-exp",
]


def request_generation(api_key: str, model: str, prompt: str, timeout: int) -> bytes:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }

    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} for model {model}: {detail}") from e

    parsed = json.loads(raw)
    candidates = parsed.get("candidates", [])
    for candidate in candidates:
        content = candidate.get("content", {})
        for part in content.get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if not inline:
                continue
            data = inline.get("data")
            mime = (inline.get("mimeType") or inline.get("mime_type") or "").lower()
            if data and (mime.startswith("image/") or not mime):
                return base64.b64decode(data)

    raise RuntimeError(f"Model {model} returned no image data")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate icon image via Gemini API")
    parser.add_argument("--output", default="Assets/icon-gemini-raw.png")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--model", default="auto", help="Gemini model or 'auto'")
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()

    api_key = os.getenv("GOOGLE_GENERATIVE_AI_API_KEY")
    if not api_key:
        print("GOOGLE_GENERATIVE_AI_API_KEY is not set", file=sys.stderr)
        return 2

    models = MODEL_CANDIDATES if args.model == "auto" else [args.model]

    last_error: Exception | None = None
    image_bytes: bytes | None = None
    chosen_model = ""
    for model in models:
        try:
            image_bytes = request_generation(api_key, model, args.prompt, args.timeout)
            chosen_model = model
            break
        except Exception as e:  # noqa: BLE001
            last_error = e

    if image_bytes is None:
        print("Gemini image generation failed for all tried models.", file=sys.stderr)
        if last_error:
            print(str(last_error), file=sys.stderr)
        return 1

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(image_bytes)
    print(f"Generated icon image with model '{chosen_model}': {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
