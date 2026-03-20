#!/usr/bin/env python3
"""Shared HarfBuzz outline payload helpers for mesh text overlays."""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from .extract_outline_data import extract_shaped_data
except ImportError:
    from extract_outline_data import extract_shaped_data


ROOT = Path(__file__).resolve().parents[1]


def resolve_font_path(font_url: str) -> Path:
    if font_url.startswith("/"):
        return ROOT / font_url.lstrip("/")
    return (ROOT / font_url).resolve()


def build_text_outline_payload(
    *,
    text: str,
    font_url: str,
    direction: str = "ltr",
    script: str | None = None,
    language: str | None = None,
    flatness_em: float = 0.0015,
) -> dict[str, Any]:
    shaped_text = extract_shaped_data(
        font_path=resolve_font_path(font_url),
        text=text,
        flatness_em=flatness_em,
        direction=direction,
        script=script,
        language=language,
        reuse_layout_js=None,
    )

    return {
        "sourceText": shaped_text.source_text,
        "fontName": shaped_text.font_name,
        "direction": shaped_text.direction,
        "script": shaped_text.script,
        "language": shaped_text.language,
        "glyphs": {
            glyph_key: {
                "glyphId": glyph.glyph_id,
                "glyphName": glyph.glyph_name,
                "sampleBounds": [float(value) for value in glyph.sample_bounds],
                "segments": [[float(value) for value in segment] for segment in glyph.segments],
            }
            for glyph_key, glyph in shaped_text.glyphs.items()
        },
        "run": [
            {
                "glyphKey": entry.glyph_key,
                "cluster": int(entry.cluster),
                "advanceEm": float(entry.advance_em),
                "xOffsetEm": float(entry.x_offset_em),
                "yOffsetEm": float(entry.y_offset_em),
            }
            for entry in shaped_text.run
        ],
    }
