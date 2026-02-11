// Single Margulis-Mozes polygon P_a — Poincaré disc model.
//
// Renders one polygon with Euclidean SDF boundary.
// Vertices are defined in UHP and mapped to the disc via Cayley transform.
//
// Polygon P_a (Theorem 5) with m = n-3 >= 2, a > 0:
//   Bottom vertices: V_k = (k*a, 1)  for k = 0, 1, ..., m
//   Top-right:       (m*a, m)
//   Top-left:        (0, m)

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
const vec3 BG_COLOR   = vec3(1.0);
const vec3 FILL_COLOR = vec3(0.42, 0.72, 0.98);
const vec3 EDGE_COLOR = vec3(0.15);

// ─── Complex arithmetic ─────────────────────────────────────────────────────
vec2 cdiv(vec2 num, vec2 den){
  float d = dot(den, den);
  return vec2(dot(num, den), num.y*den.x - num.x*den.y) / d;
}

// UHP → Poincaré disc:  w = (z − i) / (z + i)
vec2 uhpToDisc(vec2 z){
  return cdiv(vec2(z.x, z.y - 1.0), vec2(z.x, z.y + 1.0));
}

// Poincaré disc → UHP:  z = i(1 + w) / (1 − w)
vec2 discToUHP(vec2 w){
  return cdiv(vec2(-w.y, 1.0 + w.x), vec2(1.0 - w.x, -w.y));
}

// ─── SDF helpers ─────────────────────────────────────────────────────────────

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

// Euclidean SDF to a geodesic segment in the Poincaré disc between w1 and w2
float geodesicSDF_Disc(vec2 p, vec2 w1, vec2 w2){
  // Diameter case (w1, w2, origin are collinear)
  float cv = w1.x*w2.y - w1.y*w2.x;
  if(abs(cv) < 0.0001){
    return sdfSegment(p, w1, w2);
  }

  // Circle orthogonal to unit circle through w1 and w2
  float r1sq = dot(w1, w1), r2sq = dot(w2, w2);
  float det  = 2.0 * cv;
  vec2  C = vec2(
    (w2.y*(r1sq + 1.0) - w1.y*(r2sq + 1.0)) / det,
    (w1.x*(r2sq + 1.0) - w2.x*(r1sq + 1.0)) / det
  );
  float R = sqrt(max(dot(C, C) - 1.0, 0.0001));

  float a1 = atan(w1.y - C.y, w1.x - C.x);
  float a2 = atan(w2.y - C.y, w2.x - C.x);

  // Pick the arc that lies inside the unit disc
  float span = mod(a2 - a1, TAU);
  vec2 mid = C + R * vec2(cos(a1 + span*0.5), sin(a1 + span*0.5));

  if(dot(mid, mid) < 1.0){
    return sdfArc(p, C, R, a1, span);
  } else {
    return sdfArc(p, C, R, a2, TAU - span);
  }
}

// ─── Inside/outside test (in UHP coords) ─────────────────────────────────────

// Sign of (|z-c|^2 - r^2): positive = above geodesic, negative = below
float geodesicSide(float ea, float eb, vec2 z){
  float c = 0.5*(ea + eb);
  float r = 0.5*abs(eb - ea);
  float dx = z.x - c;
  return dx*dx + z.y*z.y - r*r;
}

bool insidePolygon(vec2 z, float m, float a){
  float tW = m * a;

  // Must be between vertical edges
  if(z.x < 0.0 || z.x > tW) return false;

  // Must be below top geodesic
  float topCx = tW * 0.5;
  float topR  = sqrt(topCx*topCx + m*m);
  if(geodesicSide(topCx - topR, topCx + topR, z) > 0.0) return false;

  // Must be above each bottom bump
  for(int k = 0; k < MAX_CHILDREN; k++){
    if(float(k) >= m) break;
    float ck = (float(k) + 0.5) * a;
    float r0 = sqrt(a*a*0.25 + 1.0);
    if(geodesicSide(ck - r0, ck + r0, z) < 0.0) return false;
  }

  return true;
}

void main(){
  float m  = max(uChildren, 2.0);
  float a  = max(uParam, 0.01);
  float hw = max(uThickness, 0.001);
  float tW = m * a;

  vec2 R  = uResolution;
  vec2 uv = (vPos*0.5 + 0.5) * R;
  vec2 s  = (2.0*uv - R) / R.y;

  float r2 = dot(s, s);
  vec3 col = BG_COLOR;

  if(r2 < 1.0){
    vec2 p = s;  // disc coordinates

    float pixel = 2.0 / R.y;
    float aa    = 1.5 * pixel;

    // Cayley transform to UHP for inside/outside test
    vec2 z = discToUHP(p);

    bool inside = (z.y > 0.0) && insidePolygon(z, m, a);

    // ─── Compute Euclidean SDF in disc coords ─────────────────────────
    float d = 1e10;

    // Bottom edges: m geodesic arcs
    for(int k = 0; k < MAX_CHILDREN; k++){
      if(float(k) >= m) break;
      vec2 w1 = uhpToDisc(vec2(float(k) * a, 1.0));
      vec2 w2 = uhpToDisc(vec2(float(k + 1) * a, 1.0));
      d = min(d, geodesicSDF_Disc(p, w1, w2));
    }

    // Top edge: geodesic arc (0, m) → (tW, m)
    vec2 wTL = uhpToDisc(vec2(0.0, m));
    vec2 wTR = uhpToDisc(vec2(tW, m));
    d = min(d, geodesicSDF_Disc(p, wTL, wTR));

    // Left edge: (0, 1) → (0, m)
    vec2 wBL = uhpToDisc(vec2(0.0, 1.0));
    d = min(d, geodesicSDF_Disc(p, wBL, wTL));

    // Right edge: (tW, 1) → (tW, m)
    vec2 wBR = uhpToDisc(vec2(tW, 1.0));
    d = min(d, geodesicSDF_Disc(p, wBR, wTR));

    // ─── Render ───────────────────────────────────────────────────────

    // Interior fill
    if(inside){
      col = FILL_COLOR;
    }

    // Edge lines with hyperbolic width
    // Conformal factor: Euclidean half-width = hw * (1 - |w|^2) / 2
    float conformal = max((1.0 - r2) * 0.5, 0.0);
    float hypThick  = hw * conformal;
    float edgeLine  = smoothstep(hypThick + aa, max(hypThick - aa, 0.0), d);
    col = mix(col, EDGE_COLOR, edgeLine);

    // Disc boundary fade
    float dr = 1.0 - sqrt(r2);
    float px = fwidth(s.x) + fwidth(s.y);
    float edge = smoothstep(0.0, 2.0*px, dr);
    col = mix(BG_COLOR, col, edge);
  }

  gl_FragColor = vec4(col, 1.0);
}
