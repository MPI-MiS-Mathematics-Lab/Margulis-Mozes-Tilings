#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
varying vec2 vPos;

// Branching factor: each tile has N children.
// Must be ODD (3, 5, 7, ...) for a valid 3-coloring.
#define N 5

// Hyperbolic edge thickness
#define H_WIDTH 0.04

vec3 color3(int id) {
  if(id == 0) return vec3(0.93, 0.40, 0.40);
  if(id == 1) return vec3(0.42, 0.72, 0.98);
  return vec3(0.52, 0.92, 0.56);
}

vec2 toWorld(vec2 fragCoord) {
  const vec2 minBounds = vec2(-6.0, 0.0);
  const vec2 maxBounds = vec2(6.0, 8.0);
  vec2 size = maxBounds - minBounds;
  float scale = uResolution.y / size.y;
  float centerX = 0.5 * (minBounds.x + maxBounds.x);
  float worldX = (fragCoord.x - 0.5 * uResolution.x) / scale + centerX;
  float worldY = (fragCoord.y / scale) + minBounds.y;
  return vec2(worldX, worldY);
}

float asinh1(float x) {
  return log(x + sqrt(x * x + 1.0));
}

vec2 cdiv(vec2 a, vec2 b) {
  float d = dot(b, b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}

// Exact hyperbolic distance from z to the geodesic with ideal endpoints a and b.
float signedDistanceToGeodesic(float a, float b, vec2 z) {
  float c = 0.5*(a + b);
  float r = 0.5*abs(b - a);
  float dx = z.x - c;
  return asinh1((dx*dx + z.y*z.y - r*r) / (2.0 * r * max(z.y, 1e-6)));
}

// Exact hyperbolic distance from z to the vertical geodesic x = x0.
float distanceToVertical(float x0, vec2 z) {
  float dx = abs(z.x - x0);
  return asinh1(dx / max(z.y, 1e-6));
}

// Generalized AlphaEvolve coloring for odd branching factor N:
// color = (h + count_of_odd_digits_in_baseN(l) - final_l) % 3
int getColor(int h, int l) {
  int h_increment = 0;
  int current_l = l;

  for (int i = 0; i < 40; i++) {
    if (current_l == 0 || current_l == -1) break;

    int quotient = int(floor(float(current_l) / float(N)));
    int remainder = current_l - quotient * N;

    if ((remainder & 1) == 1) h_increment++;
    current_l = quotient;
  }

  int final_l = current_l;

  int result = h + h_increment - final_l;
  result = int(mod(float(result), 3.0));
  return result;
}

void main() {
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord);

  vec3 col = vec3(0.06);

  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

  float eps = max(1e-6, fwidth(p.y));
  float yClamped = max(p.y, eps);

  float logNy = log(yClamped) / log(float(N));
  int n = int(floor(logNy));
  int h = -n;

  // ── Renormalized coordinates (pre-cap) ──
  float K = pow(float(N), float(-n));
  float yren = K * p.y;
  float xren = (p.x + 0.5) * K;
  float xmod = fract(xren);

  // Save pre-cap state for edges
  float yrenOrig = yren;
  float xmodOrig = xmod;

  // ── N-ary cap geometry (Margulis-Mozes polygon bumps) ──
  // Each tile's bottom edge consists of N geodesic segments connecting
  // vertices at (k/N, 1) for k=0..N, forming the polygon "bumps".
  float rb2 = 1.0 + 1.0 / (4.0 * float(N) * float(N));
  float r0 = sqrt(rb2);

  bool underCap = false;
  float dCapHyp = 1e10;

  for (int k = 0; k < N; k++) {
    float ck = (2.0 * float(k) + 1.0) / (2.0 * float(N));
    float dx = xmod - ck;
    float d2 = dx*dx + yren*yren;
    if (d2 < rb2) underCap = true;

    // Exact geodesic distance to cap semicircle
    float a = ck - r0;
    float b = ck + r0;
    float d = abs(signedDistanceToGeodesic(a, b, vec2(xmod, yren)));
    dCapHyp = min(dCapHyp, d);
  }

  if (underCap) {
    n -= 1;
    h = -n;
    K = pow(float(N), float(-n));
    xren = (p.x + 0.5) * K;
    yren = K * p.y;
    xmod = fract(xren);
  }

  // ── Tile coloring ──
  float cells = pow(float(N), float(-n));
  int l = int(floor((p.x + 0.5) * cells));

  int colorId = getColor(h, l);
  vec3 tileColor = color3(colorId);

  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tileColor, fade);

  // ── Exact hyperbolic-thickness edge lines ──

  // Top edge: geodesic from (0, N) to (1, N) in pre-cap cell coords
  float topR   = sqrt(0.25 + float(N)*float(N));
  float dTop   = abs(signedDistanceToGeodesic(0.5 - topR, 0.5 + topR, vec2(xmodOrig, yrenOrig)));
  float pwTop  = fwidth(dTop);
  float lineTop = 1.0 - smoothstep(H_WIDTH - pwTop, H_WIDTH + pwTop, dTop);

  // Vertical edges: geodesics at cell boundaries (post-cap)
  float dV = min(distanceToVertical(0.0, vec2(xmod, yren)),
                 distanceToVertical(1.0, vec2(xmod, yren)));
  float pwV = fwidth(dV);
  float lineV = 1.0 - smoothstep(H_WIDTH - pwV, H_WIDTH + pwV, dV);

  // Cap boundaries: exact geodesic distance
  float pwC = fwidth(dCapHyp);
  float lineC = 1.0 - smoothstep(H_WIDTH - pwC, H_WIDTH + pwC, dCapHyp);

  float line = max(max(lineTop, lineV), lineC);
  col = mix(col, vec3(0.15), line * fade);

  gl_FragColor = vec4(col, 1.0);
}
