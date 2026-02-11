#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2  uResolution;
uniform int   uN;   // n >= 5
uniform float uA;   // a > 0

varying vec2 vPos;

// --------- SDF helpers ----------
float sdVertical(vec2 p, float x0, float s){ return s*(p.x - x0); }
float sdCircle(vec2 p, float c, float R, float s){
  float d = length(vec2(p.x - c, p.y)) - R;
  return s * d;
}

// Base polygon P_a in the UHP (<=0 inside)
float sd_Pa_UHP(vec2 p, int N, float a){
  int m = N - 3;
  float d = -1e9;

  // left/right verticals: x in [0, m*a]
  d = max(d, sdVertical(p, 0.0, -1.0));            // x >= 0
  float W = float(m) * a;
  d = max(d, sdVertical(p, W,  +1.0));             // x <= W

  // bottom arcs between ((j-1)a + i) and (j a + i), equal heights y=1
  float Rb = sqrt(1.0 + 0.25*a*a);
  const int MAXN = 64;
  for(int j=1; j<MAXN; ++j){
    if(j > N-3) break;
    float c = (float(j) - 0.5) * a;
    // interior ABOVE arc => outside disk => s = -1
    d = max(d, sdCircle(p, c, Rb, -1.0));
  }

  // top arc between (0, m) and (m a, m)
  float yTop = float(m);
  float cTop = 0.5 * float(m) * a;
  float RTop = sqrt(cTop*cTop + yTop*yTop);
  // interior BELOW arc => inside disk => s = +1
  d = max(d, sdCircle(p, cTop, RTop, +1.0));

  return d; // signed: <=0 inside
}

// ---------- view framing in UHP ----------
vec2 toWorld(vec2 fragCoord, int N, float a){
  float W = float(N-3) * a;
  // frame a wide strip: a bit left/right of one FD and tall enough to show many levels
  float xmin = -0.5 * W, xmax = 1.5 * W;
  float ymin = -0.2,   ymax = max(6.0, float(N-3) * 6.0);
  vec2 cen  = 0.5 * vec2(xmin + xmax, ymin + ymax);
  vec2 size = vec2(xmax - xmin, ymax - ymin);
  float s   = min(uResolution.x/size.x, uResolution.y/size.y);
  return (fragCoord - 0.5*uResolution)/s + cen;
}

// ---------- membership at a specific level k ----------
bool insideAtLevel(vec2 p, int N, float a, int k, out vec2 q_base, out float sDown, out float dWorld){
  float lam = float(N - 3);
  float W   = float(N - 3) * a;

  // scale to base, then wrap x by base period
  sDown = pow(lam, -float(k));     // = lam^{-k}
  vec2 q = p * sDown;              // base coords
  q.x -= W * floor(q.x / W);

  float dLocal = sd_Pa_UHP(q, N, a);
  dWorld = dLocal / max(sDown, 1e-9); // world-scaled signed distance (for AA)
  q_base = q;

  // small epsilon avoids cracks on edges
  float eps = 1e-4 / max(sDown, 1.0);
  return dLocal <= eps;
}

// ---------- choose level: test k0, k0+1, k0-1 ----------
vec2 chooseLevel(vec2 p, int N, float a, out int kChosen, out vec2 qChosen, out float sDownChosen, out float dWorld){
  float lam    = float(N - 3);
  float loglam = log(max(lam, 1.000001));
  int k0 = int(floor(log(max(p.y, 1e-9)) / loglam));

  // First pass: accept the first that is inside
  vec2 qb; float sD, dW;
  if (insideAtLevel(p, N, a, k0, qb, sD, dW)){ kChosen=k0; qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }
  if (insideAtLevel(p, N, a, k0+1, qb, sD, dW)){ kChosen=k0+1; qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }
  if (insideAtLevel(p, N, a, k0-1, qb, sD, dW)){ kChosen=k0-1; qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }

  // Second pass: choose the closest of the three (min |distance|)
  float bestAbs=1e9; int bestK=k0; vec2 bestQ=qb; float bestS=sD; float bestDW=dW;
  // k0
  insideAtLevel(p, N, a, k0, qb, sD, dW); float A = abs(dW);
  if (A < bestAbs){ bestAbs=A; bestK=k0; bestQ=qb; bestS=sD; bestDW=dW; }
  // k0+1
  insideAtLevel(p, N, a, k0+1, qb, sD, dW); A = abs(dW);
  if (A < bestAbs){ bestAbs=A; bestK=k0+1; bestQ=qb; bestS=sD; bestDW=dW; }
  // k0-1
  insideAtLevel(p, N, a, k0-1, qb, sD, dW); A = abs(dW);
  if (A < bestAbs){ bestAbs=A; bestK=k0-1; bestQ=qb; bestS=sD; bestDW=dW; }

  kChosen = bestK; qChosen = bestQ; sDownChosen = bestS; dWorld = bestDW;
  return bestQ;
}

// ---------- palette ----------
vec3 levelColor(int k){
  float h = fract(0.60 + 0.12*float(k));
  float s = 0.70, v = 0.95;
  vec3 K = vec3(1.0, 2.0/3.0, 1.0/3.0);
  vec3 P = abs(fract(vec3(h)+K) * 6.0 - 3.0);
  return v * mix(vec3(1.0), clamp(P - 1.0, 0.0, 1.0), s);
}

void main(){
  // pixel coords
  vec2 fragCoord = (vPos*0.5 + 0.5) * uResolution;

  // parameters
  int   N = max(uN, 5);
  float a = uA;

  // world coords in UHP
  vec2 p = toWorld(fragCoord, N, a);

  // background + real axis
  vec3 col = vec3(0.06);
  float axis = 1.0 - smoothstep(0.0, 2.0*fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

  // choose correct level & get base-wrapped coords
  int   k;
  vec2  q;
  float sDown, dWorld;
  chooseLevel(p, N, a, k, q, sDown, dWorld);

  // AA outline + fill using world-scaled distance for constant thickness
  float px   = fwidth(dWorld);
  float edge = 1.0 - smoothstep(0.0, 2.0*px, abs(dWorld));
  float fill = 1.0 - smoothstep(0.0, px, dWorld);

  vec3 fillCol = levelColor(k);
  col = mix(col, fillCol, fill);
  col = mix(col, vec3(1.0), max(edge, 0.0));

  gl_FragColor = vec4(col, 1.0);
}

