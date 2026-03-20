#!/usr/bin/env python3
"""Minimal geometry helpers used by the Stanford Bunny viewer."""

from __future__ import annotations

import numpy as np


EPS = 1e-12


def build_vertex_normals(vertices: np.ndarray, faces: np.ndarray) -> np.ndarray:
    face_normals = np.cross(
        vertices[faces[:, 1]] - vertices[faces[:, 0]],
        vertices[faces[:, 2]] - vertices[faces[:, 0]],
    )
    vertex_normals = np.zeros_like(vertices, dtype=np.float64)
    for local in range(3):
        np.add.at(vertex_normals, faces[:, local], face_normals)
    vertex_normals /= np.maximum(np.linalg.norm(vertex_normals, axis=1, keepdims=True), EPS)
    return vertex_normals
