#!/usr/bin/env python3
"""Shared helpers for sampled curves on triangle meshes."""

from __future__ import annotations

import numpy as np


EPS = 1e-12


def dedupe_polyline(points: np.ndarray, tol: float = 1e-8) -> np.ndarray:
    deduped = [points[0]]
    for point in points[1:]:
        if np.linalg.norm(point - deduped[-1]) > tol:
            deduped.append(point)
    return np.asarray(deduped, dtype=np.float64)


def build_signed_polyline_frame(
    positions: np.ndarray,
    vertex_normals: np.ndarray,
    centerline_positions: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    segments = centerline_positions[1:] - centerline_positions[:-1]
    seg_lengths = np.linalg.norm(segments, axis=1)
    cumulative = np.concatenate([[0.0], np.cumsum(seg_lengths)])
    total_length = max(float(cumulative[-1]), EPS)

    best_dist2 = np.full(positions.shape[0], np.inf, dtype=np.float64)
    best_s = np.zeros(positions.shape[0], dtype=np.float64)
    best_side = np.zeros((positions.shape[0], 3), dtype=np.float64)
    best_points = np.zeros((positions.shape[0], 3), dtype=np.float64)
    centerline_offsets = positions[:, None, :] - centerline_positions[None, :, :]
    centerline_nearest_vertices = np.argmin(
        np.einsum("ijk,ijk->ij", centerline_offsets, centerline_offsets),
        axis=0,
    )
    centerline_normals = np.asarray(vertex_normals[centerline_nearest_vertices], dtype=np.float64).copy()
    centerline_normals /= np.maximum(np.linalg.norm(centerline_normals, axis=1, keepdims=True), EPS)

    for idx in range(1, centerline_normals.shape[0]):
        if float(np.dot(centerline_normals[idx - 1], centerline_normals[idx])) < 0.0:
            centerline_normals[idx] *= -1.0

    for seg_idx, (p0, p1) in enumerate(zip(centerline_positions[:-1], centerline_positions[1:])):
        seg = p1 - p0
        seg_len2 = float(np.dot(seg, seg))
        if seg_len2 <= EPS:
            continue
        t = np.clip(((positions - p0) @ seg) / seg_len2, 0.0, 1.0)
        proj = p0 + t[:, None] * seg[None, :]
        dist2 = np.einsum("ij,ij->i", positions - proj, positions - proj)

        improved = dist2 < best_dist2
        if not np.any(improved):
            continue

        normal = centerline_normals[seg_idx] * (1.0 - t[:, None]) + centerline_normals[seg_idx + 1] * t[:, None]
        normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), EPS)
        tangent = seg / np.sqrt(seg_len2)
        side = np.cross(normal, tangent[None, :])
        side /= np.maximum(np.linalg.norm(side, axis=1, keepdims=True), EPS)

        best_dist2[improved] = dist2[improved]
        best_s[improved] = cumulative[seg_idx] + t[improved] * np.sqrt(seg_len2)
        best_side[improved] = side[improved]
        best_points[improved] = proj[improved]

    polyline_distance = np.sqrt(np.maximum(best_dist2, 0.0))
    offset = positions - best_points
    signs = np.sign(np.einsum("ij,ij->i", offset, best_side))
    signs[signs == 0.0] = 1.0

    centerline_u = cumulative / total_length
    chart_u = best_s / total_length
    return chart_u, centerline_u, polyline_distance, signs
