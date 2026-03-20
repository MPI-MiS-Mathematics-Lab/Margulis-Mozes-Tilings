#!/usr/bin/env python3
"""Serve the Stanford Bunny potpourri3d heat viewer."""

from __future__ import annotations

import argparse
import json
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

try:
    from .mesh_heat_bunny_potpourri import build_demo_scene
except ImportError:
    from mesh_heat_bunny_potpourri import build_demo_scene


ROOT = Path(__file__).resolve().parents[1]


class MeshHeatBunnyPotpourriHandler(SimpleHTTPRequestHandler):
    scene_cache: dict | None = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path == "/api/scene":
            self._serve_scene()
            return
        if parsed.path == "/":
            self.path = "/mesh-heat-viewer/index.html"
        super().do_GET()

    def _serve_scene(self) -> None:
        if MeshHeatBunnyPotpourriHandler.scene_cache is None:
            MeshHeatBunnyPotpourriHandler.scene_cache = build_demo_scene()

        payload = json.dumps(MeshHeatBunnyPotpourriHandler.scene_cache).encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt: str, *args) -> None:
        print(f"[mesh-heat-bunny] {self.address_string()} - {fmt % args}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve the Stanford Bunny potpourri3d viewer.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host.")
    parser.add_argument("--port", type=int, default=8013, help="Bind port.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    with ThreadingHTTPServer((args.host, args.port), MeshHeatBunnyPotpourriHandler) as server:
        url = f"http://{args.host}:{args.port}/"
        print(f"Stanford Bunny potpourri3d viewer available at {url}")
        server.serve_forever()


if __name__ == "__main__":
    main()
