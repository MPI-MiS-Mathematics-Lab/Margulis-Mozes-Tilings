#ifdef GL_ES
precision highp float;
#endif
#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2  uResolution;
uniform int   uN;     // n >= 5
uniform float uA;     // a > 0

varying vec2 vPos;

// ---------- small complex helper ----------
vec2 cdiv(vec2 a, vec2 b){ // complex division a/b
  float d = dot(b,b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}

// ---------- UHP geodesic SDF helpers ----------
float sdVertical(vec2 p, float x0, float s){ return s*(p.x - x0); }
float sdCircle (vec2 p, float c, float R, float s){
  float d = length(vec2(p.x - c, p.y)) - R;
  return s * d;
}

// Base polygon P_a in the UHP (<=0 inside)
float sd_Pa_UHP(vec2 p, int N, float a){
  int m = N - 3;
  float d = -1e9;

  // left/right verticals: x in [0, m*a]
  d = max(d, sdVertical(p, 0.0, -1.0));            // x >= 0
  float W = float(m)*a;
  d = max(d, sdVertical(p, W,  +1.0));             // x <= W

  // bottom arcs between ((j-1)a + i) and (j a + i) (equal heights y=1)
  float Rb = sqrt(1.0 + 0.25*a*a);
  const int MAXN = 64;
  for(int j=1; j<MAXN; ++j){
    if(j > N-3) break;
    float c = (float(j) - 0.5)*a;
    // interior ABOVE arc => outside disk => s = -1
    d = max(d, sdCircle(p, c, Rb, -1.0));
  }

  // top arc between (0, m) and (m a, m)
  float yTop = float(m);
  float cTop = 0.5 * float(m) * a;
  float RTop = sqrt(cTop*cTop + yTop*yTop);
  // interior BELOW arc => inside disk => s = +1
  d = max(d, sdCircle(p, cTop, RTop, +1.0));

  return d;
}

// ---------- membership at a specific level k (UHP) ----------
bool insideAtLevel(vec2 p, int N, float a, int k, out vec2 q_base, out float sDown, out float dWorld){
  float lam = float(N - 3);
  float W   = float(N - 3) * a;

  // scale to base, then wrap x by base period
  sDown = pow(lam, -float(k));      // lam^{-k}
  vec2 q = p * sDown;               // base coords
  q.x -= W * floor(q.x / W);

  float dLocal = sd_Pa_UHP(q, N, a);
  dWorld = dLocal / max(sDown, 1e-9); // scale back for AA thickness
  q_base = q;

  float eps = 1e-4 / max(sDown, 1.0);
  return dLocal <= eps;
}

// ---------- choose level: test k0, k0±1 ----------
vec2 chooseLevel(vec2 p, int N, float a, out int kChosen, out vec2 qChosen, out float sDownChosen, out float dWorld){
  float lam    = float(N - 3);
  float loglam = log(max(lam, 1.000001));
  int k0 = int(floor(log(max(p.y, 1e-9)) / loglam));

  vec2 qb; float sD, dW;
  if (insideAtLevel(p, N, a, k0,   qb, sD, dW)){ kChosen=k0;   qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }
  if (insideAtLevel(p, N, a, k0+1, qb, sD, dW)){ kChosen=k0+1; qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }
  if (insideAtLevel(p, N, a, k0-1, qb, sD, dW)){ kChosen=k0-1; qChosen=qb; sDownChosen=sD; dWorld=dW; return qb; }

  // closest of the three
  float bestAbs=1e9; int bestK=k0; vec2 bestQ=qb; float bestS=sD; float bestDW=dW;
  insideAtLevel(p, N, a, k0,   qb, sD, dW); float A=abs(dW); if (A<bestAbs){bestAbs=A; bestK=k0;   bestQ=qb; bestS=sD; bestDW=dW;}
  insideAtLevel(p, N, a, k0+1, qb, sD, dW); A=abs(dW); if (A<bestAbs){bestAbs=A; bestK=k0+1; bestQ=qb; bestS=sD; bestDW=dW;}
  insideAtLevel(p, N, a, k0-1, qb, sD, dW); A=abs(dW); if (A<bestAbs){bestAbs=A; bestK=k0-1; bestQ=qb; bestS=sD; bestDW=dW;}

  kChosen=bestK; qChosen=bestQ; sDownChosen=bestS; dWorld=bestDW; return bestQ;
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
  // Screen -> centered square coords with preserved aspect
  vec2 fragCoord = (vPos*0.5 + 0.5) * uResolution;
  vec2 s = (2.0*fragCoord - uResolution) / min(uResolution.x, uResolution.y); // [-1,1]^2 scaled

  float r2 = dot(s,s);
  vec3 col = vec3(0.06);          // background (outside disk)

  if (r2 < 1.0) {
    // Disk -> UHP via Cayley: ζ = i * (1 + z) / (1 - z)
    vec2 z   = s;
    vec2 num = vec2(1.0, 0.0) + z;
    vec2 den = vec2(1.0, 0.0) - z;
    vec2 w   = cdiv(num, den);
    vec2 zeta= vec2(-w.y, w.x); // multiply by i

    // choose level & fold to base FD (in UHP)
    int   k; vec2 q; float sDown, dWorld;
    chooseLevel(zeta, uN, uA, k, q, sDown, dWorld);

    // AA outline + fill (use world-scaled distance for constant thickness)
    float px   = fwidth(dWorld);
    float edge = 1.0 - smoothstep(0.0, 1.0*px, abs(dWorld));
    float fill = 1.0 - smoothstep(0.0, px, dWorld);

    vec3 fillCol = levelColor(k);
    col = mix(col, fillCol, fill);
    col = mix(col, vec3(1.0), max(edge, 0.0));


  }

  gl_FragColor = vec4(col, 1.0);
}

