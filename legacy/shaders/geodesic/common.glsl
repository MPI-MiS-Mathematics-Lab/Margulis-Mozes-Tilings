#define PI 3.14159265358979
#define TAU 6.28318530717959

// ─── Viewport constants (must match script.js) ──────────────────────────────
const float UHP_SCALE = 4.0;
const float UHP_YOFF  = 1.5;
const float DISC_SCALE = 2.5;

// ─── Colors ──────────────────────────────────────────────────────────────────
const vec3 BG_COLOR       = vec3(1.0, 1.0, 0.98);
const vec3 EXTERIOR_COLOR = vec3(0.88, 0.88, 0.86);
const vec3 BOUNDARY_COLOR = vec3(0.15, 0.15, 0.2);
const vec3 GEODESIC_COLOR = vec3(0.1, 0.3, 0.7);
const vec3 POINT_A_COLOR  = vec3(0.85, 0.2, 0.2);
const vec3 POINT_B_COLOR  = vec3(0.15, 0.6, 0.3);

// ─── Cayley transform ───────────────────────────────────────────────────────
// Complex division helper: (a + ib) / (c + id)
vec2 cdiv(vec2 num, vec2 den) {
    float d = dot(den, den);
    return vec2(dot(num, den), num.y * den.x - num.x * den.y) / d;
}

// UHP → Poincaré disc:  w = (z − i) / (z + i)
vec2 uhpToDisc(vec2 z) {
    return cdiv(vec2(z.x, z.y - 1.0), vec2(z.x, z.y + 1.0));
}

// Poincaré disc → UHP:  z = i(1 + w) / (1 − w)
vec2 discToUHP(vec2 w) {
    return cdiv(vec2(-w.y, 1.0 + w.x), vec2(1.0 - w.x, -w.y));
}

// ─── SDF helpers ─────────────────────────────────────────────────────────────

// SDF to a line segment a→b
float sdfSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - a - t * ab);
}

// SDF to a circular arc going CCW from aStart for arcSpan radians
// on circle centered at C with radius R.
float sdfArc(vec2 p, vec2 C, float R, float aStart, float arcSpan) {
    float ap = atan(p.y - C.y, p.x - C.x);
    float da = mod(ap - aStart, TAU);       // angle of p relative to arc start [0, TAU)
    float t;
    if (da <= arcSpan) {
        t = da;                              // on the arc
    } else {
        // Outside: snap to whichever endpoint is closer
        t = (TAU - da < da - arcSpan) ? 0.0 : arcSpan;
    }
    vec2 closest = C + R * vec2(cos(aStart + t), sin(aStart + t));
    return length(p - closest);
}

// ─── Geodesic SDF in Upper Half-Plane ────────────────────────────────────────
float geodesicSDF_UHP(vec2 p, vec2 z1, vec2 z2) {
    // Vertical geodesic (degenerate semicircle)
    if (abs(z1.x - z2.x) < 0.001) {
        float yc = clamp(p.y, min(z1.y, z2.y), max(z1.y, z2.y));
        return length(p - vec2(0.5 * (z1.x + z2.x), yc));
    }

    // Semicircle centered on x-axis
    float cx = (dot(z1, z1) - dot(z2, z2)) / (2.0 * (z1.x - z2.x));
    float R  = length(z1 - vec2(cx, 0.0));
    vec2  C  = vec2(cx, 0.0);

    // Both endpoint angles are in (0, π) since y > 0
    float a1 = atan(z1.y, z1.x - cx);
    float a2 = atan(z2.y, z2.x - cx);

    // CCW arc from smaller to larger angle (always valid in upper half-plane)
    return sdfArc(p, C, R, min(a1, a2), abs(a2 - a1));
}

// ─── Geodesic SDF in Poincaré Disc ──────────────────────────────────────────
float geodesicSDF_Disc(vec2 p, vec2 w1, vec2 w2) {
    // Diameter case (w1, w2, origin are collinear)
    float cv = w1.x * w2.y - w1.y * w2.x;
    if (abs(cv) < 0.0001) {
        return sdfSegment(p, w1, w2);
    }

    // Circle orthogonal to unit circle through w1 and w2
    float r1sq = dot(w1, w1), r2sq = dot(w2, w2);
    float det  = 2.0 * cv;
    vec2  C = vec2(
        (w2.y * (r1sq + 1.0) - w1.y * (r2sq + 1.0)) / det,
        (w1.x * (r2sq + 1.0) - w2.x * (r1sq + 1.0)) / det
    );
    float R = sqrt(max(dot(C, C) - 1.0, 0.0001));

    float a1 = atan(w1.y - C.y, w1.x - C.x);
    float a2 = atan(w2.y - C.y, w2.x - C.x);

    // Pick the arc that lies inside the unit disc
    float span = mod(a2 - a1, TAU);
    vec2 mid = C + R * vec2(cos(a1 + span * 0.5), sin(a1 + span * 0.5));

    if (dot(mid, mid) < 1.0) {
        return sdfArc(p, C, R, a1, span);
    } else {
        return sdfArc(p, C, R, a2, TAU - span);
    }
}
