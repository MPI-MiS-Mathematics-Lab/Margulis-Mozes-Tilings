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
const float TERNARY_BASE = 3.0;
const float CANONICAL_Y_SPAN = 2.0; // canonical tile uses UHP y in [1, 3)

vec2 tileToUhp(float scale, float j, vec2 uv) {
  return vec2(scale * (j + uv.x), scale * (1.0 + CANONICAL_Y_SPAN * uv.y));
}

vec2 tileUvToCanonicalUhp(vec2 uv) {
  return vec2(uv.x, 1.0 + CANONICAL_Y_SPAN * uv.y);
}

vec2 canonicalUhpToTileUv(vec2 zeta) {
  return vec2(zeta.x, (zeta.y - 1.0) / CANONICAL_Y_SPAN);
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

// Hyperbolic interpolation for connector curves.
// Coordinates are evaluated in canonical-tile UHP coordinates (x, y) = (u, 1+2v).
vec2 uhpToDisk(vec2 zeta) {
  vec2 w = vec2(zeta.y, -zeta.x);
  vec2 num = w - vec2(1.0, 0.0);
  vec2 den = w + vec2(1.0, 0.0);
  return cdiv(num, den);
}

vec2 diskToUhp(vec2 z) {
  vec2 num = vec2(1.0, 0.0) + z;
  vec2 den = vec2(1.0, 0.0) - z;
  vec2 w = cdiv(num, den);
  return vec2(-w.y, w.x);
}

vec2 mobiusAdd(vec2 x, vec2 y) {
  float x2 = dot(x, x);
  float y2 = dot(y, y);
  float xy = dot(x, y);
  float den = 1.0 + 2.0 * xy + x2 * y2;
  vec2 num = (1.0 + 2.0 * xy + y2) * x + (1.0 - x2) * y;
  return num / den;
}

vec2 mobiusScalar(float t, vec2 x) {
  float r = length(x);
  if (r < 1e-9) return x;
  float a = atanh(clamp(r, 0.0, 0.999999));
  float s = tanh(t * a) / r;
  return s * x;
}

float hypDistDisk(vec2 a, vec2 b) {
  vec2 d = mobiusAdd(-a, b);
  float r = clamp(length(d), 0.0, 0.999999);
  return 2.0 * atanh(r);
}

float hypDistUhp(vec2 a, vec2 b) {
  return hypDistDisk(uhpToDisk(a), uhpToDisk(b));
}

vec2 diskStep(vec2 p, vec2 dirUnit, float s) {
  float step = tanh(0.5 * s);
  return mobiusAdd(p, dirUnit * step);
}

vec2 uhpGeodesicLerp(vec2 pUhp, vec2 qUhp, float t) {
  vec2 a = uhpToDisk(pUhp);
  vec2 b = uhpToDisk(qUhp);
  vec2 d = mobiusAdd(-a, b);
  vec2 c = mobiusAdd(a, mobiusScalar(t, d));
  return diskToUhp(c);
}

vec2 hypBezierPointUhp(vec2 p0, vec2 p1, vec2 p2, vec2 p3, float t) {
  vec2 q0 = uhpGeodesicLerp(p0, p1, t);
  vec2 q1 = uhpGeodesicLerp(p1, p2, t);
  vec2 q2 = uhpGeodesicLerp(p2, p3, t);
  vec2 r0 = uhpGeodesicLerp(q0, q1, t);
  vec2 r1 = uhpGeodesicLerp(q1, q2, t);
  return uhpGeodesicLerp(r0, r1, t);
}

float hypBezierDistTile(vec2 pUv, vec2 p0Uv, vec2 p1Uv, vec2 p2Uv, vec2 p3Uv) {
  const int STEPS = 36;
  vec2 pUhp = tileUvToCanonicalUhp(pUv);
  vec2 p0 = tileUvToCanonicalUhp(p0Uv);
  vec2 p1 = tileUvToCanonicalUhp(p1Uv);
  vec2 p2 = tileUvToCanonicalUhp(p2Uv);
  vec2 p3 = tileUvToCanonicalUhp(p3Uv);

  float d = 1e9;
  for (int i = 0; i <= STEPS; i++) {
    float t = float(i) / float(STEPS);
    vec2 curUhp = hypBezierPointUhp(p0, p1, p2, p3, t);
    d = min(d, hypDistUhp(pUhp, curUhp));
  }
  return d;
}

void buildConnectorControls(
  vec2 a, vec2 na, vec2 b, vec2 nb,
  out vec2 p0, out vec2 p1, out vec2 p2, out vec2 p3
) {
  vec2 aUhp = tileUvToCanonicalUhp(a);
  vec2 bUhp = tileUvToCanonicalUhp(b);
  vec2 aD = uhpToDisk(aUhp);
  vec2 bD = uhpToDisk(bUhp);

  float dHyp = hypDistDisk(aD, bD);
  float s = 0.45 * dHyp;

  float eps = 1e-3;
  vec2 aD2 = uhpToDisk(tileUvToCanonicalUhp(a + eps * na));
  vec2 bD2 = uhpToDisk(tileUvToCanonicalUhp(b + eps * nb));
  vec2 dirA = normalize(aD2 - aD);
  vec2 dirB = normalize(bD2 - bD);

  vec2 p1Uhp = diskToUhp(diskStep(aD, dirA, s));
  vec2 p2Uhp = diskToUhp(diskStep(bD, dirB, s));
  p0 = a;
  p1 = canonicalUhpToTileUv(p1Uhp);
  p2 = canonicalUhpToTileUv(p2Uhp);
  p3 = b;
}

float bezierConnectorDist(vec2 p, vec2 a, vec2 na, vec2 b, vec2 nb) {
  vec2 p0;
  vec2 p1;
  vec2 p2;
  vec2 p3;
  buildConnectorControls(a, na, b, nb, p0, p1, p2, p3);
  return hypBezierDistTile(p, a, p1, p2, b);
}

bool rayCrossesSegmentToRight(vec2 p, vec2 a, vec2 b) {
  if ((a.y > p.y) == (b.y > p.y)) return false;
  float xHit = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y);
  return xHit > p.x;
}

int connectorRayCrossingsFromControls(vec2 pUv, vec2 p0Uv, vec2 p1Uv, vec2 p2Uv, vec2 p3Uv) {
  const int STEPS = 28;
  vec2 p0 = tileUvToCanonicalUhp(p0Uv);
  vec2 p1 = tileUvToCanonicalUhp(p1Uv);
  vec2 p2 = tileUvToCanonicalUhp(p2Uv);
  vec2 p3 = tileUvToCanonicalUhp(p3Uv);

  int hits = 0;
  vec2 prev = canonicalUhpToTileUv(hypBezierPointUhp(p0, p1, p2, p3, 0.0));
  for (int i = 1; i <= STEPS; i++) {
    float t = float(i) / float(STEPS);
    vec2 cur = canonicalUhpToTileUv(hypBezierPointUhp(p0, p1, p2, p3, t));
    if (rayCrossesSegmentToRight(pUv, prev, cur)) {
      hits += 1;
    }
    prev = cur;
  }
  return hits;
}

int connectorRayCrossings(vec2 p, vec2 a, vec2 na, vec2 b, vec2 nb) {
  vec2 p0;
  vec2 p1;
  vec2 p2;
  vec2 p3;
  buildConnectorControls(a, na, b, nb, p0, p1, p2, p3);
  return connectorRayCrossingsFromControls(p, p0, p1, p2, p3);
}

float modPos(float x, float m) {
  return mod(mod(x, m) + m, m);
}

int ternaryTileId(float h, float l) {
  float u = fract(0.754877666 * h + 0.569840296 * l + hash12(vec2(h + 37.0, l - 91.0)));
  return int(floor(3.0 * u));
}

float parityBit(float x) {
  return mod(floor(x), 2.0);
}

float motifClassBit(int tileId) {
  // Motifs {0,1} behave as one class, motif {2} as the other.
  return tileId == 2 ? 1.0 : 0.0;
}

float ternaryFlipPotential(float h, float l) {
  int tileId = ternaryTileId(h, l);
  return mod(motifClassBit(tileId) + parityBit(h) + parityBit(l), 2.0);
}

float ternaryTileFlip(float h, float l) {
  // Anchor at (0,0), then transport by XOR potential difference.
  const float BASE_FLIP = 1.0;
  float g00 = ternaryFlipPotential(0.0, 0.0);
  float ghk = ternaryFlipPotential(h, l);
  return mod(BASE_FLIP + g00 + ghk, 2.0);
}

void evalHyperbolicConnector(
  vec2 p, vec2 a, vec2 na, vec2 b, vec2 nb,
  inout float bestD
) {
  float d = bezierConnectorDist(p, a, na, b, nb);
  bestD = min(bestD, d);
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

float truchetTernaryDistance(vec2 uv, int t) {
  const vec2 P  = vec2(0.50, 1.00);
  const vec2 SL = vec2(0.00, 0.50);
  const vec2 SR = vec2(1.00, 0.50);
  const vec2 CL = vec2(1.0/6.0, 0.00);
  const vec2 CC = vec2(3.0/6.0, 0.00);
  const vec2 CR = vec2(5.0/6.0, 0.00);
  const vec2 NP  = vec2(0.0, -1.0);
  const vec2 NSL = vec2(1.0, 0.0);
  const vec2 NSR = vec2(-1.0, 0.0);
  const vec2 NCL = vec2(0.0, 1.0);
  const vec2 NCC = vec2(0.0, 1.0);
  const vec2 NCR = vec2(0.0, 1.0);

  float d = 1e9;
  // Three non-crossing ternary motifs.
  // t=0: (SL-CL), (P-CC), (SR-CR)
  // t=1: (P-SL), (CL-CC), (CR-SR)
  // t=2: (P-SR), (CC-CR), (SL-CL)
  if (t == 0) {
    evalHyperbolicConnector(uv, SL, NSL, CL, NCL, d);
    evalHyperbolicConnector(uv, P, NP, CC, NCC, d);
    evalHyperbolicConnector(uv, SR, NSR, CR, NCR, d);
  } else if (t == 1) {
    evalHyperbolicConnector(uv, P, NP, SL, NSL, d);
    evalHyperbolicConnector(uv, CL, NCL, CC, NCC, d);
    evalHyperbolicConnector(uv, CR, NCR, SR, NSR, d);
  } else {
    evalHyperbolicConnector(uv, P, NP, SR, NSR, d);
    evalHyperbolicConnector(uv, CC, NCC, CR, NCR, d);
    evalHyperbolicConnector(uv, SL, NSL, CL, NCL, d);
  }
  return d;
}

float truchetTernaryRegionParity(vec2 uv, int t) {
  const vec2 P  = vec2(0.50, 1.00);
  const vec2 SL = vec2(0.00, 0.50);
  const vec2 SR = vec2(1.00, 0.50);
  const vec2 CL = vec2(1.0/6.0, 0.00);
  const vec2 CC = vec2(3.0/6.0, 0.00);
  const vec2 CR = vec2(5.0/6.0, 0.00);
  const vec2 UL = vec2(0.00, 1.00);
  const vec2 UR = vec2(1.00, 1.00);
  const vec2 LL = vec2(0.00, 0.00);
  const vec2 LR = vec2(1.00, 0.00);
  const vec2 NP  = vec2(0.0, -1.0);
  const vec2 NSL = vec2(1.0, 0.0);
  const vec2 NSR = vec2(-1.0, 0.0);
  const vec2 NCL = vec2(0.0, 1.0);
  const vec2 NCC = vec2(0.0, 1.0);
  const vec2 NCR = vec2(0.0, 1.0);

  // Avoid parity ambiguity exactly on tile boundaries (u/v = 0 or 1).
  vec2 p = clamp(uv, vec2(1e-4), vec2(1.0 - 1e-4));

  int hits = 0;
  if (t == 0) {
    // Loop: UL -> SL -> CL -> CC -> P -> UR -> SR -> CR -> LR -> LL -> UL
    hits += int(rayCrossesSegmentToRight(p, UL, SL));
    hits += connectorRayCrossings(p, SL, NSL, CL, NCL);
    hits += int(rayCrossesSegmentToRight(p, CL, CC));
    hits += connectorRayCrossings(p, CC, NCC, P, NP);
    hits += int(rayCrossesSegmentToRight(p, P, UR));
    hits += int(rayCrossesSegmentToRight(p, UR, SR));
    hits += connectorRayCrossings(p, SR, NSR, CR, NCR);
    hits += int(rayCrossesSegmentToRight(p, CR, LR));
    hits += int(rayCrossesSegmentToRight(p, LR, LL));
    hits += int(rayCrossesSegmentToRight(p, LL, UL));
  } else if (t == 1) {
    // Loop: UR -> P -> SL -> LL -> CL -> CC -> CR -> SR -> UR
    hits += int(rayCrossesSegmentToRight(p, UR, P));
    hits += connectorRayCrossings(p, P, NP, SL, NSL);
    hits += int(rayCrossesSegmentToRight(p, SL, LL));
    hits += int(rayCrossesSegmentToRight(p, LL, CL));
    hits += connectorRayCrossings(p, CL, NCL, CC, NCC);
    hits += int(rayCrossesSegmentToRight(p, CC, CR));
    hits += connectorRayCrossings(p, CR, NCR, SR, NSR);
    hits += int(rayCrossesSegmentToRight(p, SR, UR));
  } else {
    // Loop: UL -> P -> SR -> LR -> CR -> CC -> CL -> SL -> UL
    hits += int(rayCrossesSegmentToRight(p, UL, P));
    hits += connectorRayCrossings(p, P, NP, SR, NSR);
    hits += int(rayCrossesSegmentToRight(p, SR, LR));
    hits += int(rayCrossesSegmentToRight(p, LR, CR));
    hits += connectorRayCrossings(p, CR, NCR, CC, NCC);
    hits += int(rayCrossesSegmentToRight(p, CC, CL));
    hits += connectorRayCrossings(p, CL, NCL, SL, NSL);
    hits += int(rayCrossesSegmentToRight(p, SL, UL));
  }
  return mod(float(hits), 2.0);
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

vec3 shadeTernaryBand(float x, float y, float nBand, float smh) {
  float scale = pow(TERNARY_BASE, nBand);
  float j = floor(x / scale);
  vec2 uv = vec2(fract(x / scale), (y - scale) / (CANONICAL_Y_SPAN * scale));
  uv = clamp(uv, 0.0, 1.0);

  int tileId = ternaryTileId(nBand, j);
  float parity = truchetTernaryRegionParity(uv, tileId);
  float flip = ternaryTileFlip(nBand, j);
  float bwBit = mod(parity + flip, 2.0);
  return mix(vec3(1.0), vec3(0.0), bwBit);
}

vec3 renderTernaryTruchet(vec2 s) {
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
  float n0 = floor(log(max(y, eps)) / log(TERNARY_BASE));
  col = shadeTernaryBand(x, y, n0, smh);

  float fade = smoothstep(0.0, 3.0*eps, y);
  col = mix(vec3(1.0), col, fade);

  float dr = 1.0 - sqrt(r2);
  float px = fwidth(s.x) + fwidth(s.y);
  float diskEdge = smoothstep(0.0, 2.0*px, dr);
  col = mix(vec3(1.0), col, diskEdge);
  return col;
}

float sampleInk(vec2 s) {
  return 1.0 - renderTernaryTruchet(s).r;
}

float sampleInkHyper(vec2 s, vec2 a) {
  return 1.0 - renderTernaryTruchet(diskTranslate(s, a)).r;
}

void main() {
  vec2 R = uResolution.xy;
  vec2 s0 = (2.0*gl_FragCoord.xy - R) / R.y;
  vec2 m = (2.0 * uMouse - uResolution) / uResolution.y;
  vec2 s = diskTranslate(s0, -m);

  float sepH = 0.028;
  float sepLocal = 0.5 * sepH * max(0.0, 1.0 - dot(s, s));
  vec2 offs = vec2(sepLocal, 0.0);
  vec2 leftS = s + offs;
  vec2 rightS = s - offs;

  float diskMask = 1.0 - smoothstep(0.998, 1.004, length(s));
  float centerInk = 1.0 - renderTernaryTruchet(s).r;
  float leftInk = 1.0 - renderTernaryTruchet(leftS).r;
  float rightInk = 1.0 - renderTernaryTruchet(rightS).r;

  vec3 paper = vec3(0.98, 0.95, 0.90);
  vec3 col = paper;
  col = mix(col, vec3(0.06, 0.66, 0.84), 0.78 * leftInk);
  col = mix(col, vec3(0.94, 0.10, 0.53), 0.64 * rightInk);
  col = mix(col, vec3(0.10), 0.48 * centerInk);
  col += (hash12(s * 1300.0) - 0.5) * 0.03;
  col = mix(vec3(1.0), col, diskMask);
  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col, 1.0);
}
