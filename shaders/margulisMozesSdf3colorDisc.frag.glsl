// Margulis-Mozes Theorem 5 tiling — Poincaré disc, polygon SDF edges, 3-coloring.
//
// Valid 3-coloring for ODD branching factor m (3, 5, 7, ...).

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

vec3 color3(int id){
  if(id==0) return vec3(0.93,0.40,0.40);
  if(id==1) return vec3(0.42,0.72,0.98);
  return vec3(0.52,0.92,0.56);
}

int getColor(int h, int l, int N){
  int h_increment = 0;
  int current_l = l;

  for(int i = 0; i < 40; i++){
    if(current_l == 0 || current_l == -1) break;
    int quotient = int(floor(float(current_l) / float(N)));
    int remainder = current_l - quotient * N;
    if((remainder & 1) == 1) h_increment++;
    current_l = quotient;
  }

  int final_l = current_l;
  int result = h + h_increment - final_l;
  return int(mod(float(result), 3.0));
}

vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b,b);
  return vec2((a.x*b.x+a.y*b.y)/d, (a.y*b.x-a.x*b.y)/d);
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

float polygonSDF(vec2 lp, float m, float a){
  float tW = m * a;
  float d = 1e10;

  for(int k = 0; k < MAX_CHILDREN; k++){
    if(float(k) >= m) break;
    d = min(d, geodesicSDF(lp,
        vec2(float(k) * a, 1.0),
        vec2(float(k + 1) * a, 1.0)));
  }

  d = min(d, geodesicSDF(lp, vec2(0.0, m), vec2(tW, m)));
  d = min(d, sdfSegment(lp, vec2(0.0, 1.0), vec2(0.0, m)));
  d = min(d, sdfSegment(lp, vec2(tW, 1.0), vec2(tW, m)));

  return d;
}

void main(){
  float m  = max(uChildren, 3.0);
  float a  = max(uParam, 0.01);
  float hw = max(uThickness, 0.001);
  float tW = m * a;
  float logB = log2(m);
  int   N  = int(m);

  vec2 R  = uResolution;
  vec2 uv = (vPos*0.5+0.5)*R;
  vec2 s  = (2.0*uv - R)/R.y;

  float r2 = dot(s,s);
  vec3 col = vec3(1.0);

  if(r2 < 1.0){
    vec2 z   = s;
    vec2 num = vec2(1.0+z.x,  z.y);
    vec2 den = vec2(1.0-z.x, -z.y);
    vec2 w   = cdiv(num, den);
    vec2 zeta= vec2(-w.y, w.x);

    float zoom = max(uZoom, 0.1);
    float x = zeta.x / zoom, y = zeta.y / zoom;

    float eps = max(1e-6, fwidth(y));
    float yC  = max(y, eps);

    int   n = int(floor(log2(yC)/logB));
    float K = pow(m, float(-n));

    float xren = K*x;
    float yren = K*y;
    float cell = floor(xren/tW);
    float xmod = xren - cell*tW;

    // Cap detection
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

    // 3-coloring
    int h  = -n;
    int l  = int(cell);
    int id = getColor(h, l, N);
    vec3 tc = color3(id);

    // Polygon SDF edges
    float d  = polygonSDF(vec2(xmod, yren), m, a);
    float pw = fwidth(d);
    float hypThick = hw * yren;
    float edgeLine = smoothstep(hypThick + pw, max(hypThick - pw, 0.0), d);

    float fade = smoothstep(0.0, 3.0*eps, y);
    col = mix(vec3(1.0), tc, fade);
    col = mix(col, vec3(0.15), edgeLine * fade);

    // Disc boundary
    float dr = 1.0 - sqrt(r2);
    float px = fwidth(s.x) + fwidth(s.y);
    float edge = smoothstep(0.0, 2.0*px, dr);
    col = mix(vec3(1.0), col, edge);
  }

  gl_FragColor = vec4(col, 1.0);
}
