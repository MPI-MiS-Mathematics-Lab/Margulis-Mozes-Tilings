"""
mm_coloring: addresses, colorings, and tile geometry for the m-ary
Margulis-Mozes tilings (Theorem 5 of Margulis-Mozes 1998).

This is the Python port of the GLSL coloring logic (getColor in
shaders/margulisMozesSdf3colorUhp.frag.glsl and its even-m sibling),
together with the greedy algorithm of the paper, the alternative m=2
formula from the legacy binary shaders, and the Theorem-5 tile geometry
used by the figure pipeline in the paper repository.

Conventions (match the paper):
  - address (h, l) in Z x Z; parent(h, l) = (h-1, floor(l/m));
  - h increases toward the ideal boundary (smaller y in UHP);
  - tile (h, l) occupies y in [m^-h, m^-h+1), x in [l*w, (l+1)*w) with
    w = m*a*m^-h, and is the Theorem-5 polygon P_a scaled by m^-h.

The color ids have a fixed meaning across every figure of the paper:
  0 -> PALETTE[0] (salmon), 1 -> PALETTE[1] (sky blue), 2 -> PALETTE[2]
  (light green), identical to the production shaders.
"""

from __future__ import annotations

import math
from typing import Callable, Dict, List, Optional, Tuple

# Palette of the production shaders: vec3(0.93,0.40,0.40),
# vec3(0.42,0.72,0.98), vec3(0.52,0.92,0.56).
PALETTE = ("#ed6666", "#6bb8fa", "#85eb8f")
INK = "#262626"


# ---------------------------------------------------------------------------
# digit machinery
# ---------------------------------------------------------------------------

def digits_eps(l: int, m: int) -> Tuple[List[int], int]:
    """Floor-division base-m digits of l (LSB first) and terminator in {0,-1}."""
    ds: List[int] = []
    q = l
    while q not in (0, -1):
        ds.append(q - m * (q // m))
        q = q // m
    return ds, q


def s_odd(l: int, m: int) -> int:
    """Count of odd digits in the signed base-m expansion."""
    ds, _ = digits_eps(l, m)
    return sum(1 for d in ds if d & 1)


def T_even(l: int, m: int) -> int:
    """Parity-transition count of the digit-parity sequence extended by the tail."""
    ds, eps = digits_eps(l, m)
    tail = (m - 1) & 1 if eps == -1 else 0
    par = [d & 1 for d in ds] + [tail]
    return sum(1 for i in range(len(par) - 1) if par[i] != par[i + 1])


def closed_form(h: int, l: int, m: int) -> int:
    """The paper's closed-form 3-coloring: s_m for odd m, T_m for even m."""
    _, eps = digits_eps(l, m)
    g = s_odd(l, m) if m & 1 else T_even(l, m)
    return (h + g + abs(eps)) % 3


def alt_m2(h: int, l: int) -> int:
    """Legacy binary-shader 3-coloring of the m=2 tiling (and only m=2)."""
    pN = h % 2
    pJ = l % 3
    return (pN * pJ + (1 - pN) * (2 - pJ)) % 3


def descent_path(h: int, l: int, m: int) -> List[Tuple[int, int, Optional[int]]]:
    """Ancestor chain from the spine ancestor down to (h, l), for l >= 0.

    Returns [(h-k, 0, None), ..., (h, l, d0)]: each entry is a tile with the
    digit (child index) used to step into it, MSB first; the top entry has
    no incoming digit.
    """
    if l < 0:
        raise ValueError("descent_path is for l >= 0")
    ds, _ = digits_eps(l, m)
    k = len(ds)
    chain: List[Tuple[int, int, Optional[int]]] = [(h - k, 0, None)]
    idx = 0
    for i in range(k - 1, -1, -1):
        idx = idx * m + ds[i]
        chain.append((h - i, idx, ds[i]))
    return chain


# ---------------------------------------------------------------------------
# greedy algorithm (spine seed, pluggable choice rule)
# ---------------------------------------------------------------------------

def p0_of(j: int, m: int) -> int:
    """LSB-digit parity of j, with p0(0) = 0 and p0(-1) = 1."""
    if j == 0:
        return 0
    if j == -1:
        return 1
    ds, eps = digits_eps(j, m)
    return (ds[0] & 1) if ds else abs(eps)


def canonical_rule(m: int) -> Callable[[int, int], int]:
    """The choice rule whose greedy run equals the closed form."""
    if m & 1:
        return lambda p, j: (p + 1) % 3
    return lambda p, j: (p + 1 + p0_of(j, m)) % 3


class Greedy:
    """Spine-seeded greedy coloring with a pluggable rule at choice points.

    rule(p, j) -> color, called at the choice point (h, jm) where parent and
    left neighbor share color p. Colors are memoized; the recursion is
    well-founded because parent and left neighbor both have smaller l.
    """

    def __init__(self, m: int, rule: Optional[Callable[[int, int], int]] = None):
        self.m = m
        self.rule = rule or canonical_rule(m)
        self.cache: Dict[Tuple[int, int], int] = {}
        self.choice_points: set = set()

    def color(self, h: int, l: int) -> int:
        key = (h, l)
        if key in self.cache:
            return self.cache[key]
        m = self.m
        if l < 0:
            v = (self.color(h, -l - 1) + 1) % 3
        elif l == 0:
            v = h % 3
        elif l < m:
            v = (h + (l & 1)) % 3
        else:
            p = self.color(h - 1, l // m)
            a = self.color(h, l - 1)
            if p != a:
                v = (0 + 1 + 2) - p - a  # unique third color
            else:
                self.choice_points.add(key)
                v = self.rule(p, l // m)
        self.cache[key] = v
        return v

    def is_choice_point(self, h: int, l: int) -> bool:
        if l < self.m or l % self.m != 0:
            return False
        return self.color(h - 1, l // self.m) == self.color(h, l - 1)


# ---------------------------------------------------------------------------
# Truchet decoration formulas (band convention of the Truchet shaders:
# b = floor(log_m y) grows away from the boundary; the paper states these
# formulas in that convention and says so)
# ---------------------------------------------------------------------------

def motif(b: int, l: int) -> int:
    """Ternary Truchet motif selector t = (b + 2l) mod 3."""
    return (b + 2 * l) % 3


def flip_potential(b: int, l: int, motif_of: Callable[[int, int], int]) -> int:
    """Region-coloring potential g = [motif = 2] xor par(b) xor par(l)."""
    return ((1 if motif_of(b, l) == 2 else 0) ^ (b & 1) ^ (l & 1))


# ---------------------------------------------------------------------------
# Theorem-5 tile geometry (UHP)
# ---------------------------------------------------------------------------

def tile_vertices(m: int, a: float) -> List[complex]:
    """Vertices of P_a for branching factor m = n - 3, in Theorem-5 order.

    Bottom chain (k*a, 1) for k = 0..m, then top right (m*a, m), then top
    left (0, m). All edges are geodesics; the bottom chain consists of the
    m 'caps' that the children's top arches fill.
    """
    verts = [complex(k * a, 1.0) for k in range(m + 1)]
    verts.append(complex(m * a, float(m)))
    verts.append(complex(0.0, float(m)))
    return verts


def _geodesic_arc(z1: complex, z2: complex, samples: int = 48) -> List[complex]:
    """Sample the UHP geodesic from z1 to z2 (semicircle or vertical line)."""
    x1, y1, x2, y2 = z1.real, z1.imag, z2.real, z2.imag
    if abs(x1 - x2) < 1e-12:
        return [complex(x1, y1 + (y2 - y1) * t / samples) for t in range(samples + 1)]
    cx = ((x1 * x1 + y1 * y1) - (x2 * x2 + y2 * y2)) / (2.0 * (x1 - x2))
    r = math.hypot(x1 - cx, y1)
    t1 = math.atan2(y1, x1 - cx)
    t2 = math.atan2(y2, x2 - cx)
    return [complex(cx + r * math.cos(t1 + (t2 - t1) * t / samples),
                    r * math.sin(t1 + (t2 - t1) * t / samples))
            for t in range(samples + 1)]


def tile_boundary(h: int, l: int, m: int, a: float,
                  samples: int = 48) -> List[complex]:
    """Sampled boundary of tile (h, l): P_a scaled by m^-h, shifted by l*m*a*m^-h."""
    scale = float(m) ** (-h)
    shift = l * m * a * scale
    verts = tile_vertices(m, a)
    pts: List[complex] = []
    n = len(verts)
    for i in range(n):
        arc = _geodesic_arc(verts[i], verts[(i + 1) % n], samples)
        seg = [complex(z.real * scale + shift, z.imag * scale) for z in arc]
        pts.extend(seg[:-1])
    pts.append(pts[0])
    return pts


def tile_anchor(h: int, l: int, m: int, a: float) -> complex:
    """A visual anchor point inside tile (h, l) (for labels)."""
    scale = float(m) ** (-h)
    return complex((l + 0.5) * m * a * scale, 0.45 * (1 + m) * scale)


# ---------------------------------------------------------------------------
# self-test
# ---------------------------------------------------------------------------

def _self_test() -> None:
    # closed forms are proper and match the canonical greedy
    for m in range(2, 9):
        g = Greedy(m)
        for h in range(-2, 3):
            for l in range(-60, 61):
                c = closed_form(h, l, m)
                assert c != closed_form(h, l + 1, m), (m, h, l, "H")
                for k in range(m):
                    assert c != closed_form(h + 1, m * l + k, m), (m, h, l, k, "PC")
                assert g.color(h, l) == c, (m, h, l, "greedy")
    # alt formula proper for m = 2 and distinct from the closed form
    diff = 0
    for h in range(-4, 5):
        for l in range(-80, 81):
            c = alt_m2(h, l)
            assert c != alt_m2(h, l + 1), (h, l)
            for k in range(2):
                assert c != alt_m2(h + 1, 2 * l + k), (h, l, k)
            diff += int(c != closed_form(h, l, 2))
    assert diff > 0
    # descent path consistency: digits accumulate to the closed form (odd m)
    for m in (3, 5):
        for l in (5, 50, 121):
            chain = descent_path(0, l, m)
            assert chain[-1][1] == l
            acc = chain[0][0] % 3
            for (_, _, d) in chain[1:]:
                acc = (acc + 1 + (d & 1)) % 3
            assert acc == closed_form(0, l, m), (m, l)
    print("mm_coloring self-test: OK")


if __name__ == "__main__":
    _self_test()
