#!/usr/bin/env python3
"""Generate shaped glyph outline data for the hyperbolic curve text demo."""

from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from fontTools.pens.basePen import (
    decomposeQuadraticSegment,
    decomposeSuperBezierSegment,
)
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.ttLib import TTFont

try:
    import uharfbuzz as hb
except ImportError:
    hb = None


DEFAULT_TEXT = "The fence curves in toward the side of the house."


Point = tuple[float, float]
Segment = tuple[Point, Point]


@dataclass(frozen=True)
class GlyphOutlineData:
    glyph_id: int
    glyph_name: str
    sample_bounds: tuple[float, float, float, float]
    segments: list[tuple[float, float, float, float]]


@dataclass(frozen=True)
class ShapedRunEntry:
    glyph_key: str
    cluster: int
    advance_em: float
    x_offset_em: float
    y_offset_em: float


@dataclass(frozen=True)
class ShapedTextData:
    source_text: str
    font_name: str
    direction: str
    script: str | None
    language: str | None
    glyphs: dict[str, GlyphOutlineData]
    run: list[ShapedRunEntry]


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    data_dir = root / "data"
    parser = argparse.ArgumentParser(
        description="Shape text and flatten font outlines into the JS format used by the curve-text shader."
    )
    parser.add_argument(
        "--font",
        type=Path,
        default=root / "fonts" / "cmunrm.ttf",
        help="Input TTF/OTF font file.",
    )
    parser.add_argument(
        "--text",
        default=DEFAULT_TEXT,
        help="Text to shape and export.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=data_dir / "computer-modern-outline-data.js",
        help="Output JS file.",
    )
    parser.add_argument(
        "--flatness-em",
        type=float,
        default=0.0015,
        help="Maximum curve deviation in em units before subdivision.",
    )
    parser.add_argument(
        "--reuse-layout-js",
        type=Path,
        default=None,
        help=(
            "Reuse shaped layout and metadata from an existing generated JS file. "
            "This bypasses HarfBuzz and only rebuilds glyph outlines."
        ),
    )
    parser.add_argument(
        "--direction",
        choices=["auto", "ltr", "rtl", "ttb", "btt"],
        default="auto",
        help="Optional shaping direction override.",
    )
    parser.add_argument(
        "--script",
        default=None,
        help="Optional OpenType script override, for example Arab or Latn.",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="Optional language override, for example ar or en.",
    )
    return parser.parse_args()


def mid(a: Point, b: Point) -> Point:
    return ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)


def point_line_distance(p: Point, a: Point, b: Point) -> float:
    bax = b[0] - a[0]
    bay = b[1] - a[1]
    denom = bax * bax + bay * bay
    if denom < 1e-12:
        dx = p[0] - a[0]
        dy = p[1] - a[1]
        return (dx * dx + dy * dy) ** 0.5
    return abs((p[0] - a[0]) * bay - (p[1] - a[1]) * bax) / (denom ** 0.5)


def append_segment(segments: list[Segment], a: Point, b: Point) -> None:
    if abs(a[0] - b[0]) < 1e-12 and abs(a[1] - b[1]) < 1e-12:
        return
    segments.append((a, b))


def flatten_quadratic(segments: list[Segment], p0: Point, p1: Point, p2: Point, tol: float) -> None:
    if point_line_distance(p1, p0, p2) <= tol:
        append_segment(segments, p0, p2)
        return
    p01 = mid(p0, p1)
    p12 = mid(p1, p2)
    p012 = mid(p01, p12)
    flatten_quadratic(segments, p0, p01, p012, tol)
    flatten_quadratic(segments, p012, p12, p2, tol)


def flatten_cubic(
    segments: list[Segment],
    p0: Point,
    p1: Point,
    p2: Point,
    p3: Point,
    tol: float,
) -> None:
    if max(point_line_distance(p1, p0, p3), point_line_distance(p2, p0, p3)) <= tol:
        append_segment(segments, p0, p3)
        return
    p01 = mid(p0, p1)
    p12 = mid(p1, p2)
    p23 = mid(p2, p3)
    p012 = mid(p01, p12)
    p123 = mid(p12, p23)
    p0123 = mid(p012, p123)
    flatten_cubic(segments, p0, p01, p012, p0123, tol)
    flatten_cubic(segments, p0123, p123, p23, p3, tol)


def flatten_qcurve(
    segments: list[Segment],
    current: Point,
    contour_start: Point,
    points: list[Point | None],
    tol: float,
) -> Point:
    if not points:
        return current
    explicit_points = list(points)
    if explicit_points[-1] is None:
        explicit_points = explicit_points[:-1]
        if not explicit_points:
            return contour_start
        explicit_points.append(contour_start)
    for control, end in decomposeQuadraticSegment(explicit_points):
        flatten_quadratic(segments, current, control, end, tol)
        current = end
    return current


def flatten_curve(
    segments: list[Segment],
    current: Point,
    points: list[Point],
    tol: float,
) -> Point:
    if len(points) == 3:
        pieces = [tuple(points)]
    else:
        pieces = decomposeSuperBezierSegment(points)
    for c1, c2, end in pieces:
        flatten_cubic(segments, current, c1, c2, end, tol)
        current = end
    return current


def recording_to_segments(commands: Iterable[tuple[str, tuple]], tol_font_units: float) -> list[Segment]:
    segments: list[Segment] = []
    current: Point | None = None
    contour_start: Point | None = None

    for op, raw_points in commands:
        points = [tuple(map(float, p)) if p is not None else None for p in raw_points]
        if op == "moveTo":
            contour_start = points[0]
            current = contour_start
        elif op == "lineTo":
            assert current is not None
            end = points[0]
            append_segment(segments, current, end)
            current = end
        elif op == "qCurveTo":
            if current is None or contour_start is None:
                if not points or points[-1] is not None:
                    raise ValueError("qCurveTo encountered without an active contour")
                off_curves = [pt for pt in points[:-1] if pt is not None]
                if len(off_curves) < 2:
                    raise ValueError("Need at least two off-curve points to infer a contour start")
                implied_start = mid(off_curves[-1], off_curves[0])
                current = implied_start
                contour_start = implied_start
            current = flatten_qcurve(segments, current, contour_start, points, tol_font_units)
        elif op == "curveTo":
            assert current is not None
            current = flatten_curve(segments, current, points, tol_font_units)
        elif op == "closePath":
            if current is not None and contour_start is not None:
                append_segment(segments, current, contour_start)
            current = None
            contour_start = None
        elif op == "endPath":
            current = None
            contour_start = None
        else:
            raise ValueError(f"Unsupported pen operation: {op}")

    return segments


def format_float(value: float) -> str:
    if abs(value) < 5e-8:
        value = 0.0
    text = f"{value:.4f}"
    text = text.rstrip("0").rstrip(".")
    return "0" if text in {"", "-0"} else text


def format_array(values: Iterable[float]) -> str:
    return "[" + ", ".join(format_float(v) for v in values) + "]"


def glyph_bounds(segments: list[tuple[float, float, float, float]]) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []
    for x0, y0, x1, y1 in segments:
        xs.extend((x0, x1))
        ys.extend((y0, y1))
    if not xs:
        return (0.0, 0.0, 0.0, 0.0)
    return (min(xs), min(ys), max(xs), max(ys))


def shape_text(
    font_path: Path,
    tt_font: TTFont,
    text: str,
    direction: str,
    script: str | None,
    language: str | None,
) -> tuple[str, str | None, str | None, list[tuple[int, int, int, int, int]]]:
    if hb is None:
        resolved_direction = "ltr" if direction == "auto" else direction
        resolved_script = script or "Latn"
        resolved_language = language or "en"
        if resolved_direction != "ltr" or resolved_script != "Latn":
            raise SystemExit(
                "uharfbuzz is required for non-Latin or non-ltr shaping. Install the "
                "dependencies from requirements.txt, or use --reuse-layout-js to rebuild "
                "outlines from an existing generated data file."
            )

        cmap = tt_font.getBestCmap() or {}
        hmtx = tt_font["hmtx"].metrics
        shaped: list[tuple[int, int, int, int, int]] = []
        for cluster, ch in enumerate(text):
            glyph_name = cmap.get(ord(ch))
            if glyph_name is None:
                raise SystemExit(
                    f"Glyph fallback failed for U+{ord(ch):04X} ({ch!r}) in {font_path.name}. "
                    "Install uharfbuzz for full shaping support."
                )
            glyph_id = tt_font.getGlyphID(glyph_name)
            x_advance = hmtx[glyph_name][0]
            shaped.append((glyph_id, cluster, x_advance, 0, 0))
        return resolved_direction, resolved_script, resolved_language, shaped

    data = font_path.read_bytes()
    face = hb.Face(data)
    hb_font = hb.Font(face)
    hb_font.scale = (face.upem, face.upem)
    hb.ot_font_set_funcs(hb_font)

    buffer = hb.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    if direction != "auto":
        buffer.direction = direction
    if script:
        buffer.script = script
    if language:
        buffer.language = language

    hb.shape(hb_font, buffer)

    shaped = [
        (
            info.codepoint,
            info.cluster,
            pos.x_advance,
            pos.x_offset,
            pos.y_offset,
        )
        for info, pos in zip(buffer.glyph_infos, buffer.glyph_positions)
    ]
    return str(buffer.direction), str(buffer.script), str(buffer.language), shaped


def load_layout_from_generated_js(js_path: Path) -> tuple[str, str, str | None, str | None, list[ShapedRunEntry]]:
    node_program = """
const dataPath = process.argv[1];
global.window = {};
require(dataPath);
process.stdout.write(JSON.stringify({
  sourceText: window.FONT_SOURCE_TEXT,
  fontName: window.FONT_SOURCE_FONT,
  direction: window.FONT_DIRECTION,
  script: window.FONT_SCRIPT,
  language: window.FONT_LANGUAGE,
  run: window.FONT_LAYOUT_RUN_RAW
}));
"""
    result = subprocess.run(
        ["node", "-e", node_program, str(js_path.resolve())],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    run = [
        ShapedRunEntry(
            glyph_key=entry["glyphKey"],
            cluster=entry["cluster"],
            advance_em=entry["advanceEm"],
            x_offset_em=entry["xOffsetEm"],
            y_offset_em=entry["yOffsetEm"],
        )
        for entry in payload["run"]
    ]
    return (
        payload["sourceText"],
        payload["direction"],
        payload["script"],
        payload["language"],
        run,
    )


def extract_glyph_outline(
    glyph_set,
    glyph_name: str,
    glyph_id: int,
    units_per_em: float,
    tol_font_units: float,
) -> GlyphOutlineData:
    pen = DecomposingRecordingPen(glyph_set)
    glyph_set[glyph_name].draw(pen)
    raw_segments = recording_to_segments(pen.value, tol_font_units)
    segments = [
        (
            a[0] / units_per_em,
            a[1] / units_per_em,
            b[0] / units_per_em,
            b[1] / units_per_em,
        )
        for a, b in raw_segments
    ]
    return GlyphOutlineData(
        glyph_id=glyph_id,
        glyph_name=glyph_name,
        sample_bounds=glyph_bounds(segments),
        segments=segments,
    )


def extract_shaped_data(
    font_path: Path,
    text: str,
    flatness_em: float,
    direction: str,
    script: str | None,
    language: str | None,
    reuse_layout_js: Path | None,
) -> ShapedTextData:
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    glyph_order = font.getGlyphOrder()
    units_per_em = float(font["head"].unitsPerEm)
    tol_font_units = flatness_em * units_per_em

    glyphs: dict[str, GlyphOutlineData] = {}
    if reuse_layout_js is not None:
        resolved_text, resolved_direction, resolved_script, resolved_language, run = load_layout_from_generated_js(
            reuse_layout_js
        )
        glyph_ids = sorted({int(entry.glyph_key.removeprefix("gid")) for entry in run})
        for glyph_id in glyph_ids:
            glyph_name = glyph_order[glyph_id]
            glyph_key = f"gid{glyph_id}"
            glyphs[glyph_key] = extract_glyph_outline(
                glyph_set=glyph_set,
                glyph_name=glyph_name,
                glyph_id=glyph_id,
                units_per_em=units_per_em,
                tol_font_units=tol_font_units,
            )
    else:
        resolved_direction, resolved_script, resolved_language, shaped = shape_text(
            font_path=font_path,
            tt_font=font,
            text=text,
            direction=direction,
            script=script,
            language=language,
        )

        resolved_text = text
        run = []
        for glyph_id, cluster, x_advance, x_offset, y_offset in shaped:
            glyph_name = glyph_order[glyph_id]
            glyph_key = f"gid{glyph_id}"
            if glyph_key not in glyphs:
                glyphs[glyph_key] = extract_glyph_outline(
                    glyph_set=glyph_set,
                    glyph_name=glyph_name,
                    glyph_id=glyph_id,
                    units_per_em=units_per_em,
                    tol_font_units=tol_font_units,
                )
            run.append(
                ShapedRunEntry(
                    glyph_key=glyph_key,
                    cluster=cluster,
                    advance_em=x_advance / units_per_em,
                    x_offset_em=x_offset / units_per_em,
                    y_offset_em=y_offset / units_per_em,
                )
            )

    return ShapedTextData(
        source_text=resolved_text,
        font_name=font_path.name,
        direction=resolved_direction,
        script=resolved_script,
        language=resolved_language,
        glyphs=glyphs,
        run=run,
    )


def write_js(output_path: Path, shaped_text: ShapedTextData) -> None:
    max_segments = max((len(glyph.segments) for glyph in shaped_text.glyphs.values()), default=0)
    lines = [
        "// Generated by scripts/extract_outline_data.py",
        f"window.FONT_SOURCE_TEXT = {json.dumps(shaped_text.source_text, ensure_ascii=False)};",
        f"window.FONT_SOURCE_FONT = {json.dumps(shaped_text.font_name)};",
        f"window.FONT_DIRECTION = {json.dumps(shaped_text.direction)};",
        f"window.FONT_SCRIPT = {json.dumps(shaped_text.script)};",
        f"window.FONT_LANGUAGE = {json.dumps(shaped_text.language)};",
        f"window.MAX_GLYPH_SEGMENTS = {max_segments};",
        "window.FONT_OUTLINE_GLYPHS_RAW = {",
    ]

    glyph_items = list(shaped_text.glyphs.items())
    for glyph_index, (glyph_key, glyph) in enumerate(glyph_items):
        trailing_comma = "," if glyph_index < len(glyph_items) - 1 else ""
        lines.append(f"  {json.dumps(glyph_key)}: {{")
        lines.append(f"    glyphId: {glyph.glyph_id},")
        lines.append(f"    glyphName: {json.dumps(glyph.glyph_name)},")
        lines.append(f"    sampleBounds: {format_array(glyph.sample_bounds)},")
        lines.append("    segments: [")
        for seg_index, seg in enumerate(glyph.segments):
            seg_comma = "," if seg_index < len(glyph.segments) - 1 else ""
            lines.append(f"      {format_array(seg)}{seg_comma}")
        lines.append("    ]")
        lines.append(f"  }}{trailing_comma}")
    lines.append("};")
    lines.append("window.FONT_LAYOUT_RUN_RAW = [")

    for run_index, entry in enumerate(shaped_text.run):
        trailing_comma = "," if run_index < len(shaped_text.run) - 1 else ""
        lines.append("  {")
        lines.append(f"    glyphKey: {json.dumps(entry.glyph_key)},")
        lines.append(f"    cluster: {entry.cluster},")
        lines.append(f"    advanceEm: {format_float(entry.advance_em)},")
        lines.append(f"    xOffsetEm: {format_float(entry.x_offset_em)},")
        lines.append(f"    yOffsetEm: {format_float(entry.y_offset_em)}")
        lines.append(f"  }}{trailing_comma}")
    lines.append("];")
    lines.append("")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    args = parse_args()
    shaped_text = extract_shaped_data(
        font_path=args.font,
        text=args.text,
        flatness_em=args.flatness_em,
        direction=args.direction,
        script=args.script,
        language=args.language,
        reuse_layout_js=args.reuse_layout_js,
    )
    write_js(args.output, shaped_text)


if __name__ == "__main__":
    main()
