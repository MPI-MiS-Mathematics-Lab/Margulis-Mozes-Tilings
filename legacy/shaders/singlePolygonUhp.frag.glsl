// Single Margulis-Mozes polygon P_a — Upper Half-Plane model.
//
// Renders one polygon with Euclidean SDF boundary in UHP coordinates.
// Useful for studying the geodesic segment geometry.
//
// Polygon P_a (Theorem 5) with m = n-3 >= 2, a > 0:
//   Bottom vertices: V_k = (k*a, 1)  for k = 0, 1, ..., m
//   Top-right:       (m*a, m)
//   Top-left:        (0, m)
//
// Edges:
//   Bottom: m geodesic arcs V_k -> V_{k+1}  (bumps)
//   Right:  vertical geodesic x = m*a,  y in [1, m]
//   Top:    geodesic arc (0, m) -> (m*a, m)
//   Left:   vertical geodesic x = 0,    y in [1, m]

#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2  uResolution;
uniform float uThickness;   // Hyperbolic edge line width
uniform float uChildren;    // Branching factor m = n-3 (>= 2)
uniform float uParam;       // Vertex spacing parameter a (> 0)
varying vec2  vPos;

#define PI  3.14159265358979
#define TAU 6.28318530717959
#define MAX_CHILDREN 16

// ─── Colors ──────────────────────────────────────────────────────────────────
const vec3 BG_COLOR    = vec3(0.06);
const vec3 FILL_COLOR  = vec3(0.42, 0.72, 0.98);
const vec3 EDGE_COLOR  = vec3(0.15);
const vec3 AXIS_COLOR  = vec3(0.85);

// ─── SDF helpers (from geodesic reference) ───────────────────────────────────

// Euclidean SDF to a line segment a→b
float sdfSegment(vec2 p, vec2 a, vec2 b){
  vec2 ab = b - a;
  float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
  return length(p - a - t * ab);
}

// Euclidean SDF to a circular arc (CCW from aStart for arcSpan radians)
float sdfArc(vec2 p, vec2 C, float R, float aStart, float arcSpan){
  float ap = atan(p.y - C.y, p.x - C.x);
  float da = mod(ap - aStart, TAU);
  float t;
  if(da <= arcSpan){
    t = da;
  } else {
    t = (TAU - da < da - arcSpan) ? 0.0 : arcSpan;
  }
  vec2 closest = C + R * vec2(cos(aStart + t), sin(aStart + t));
  return length(p - closest);
}

// Euclidean SDF to a geodesic segment in UHP between z1 and z2
float geodesicSDF(vec2 p, vec2 z1, vec2 z2){
  // Vertical geodesic (degenerate semicircle)
  if(abs(z1.x - z2.x) < 0.001){
    float yc = clamp(p.y, min(z1.y, z2.y), max(z1.y, z2.y));
    return length(p - vec2(0.5*(z1.x + z2.x), yc));
  }

  // Semicircle centered on x-axis
  float cx = (dot(z1, z1) - dot(z2, z2)) / (2.0*(z1.x - z2.x));
  float R  = length(z1 - vec2(cx, 0.0));
  vec2  C  = vec2(cx, 0.0);

  float a1 = atan(z1.y, z1.x - cx);
  float a2 = atan(z2.y, z2.x - cx);

  // CCW arc from smaller to larger angle (valid in upper half-plane)
  return sdfArc(p, C, R, min(a1, a2), abs(a2 - a1));
}

// ─── Inside/outside test helpers ─────────────────────────────────────────────

// Sign of (|z-c|^2 - r^2): positive = above geodesic, negative = below
float geodesicSide(float ea, float eb, vec2 z){
  float c = 0.5*(ea + eb);
  float r = 0.5*abs(eb - ea);
  float dx = z.x - c;
  return dx*dx + z.y*z.y - r*r;
}

// ─── Viewport (auto-centers on polygon) ──────────────────────────────────────

vec2 toWorld(vec2 fragCoord, float m, float a){
  float tW   = m * a;
  float cx   = tW * 0.5;
  float cy   = (1.0 + m) * 0.5;
  float span = max(tW, m) * 0.7 + 1.5;

  float scale = uResolution.y / (2.0 * span);
  float worldX = (fragCoord.x - 0.5*uResolution.x) / scale + cx;
  float worldY = fragCoord.y / scale + cy - span;
  return vec2(worldX, worldY);
}

void main(){
  float m  = max(uChildren, 2.0);
  float a  = max(uParam, 0.01);
  float hw = max(uThickness, 0.001);
  float tW = m * a;

  vec2 fragCoord = (vPos*0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord, m, a);

  // Pixel size in world coords (for anti-aliasing)
  float span  = max(tW, m) * 0.7 + 1.5;
  float pixel = 2.0 * span / uResolution.y;
  float aa    = 1.5 * pixel;

  vec3 col = BG_COLOR;

  // x-axis boundary
  float axD = abs(p.y);
  col = mix(AXIS_COLOR, col, smoothstep(pixel*0.5, pixel*2.0, axD));

  if(p.y > 0.0){
    // ─── Compute SDF to polygon boundary ───────────────────────────────
    float d = 1e10;
    bool inside = true;

    // Bottom edges: m geodesic arcs (ka, 1) → ((k+1)a, 1)
    for(int k = 0; k < MAX_CHILDREN; k++){
      if(float(k) >= m) break;
      vec2 v1 = vec2(float(k) * a, 1.0);
      vec2 v2 = vec2(float(k + 1) * a, 1.0);
      d = min(d, geodesicSDF(p, v1, v2));

      // Inside test: must be above each bump's full geodesic
      float ck = (float(k) + 0.5) * a;
      float r0 = sqrt(a*a*0.25 + 1.0);
      if(geodesicSide(ck - r0, ck + r0, p) < 0.0) inside = false;
    }

    // Top edge: geodesic arc (0, m) → (tW, m)
    d = min(d, geodesicSDF(p, vec2(0.0, m), vec2(tW, m)));
    // Inside test: must be below top geodesic
    float topCx = tW * 0.5;
    float topR  = sqrt(topCx*topCx + m*m);
    if(geodesicSide(topCx - topR, topCx + topR, p) > 0.0) inside = false;

    // Left edge: vertical segment (0, m) → (0, 1)
    d = min(d, sdfSegment(p, vec2(0.0, 1.0), vec2(0.0, m)));
    if(p.x < 0.0) inside = false;

    // Right edge: vertical segment (tW, 1) → (tW, m)
    d = min(d, sdfSegment(p, vec2(tW, 1.0), vec2(tW, m)));
    if(p.x > tW) inside = false;

    // ─── Render ────────────────────────────────────────────────────────

    // Interior fill
    if(inside){
      col = FILL_COLOR;
    }

    // Edge lines with hyperbolic width (Euclidean half-width = hw * y)
    float hypThick = hw * max(p.y, 0.001);
    float edgeLine = smoothstep(hypThick + aa, max(hypThick - aa, 0.0), d);
    col = mix(col, EDGE_COLOR, edgeLine);
  }

  gl_FragColor = vec4(col, 1.0);
}
