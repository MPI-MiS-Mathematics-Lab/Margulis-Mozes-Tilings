#ifdef GL_ES
precision highp float;
#endif

// Derivatives for fwidth (WebGL1) — in WebGL2 they're core
#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
uniform vec2 uMouse;
const float STROKE_RHO = 0.062;

vec2 tileToUhp(float scale, float j, vec2 uv) {
  return vec2(scale * (j + uv.x), scale * (1.0 + uv.y));
}

vec2 cdiv(vec2 a, vec2 b) {
  float den = dot(b, b);
  return vec2((a.x*b.x + a.y*b.y)/den, (a.y*b.x - a.x*b.y)/den);
}

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 diskTranslate(vec2 z, vec2 a) {
  float aa = dot(a, a);
  if (aa < 1e-8) return z;
  if (aa > 0.92*0.92) a *= 0.92 / sqrt(aa);
  vec2 num = z + a;
  vec2 den = vec2(1.0 + a.x*z.x + a.y*z.y, a.x*z.y - a.y*z.x);
  return cdiv(num, den);
}

vec2 cubicBezierPoint(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
  float u = 1.0 - t;
  float uu = u * u;
  float tt = t * t;
  return uu * u * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + tt * t * p3;
}

vec2 cubicBezierTangent(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
  float u = 1.0 - t;
  return 3.0 * u * u * (p1 - p0)
       + 6.0 * u * t * (p2 - p1)
       + 3.0 * t * t * (p3 - p2);
}

float bezierDist2At(vec2 p, vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
  vec2 q = cubicBezierPoint(p0, p1, p2, p3, t);
  vec2 v = p - q;
  return dot(v, v);
}

vec2 cubicBezierClosest(vec2 p, vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
  const int STEPS = 64;
  float bestD2 = 1e9;
  float bestT = 0.0;
  for (int i = 0; i <= STEPS; i++) {
    float t = float(i) / float(STEPS);
    float d2 = bezierDist2At(p, p0, p1, p2, p3, t);
    if (d2 < bestD2) {
      bestD2 = d2;
      bestT = t;
    }
  }

  float dt = 1.0 / float(STEPS);
  float lo = max(0.0, bestT - dt);
  float hi = min(1.0, bestT + dt);
  for (int k = 0; k < 7; k++) {
    float m1 = mix(lo, hi, 0.3333333);
    float m2 = mix(lo, hi, 0.6666667);
    float d1 = bezierDist2At(p, p0, p1, p2, p3, m1);
    float d2 = bezierDist2At(p, p0, p1, p2, p3, m2);
    if (d1 < d2) {
      hi = m2;
    } else {
      lo = m1;
    }
  }

  float tRefined = 0.5 * (lo + hi);
  float dRefined = sqrt(bezierDist2At(p, p0, p1, p2, p3, tRefined));
  return vec2(dRefined, tRefined);
}

void evalConnector(
  vec2 p, vec2 a, vec2 na, vec2 b, vec2 nb, float connId,
  inout float bestD, inout float bestT, inout float bestConn, inout vec2 bestTan
) {
  float k = 0.45 * length(b - a);
  vec2 p0 = a;
  vec2 p1 = a + k * na;
  vec2 p2 = b + k * nb;
  vec2 p3 = b;
  vec2 hit = cubicBezierClosest(p, p0, p1, p2, p3);
  if (hit.x < bestD) {
    bestD = hit.x;
    bestT = hit.y;
    bestConn = connId;
    vec2 tan = cubicBezierTangent(p0, p1, p2, p3, hit.y);
    bestTan = tan / max(length(tan), 1e-6);
  }
}

float semiDiskSdf(vec2 p, vec2 c, vec2 nIn, float r) {
  float dCircle = length(p - c) - r;
  float dHalf = -dot(p - c, nIn);
  return max(dCircle, dHalf);
}

float sminPoly(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / max(k, 1e-6), 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

void truchetClosestInfo(vec2 uv, int t, out float d, out float tCurve, out float connId, out vec2 tan) {
  const vec2 P  = vec2(0.50, 1.00);
  const vec2 SL = vec2(0.00, 0.50);
  const vec2 SR = vec2(1.00, 0.50);
  const vec2 CL = vec2(0.25, 0.00);
  const vec2 CR = vec2(0.75, 0.00);
  const vec2 NP  = vec2(0.0, -1.0);
  const vec2 NSL = vec2(1.0, 0.0);
  const vec2 NSR = vec2(-1.0, 0.0);
  const vec2 NCL = vec2(0.0, 1.0);
  const vec2 NCR = vec2(0.0, 1.0);

  d = 1e9;
  tCurve = 0.0;
  connId = 0.0;
  tan = vec2(1.0, 0.0);
  // 3 motifs with cubic Bezier connectors that hit boundaries at 90 degrees.
  // t=0 -> {slcl, psr, cr}
  // t=1 -> {psl, srcr, cl}
  // t=2 -> {slcl, srcr, p}
  if (t == 0) {
    evalConnector(uv, SL, NSL, CL, NCL, 0.0, d, tCurve, connId, tan);
    evalConnector(uv, P, NP, SR, NSR, 1.0, d, tCurve, connId, tan);
  } else if (t == 1) {
    evalConnector(uv, P, NP, SL, NSL, 2.0, d, tCurve, connId, tan);
    evalConnector(uv, SR, NSR, CR, NCR, 3.0, d, tCurve, connId, tan);
  } else {
    evalConnector(uv, SL, NSL, CL, NCL, 4.0, d, tCurve, connId, tan);
    evalConnector(uv, SR, NSR, CR, NCR, 5.0, d, tCurve, connId, tan);
  }
}

vec2 zetaToModel(vec2 zeta) {
  return vec2(0.16 * zeta.x, 0.90 * log(1.0 + zeta.y));
}

float checkerPattern(vec2 uv, float scale) {
  vec2 c = floor(uv * scale);
  return mod(c.x + c.y, 2.0);
}

vec3 backgroundFromZeta(vec2 zeta) {
  vec2 m = zetaToModel(zeta);
  float ch = checkerPattern(m, 3.1);
  vec3 cA = vec3(0.93, 0.95, 0.98);
  vec3 cB = vec3(0.08, 0.10, 0.14);
  vec3 col = mix(cA, cB, ch);
  float stripes = 0.5 + 0.5 * sin(4.0 * m.x + 6.0 * m.y);
  col = mix(col, col * vec3(0.90, 0.96, 1.08), 0.18 * stripes);
  return col;
}

bool diskToZeta(vec2 s, out vec2 zeta) {
  if (dot(s, s) >= 0.9995) return false;
  vec2 num = vec2(1.0, 0.0) + s;
  vec2 den = vec2(1.0, 0.0) - s;
  float d = dot(den, den);
  if (d < 1e-8) return false;
  vec2 w = vec2((num.x*den.x + num.y*den.y)/d, (num.y*den.x - num.x*den.y)/d);
  zeta = vec2(-w.y, w.x);
  return zeta.y > 1e-6;
}

vec3 backgroundAtDisk(vec2 s) {
  vec2 zeta;
  if (!diskToZeta(s, zeta)) return vec3(1.0);
  return backgroundFromZeta(zeta);
}

vec3 blurBackgroundAtDisk(vec2 s, vec2 axis, float radius) {
  vec2 a = axis;
  float al = length(a);
  if (al < 1e-6) a = vec2(1.0, 0.0);
  else a /= al;

  vec3 c0 = backgroundAtDisk(s);
  vec3 c1 = backgroundAtDisk(s + a * radius);
  vec3 c2 = backgroundAtDisk(s - a * radius);
  vec3 c3 = backgroundAtDisk(s + a * 2.0 * radius);
  vec3 c4 = backgroundAtDisk(s - a * 2.0 * radius);
  return c0 * 0.38 + (c1 + c2) * 0.22 + (c3 + c4) * 0.09;
}

float fresnelSchlick(float cosTheta, float ior) {
  float r0 = (1.0 - ior) / (1.0 + ior);
  r0 *= r0;
  return r0 + (1.0 - r0) * pow(1.0 - clamp(cosTheta, 0.0, 1.0), 5.0);
}

vec3 shadeBinaryBand(vec2 s, vec2 zeta, float x, float y, float nBand, float smh) {
  float scale = exp2(nBand);
  float j = floor(x / scale);
  vec2 uv = vec2(fract(x / scale), (y - scale) / scale);
  uv = clamp(uv, 0.0, 1.0);

  int tileId = int(mod(nBand + 2.0*j, 3.0));
  vec3 bg = backgroundFromZeta(zeta);

  float dCenter;
  float tCurve;
  float connId;
  vec2 curveTan;
  truchetClosestInfo(uv, tileId, dCenter, tCurve, connId, curveTan);

  float widthUhp = y * sinh(STROKE_RHO);
  float widthTile = widthUhp / max(scale, 1e-6);
  widthTile *= 1.55;
  float edge = dCenter - widthTile;

  const vec2 P  = vec2(0.50, 1.00);
  const vec2 CL = vec2(0.25, 0.00);
  const vec2 CR = vec2(0.75, 0.00);
  vec2 capCenter = CR;
  if (tileId == 0) {
    capCenter = CR;
  } else if (tileId == 1) {
    capCenter = CL;
  } else {
    capCenter = P;
  }
  // Circular cap (softer differential behavior than semi-disk max()).
  float dCap = length(uv - capCenter) - widthTile;
  float joinK = 0.75 * widthTile;
  edge = sminPoly(edge, dCap, joinK);

  float aa = max(1e-5, smh);
  float mask = 1.0 - smoothstep(-aa, aa, edge);
  return mix(vec3(1.0), vec3(0.0), mask);
}

vec3 renderBinaryTruchet(vec2 s) {
  vec3 col = vec3(1.0);
  float r2 = dot(s, s);
  if (r2 >= 1.0) return col;
  float smh = 20.0 / uResolution.x;

  vec2 z = s;
  vec2 num = vec2(1.0, 0.0) + z;
  vec2 den = vec2(1.0, 0.0) - z;
  float d = dot(den, den);
  vec2 w = vec2((num.x*den.x + num.y*den.y)/d, (num.y*den.x - num.x*den.y)/d);
  vec2 zeta = vec2(-w.y, w.x);

  float x = zeta.x;
  float y = zeta.y;
  float eps = max(1e-12, fwidth(y));
  float l2 = log2(max(y, eps));
  float n0 = floor(l2);
  col = shadeBinaryBand(s, zeta, x, y, n0, smh);

  float fade = smoothstep(0.0, 3.0*eps, y);
  col = mix(vec3(1.0), col, fade);

  float dr = 1.0 - sqrt(r2);
  float px = fwidth(s.x) + fwidth(s.y);
  float diskEdge = smoothstep(0.0, 2.0*px, dr);
  col = mix(vec3(1.0), col, diskEdge);
  return col;
}

void main() {
  vec2 R = uResolution.xy;
  vec2 s0 = (2.0*gl_FragCoord.xy - R) / R.y;
  vec2 m = (2.0 * uMouse - uResolution) / uResolution.y;
  vec2 s = diskTranslate(s0, -m);

  // Hyperbolic-aware local stereo: Euclidean offset shrinks near |s|->1.
  float sepH = 0.028;
  float sepLocal = 0.5 * sepH * max(0.0, 1.0 - dot(s, s));
  vec2 offs = vec2(sepLocal, 0.0);
  vec2 leftS = s + offs;
  vec2 rightS = s - offs;

  float centerInk = 1.0 - renderBinaryTruchet(s).r;
  float leftInk = 1.0 - renderBinaryTruchet(leftS).r;
  float rightInk = 1.0 - renderBinaryTruchet(rightS).r;

  vec3 col = vec3(1.0);
  col -= vec3(1.00, 0.06, 0.06) * leftInk;
  col -= vec3(0.08, 0.64, 1.00) * rightInk;
  col -= vec3(0.12) * centerInk;
  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col, 1.0);
}
