#!/usr/bin/env python3
"""Stanford Bunny text-on-mesh scene built on potpourri3d."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np

import potpourri3d as pp3d

try:
    from .mesh_curve import (
        build_signed_polyline_frame,
        dedupe_polyline,
    )
    from .mesh_geometry import build_vertex_normals
    from .mesh_text import build_text_outline_payload
except ImportError:
    from mesh_curve import (
        build_signed_polyline_frame,
        dedupe_polyline,
    )
    from mesh_geometry import build_vertex_normals
    from mesh_text import build_text_outline_payload

# ==========================================
# CONFIGURATION
# ==========================================
CONFIG = {
    "text": {
        "content": "الخَيْلُ وَاللّيْلُ وَالبَيْداءُ تَعرِفُني وَالسّيفُ وَالرّمحُ والقرْطاسُ وَالقَلَمُ",
        "font_url": "/fonts/NotoNaskhArabic-Regular.ttf",
        "fit_width": 0.97,   # Aspect ratio width for the vector text box
        "fit_height": 0.17,  # Aspect ratio height for the vector text box
        "direction": "rtl",
        "script": "Arab",
        "language": "ar",
    },
    "routing": {
        # 3D Waypoints in PCA space guiding the centerline around the bunny
        "targets": [
            np.array([-0.070, 0.001, 0.022], dtype=np.float64),
            np.array([-0.030, 0.008, 0.023], dtype=np.float64),
            np.array([0.005, 0.012, 0.024], dtype=np.float64),
            np.array([0.035, 0.011, 0.021], dtype=np.float64),
            np.array([0.055, 0.008, 0.016], dtype=np.float64),
        ],
        # Penalizes distance on certain axes to keep the line centered
        "pca_weights": np.array([1.0, 2.0, 3.0], dtype=np.float64),
        "scale_quantile": 0.9, # Ignores top 10% of extremities (like ears) for scale bounding
    },
    "mapping": {
        "strip_quantile": 0.98, # Calculates physical band width, ignoring top 2% furthest points
        "v_center": 0.5,        # Centers the text exactly in the middle of the UV canvas
        "v_scale": 2.4,         # Spreads/compresses the vertical mapping (higher = tighter wrap)
        "v_extent": 0.1,        # The rendering/clipping limit for the band in the viewer
    },
    "hybrid_distance": {
        "inner_source_gap_factor": 1.5, # Fully trust continuous polyline distance inside this band
        "outer_source_gap_factor": 4.5, # Blend back to heat distance outside this band
    }
}
# ==========================================

ROOT = Path(__file__).resolve().parents[1]
BUNNY_PATH = ROOT / "assets" / "bunny" / "reconstruction" / "bun_zipper.ply"


def load_bunny_mesh() -> tuple[np.ndarray, np.ndarray]:
    if not BUNNY_PATH.exists():
        raise SystemExit(
            "Stanford Bunny mesh not found. Download it first with:\n"
            "  curl -L --max-time 60 https://graphics.stanford.edu/pub/3Dscanrep/bunny.tar.gz -o assets/bunny.tar.gz\n"
            "  tar -xzf assets/bunny.tar.gz -C assets bunny/reconstruction"
        )
    vertices, faces = pp3d.read_mesh(str(BUNNY_PATH))
    vertices = vertices.astype(np.float64)
    faces = faces.astype(np.int32)

    used_vertices = np.unique(faces.reshape(-1))
    remap = np.full(vertices.shape[0], -1, dtype=np.int32)
    remap[used_vertices] = np.arange(used_vertices.shape[0], dtype=np.int32)
    compact_vertices = vertices[used_vertices]
    compact_faces = remap[faces]
    return compact_vertices, compact_faces


def pca_coordinates(vertices: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    centered = vertices - vertices.mean(axis=0, keepdims=True)
    evals, evecs = np.linalg.eigh(centered.T @ centered)
    basis = evecs[:, np.argsort(evals)[::-1]]
    coords = centered @ basis
    return coords, basis


def pick_body_anchor(coords: np.ndarray, target: np.ndarray) -> int:
    scale = np.quantile(np.abs(coords), CONFIG["routing"]["scale_quantile"], axis=0)
    weights = CONFIG["routing"]["pca_weights"]
    distance2 = np.sum(((coords - target) / np.maximum(scale, 1e-8)) ** 2 * weights, axis=1)
    return int(np.argmin(distance2))


def build_bunny_centerline(vertices: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    coords, _ = pca_coordinates(vertices)
    anchors = [pick_body_anchor(coords, target) for target in CONFIG["routing"]["targets"]]
    return np.asarray(anchors, dtype=np.int32), coords


def nearest_vertices_to_polyline(vertices: np.ndarray, polyline_positions: np.ndarray) -> np.ndarray:
    nearest: list[int] = []
    for point in polyline_positions:
        vertex_index = int(np.argmin(np.einsum("ij,ij->i", vertices - point[None, :], vertices - point[None, :])))
        if not nearest or vertex_index != nearest[-1]:
            nearest.append(vertex_index)
    return np.asarray(nearest, dtype=np.int32)


def estimate_source_gap_median(vertices: np.ndarray, sampled_vertices: np.ndarray) -> float:
    if sampled_vertices.shape[0] < 2:
        return 0.0
    sampled_positions = vertices[sampled_vertices]
    sampled_gaps = np.linalg.norm(sampled_positions[1:] - sampled_positions[:-1], axis=1)
    return float(np.median(sampled_gaps))


def blend_near_center_distance(
    heat_distance: np.ndarray,
    polyline_distance: np.ndarray,
    inner_radius: float,
    outer_radius: float,
) -> np.ndarray:
    if outer_radius <= inner_radius + 1e-12:
        return polyline_distance.copy()

    blend = np.clip((polyline_distance - inner_radius) / (outer_radius - inner_radius), 0.0, 1.0)
    blend = blend * blend * (3.0 - 2.0 * blend)
    return (1.0 - blend) * polyline_distance + blend * heat_distance


def build_demo_scene() -> dict[str, Any]:
    vertices, faces = load_bunny_mesh()
    vertex_normals = build_vertex_normals(vertices, faces)
    
    text = CONFIG["text"]["content"]
    font_url = CONFIG["text"]["font_url"]

    anchor_indices, _ = build_bunny_centerline(vertices)
    geodesic_positions = np.asarray(
        pp3d.EdgeFlipGeodesicSolver(vertices, faces).find_geodesic_path_poly(anchor_indices.tolist()),
        dtype=np.float64,
    )
    centerline_positions = dedupe_polyline(geodesic_positions)
    centerline_source_vertices = nearest_vertices_to_polyline(vertices, centerline_positions)

    curve_distance = np.asarray(
        pp3d.MeshHeatMethodDistanceSolver(vertices, faces).compute_distance_multisource(centerline_source_vertices.tolist()),
        dtype=np.float64,
    )
    chart_u, centerline_u, curve_distance_polyline, curve_signs = build_signed_polyline_frame(
        vertices,
        vertex_normals,
        centerline_positions,
    )
    source_gap_median = estimate_source_gap_median(vertices, centerline_source_vertices)
    hybrid_inner_radius = max(
        CONFIG["hybrid_distance"]["inner_source_gap_factor"] * source_gap_median,
        1e-6,
    )
    hybrid_outer_radius = max(
        CONFIG["hybrid_distance"]["outer_source_gap_factor"] * source_gap_median,
        hybrid_inner_radius + 1e-6,
    )
    curve_distance_hybrid = blend_near_center_distance(
        heat_distance=curve_distance,
        polyline_distance=curve_distance_polyline,
        inner_radius=hybrid_inner_radius,
        outer_radius=hybrid_outer_radius,
    )
    signed_curve_distance = curve_distance_hybrid * curve_signs
    chart_u = 1.0 - chart_u
    centerline_u = 1.0 - centerline_u

    strip_scale = max(float(np.quantile(np.abs(signed_curve_distance), CONFIG["mapping"]["strip_quantile"])), 1e-6)
    chart_v = CONFIG["mapping"]["v_center"] - CONFIG["mapping"]["v_scale"] * (signed_curve_distance / strip_scale)

    return {
        "name": "stanford_bunny",
        "solverName": "potpourri3d - Stanford Bunny",
        "fieldLabels": {
            "curveDistance": "Curve Heat Distance",
            "curveDistanceHybrid": "Curve Hybrid Distance",
            "signedCurveDistance": "Signed Curve Distance",
        },
        "divergingFields": ["signedCurveDistance"],
        "text": text,
        "fontUrl": font_url,
        "textOutlineData": build_text_outline_payload(
            text=text,
            font_url=font_url,
            direction=CONFIG["text"]["direction"],
            script=CONFIG["text"]["script"],
            language=CONFIG["text"]["language"],
        ),
        "textFitWidth": CONFIG["text"]["fit_width"],
        "textFitHeight": CONFIG["text"]["fit_height"],
        "positions": vertices.astype(np.float32).reshape(-1).tolist(),
        "faces": faces.astype(np.int32).reshape(-1).tolist(),
        "vertexNormals": vertex_normals.astype(np.float32).reshape(-1).tolist(),
        "centerlinePositions": centerline_positions.astype(np.float32).reshape(-1).tolist(),
        "centerlineU": centerline_u.astype(np.float32).tolist(),
        "chartU": chart_u.astype(np.float32).tolist(),
        "chartV": chart_v.astype(np.float32).tolist(),
        "defaultField": "curveDistance",
        "fields": {
            "curveDistance": curve_distance.astype(np.float32).tolist(),
            "curveDistanceHybrid": curve_distance_hybrid.astype(np.float32).tolist(),
            "signedCurveDistance": signed_curve_distance.astype(np.float32).tolist(),
        },
        "ranges": {
            "curveDistance": [float(np.min(curve_distance)), float(np.max(curve_distance))],
            "curveDistanceHybrid": [
                float(np.min(curve_distance_hybrid)),
                float(np.max(curve_distance_hybrid)),
            ],
            "signedCurveDistance": [
                float(np.min(signed_curve_distance)),
                float(np.max(signed_curve_distance)),
            ],
        },
        "textBand": {
            "stripScale": strip_scale,
            "vCenter": CONFIG["mapping"]["v_center"],
            "vExtent": CONFIG["mapping"]["v_extent"],
        },
        "summary": {
            "nVertices": int(vertices.shape[0]),
            "nFaces": int(faces.shape[0]),
            "curveVertices": int(centerline_positions.shape[0]),
            "sourceVertices": int(centerline_source_vertices.shape[0]),
            "chartSignedField": "signedCurveDistance",
            "sourceGapMedian": source_gap_median,
            "hybridBlendInner": hybrid_inner_radius,
            "hybridBlendOuter": hybrid_outer_radius,
        },
    }
