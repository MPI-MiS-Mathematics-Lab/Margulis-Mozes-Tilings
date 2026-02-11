// Margulis-Mozes Theorem 5 tiling — UHP model, polygon SDF edge rendering.
//
// Same tiling algorithm as margulisMozesUhp, but edges are rendered via
// a unified Euclidean SDF to the polygon boundary (geodesic segments).

#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2  uResolution;
uniform float uThickness;
uniform float uChildren;
uniform float uParam;
uniform float uZoom;
varying vec2  vPos;

#define TAU 6.28318530717959
#define MAX_CHILDREN 16

vec3 color4(int id){
  if(id==0) return vec3(0.93,0.40,0.40);
  if(id==1) return vec3(0.42,0.72,0.98);
  if(id==2) return vec3(0.52,0.92,0.56);
  return vec3(0.95,0.86,0.45);
}

vec2 toWorld(vec2 fragCoord, float zoom){
  vec2 lo = vec2(-6.0 * zoom, 0.0);
  vec2 hi = vec2( 6.0 * zoom, 8.0 * zoom);
  vec2 sz = hi - lo;
  float sc = uResolution.y / sz.y;
  float cx = 0.5*(lo.x + hi.x);
  return vec2(
    (fragCoord.x - 0.5*uResolution.x)/sc + cx,
    fragCoord.y/sc + lo.y
  );
}

// ─── SDF helpers ─────────────────────────────────────────────────────────────

float sdfSegment(vec2 p, vec2 a, vec2 b){
  vec2 ab = b - a;
  float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
  return length(p - a - t * ab);
}

float sdfArc(vec2 p, vec2 C, float R, float aStart, float arcSpan){
  float ap = atan(p.y - C.y, p.x - C.x);
  float da = mod(ap - aStart, TAU);
  float t;
  if(da <= arcSpan) t = da;
  else t = (TAU - da < da - arcSpan) ? 0.0 : arcSpan;
  vec2 closest = C + R * vec2(cos(aStart + t), sin(aStart + t));
  return length(p - closest);
}

float geodesicSDF(vec2 p, vec2 z1, vec2 z2){
  if(abs(z1.x - z2.x) < 0.001){
    float yc = clamp(p.y, min(z1.y, z2.y), max(z1.y, z2.y));
    return length(p - vec2(0.5*(z1.x + z2.x), yc));
  }
  float cx = (dot(z1, z1) - dot(z2, z2)) / (2.0*(z1.x - z2.x));
  float R  = length(z1 - vec2(cx, 0.0));
  vec2  C  = vec2(cx, 0.0);
  float a1 = atan(z1.y, z1.x - cx);
  float a2 = atan(z2.y, z2.x - cx);
  return sdfArc(p, C, R, min(a1, a2), abs(a2 - a1));
}

// ─── Polygon SDF in local coords ────────────────────────────────────────────

float polygonSDF(vec2 lp, float m, float a){
  float tW = m * a;
  float d = 1e10;

  // Bottom: m geodesic arcs from (ka, 1) to ((k+1)a, 1)
  for(int k = 0; k < MAX_CHILDREN; k++){
    if(float(k) >= m) break;
    d = min(d, geodesicSDF(lp,
        vec2(float(k) * a, 1.0),
        vec2(float(k + 1) * a, 1.0)));
  }

  // Top: geodesic from (0, m) to (tW, m)
  d = min(d, geodesicSDF(lp, vec2(0.0, m), vec2(tW, m)));

  // Left vertical: (0, 1) → (0, m)
  d = min(d, sdfSegment(lp, vec2(0.0, 1.0), vec2(0.0, m)));

  // Right vertical: (tW, 1) → (tW, m)
  d = min(d, sdfSegment(lp, vec2(tW, 1.0), vec2(tW, m)));

  return d;
}

void main(){
  float m  = max(uChildren, 2.0);
  float a  = max(uParam, 0.01);
  float hw = max(uThickness, 0.001);
  float tW = m * a;
  float logB = log2(m);

  float zoom = max(uZoom, 0.1);

  vec2 fc = (vPos*0.5+0.5)*uResolution;
  vec2 p  = toWorld(fc, zoom);

  vec3 col = vec3(0.06);

  // x-axis
  float ax = 1.0 - smoothstep(0.0, 2.0*fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), ax);

  if(p.y > 0.0){
    float x = p.x, y = p.y;
    float eps = max(1e-6, fwidth(y));
    float yC  = max(y, eps);

    // Level detection
    int   n = int(floor(log2(yC)/logB));
    float K = pow(m, float(-n));

    // Renormalize to local polygon coords
    float xren = K*x;
    float yren = K*y;
    float cell = floor(xren/tW);
    float xmod = xren - cell*tW;

    // Cap detection (bump disc test)
    float rb2 = a*a*0.25 + 1.0;
    bool under = false;
    for(int k = 0; k < MAX_CHILDREN; k++){
      if(float(k) >= m) break;
      float ck = (float(k)+0.5)*a;
      float dx = xmod - ck;
      if(dx*dx + yren*yren < rb2) under = true;
    }

    if(under){
      n -= 1;
      K = pow(m, float(-n));
      xren = K*x;
      yren = K*y;
      cell = floor(xren/tW);
      xmod = xren - cell*tW;
    }

    // 4-coloring
    int h  = -n;
    int l  = int(cell);
    int pN = int(mod(float(h)+4096.0, 2.0));
    int pL = int(mod(float(l)+4096.0, 2.0));
    int id = pN*2 + pL;
    vec3 tc = color4(id);

    float fade = smoothstep(0.0, 3.0*eps, y);
    col = mix(col, tc, fade);

    // Polygon SDF in post-cap local coords
    float d  = polygonSDF(vec2(xmod, yren), m, a);
    float pw = fwidth(d);

    // Edge line with hyperbolic width (Euclidean half-width = hw * y_local)
    float hypThick = hw * yren;
    float edgeLine = smoothstep(hypThick + pw, max(hypThick - pw, 0.0), d);
    col = mix(col, vec3(0.15), edgeLine * fade);
  }

  gl_FragColor = vec4(col, 1.0);
}
