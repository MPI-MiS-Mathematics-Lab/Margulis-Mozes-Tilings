#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
varying vec2 vPos;

#define AA 1
const float PI    = 3.14159265358979323846;
const float SQRT2 = 1.41421356237309504880;

vec2 cadd(vec2 a, vec2 b){ return a + b; }
vec2 csub(vec2 a, vec2 b){ return a - b; }
vec2 cmul(vec2 a, vec2 b){ return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x); }
vec2 cscal(vec2 a, float s){ return a * s; }
vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b,b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}
float cosh1(float x){ float ex=exp(x), emx=exp(-x); return 0.5*(ex+emx); }
float sinh1(float x){ float ex=exp(x), emx=exp(-x); return 0.5*(ex-emx); }
vec2 ccos(vec2 z){ return vec2(cos(z.x)*cosh1(z.y), -sin(z.x)*sinh1(z.y)); }

const float q   = 0.04321391826377226;
const float q14 = 0.45593812776599624;
const float th2_0 = 0.9135791381561168;
const float th4_0 = 0.9135791381561169;
const float Ke    = 1.8540746773013725;

vec2 theta2(vec2 v){
  vec2 sum = vec2(0.0);
  float r = 1.0;
  float inc = q*q;
  for(int n=0; n<5; ++n){
    float k = float(2*n + 1);
    sum += cscal(ccos(cscal(v, k)), r);
    r   *= inc;
    inc *= (q*q);
  }
  return cscal(sum, 2.0*q14);
}

vec2 theta4(vec2 v){
  vec2 sum = vec2(1.0, 0.0);
  float qp  = q;
  float q2  = q*q;
  float step= q*q*q;
  float sgn = -1.0;
  for(int n=1; n<=5; ++n){
    sum += cscal(ccos(cscal(v, 2.0*float(n))), 2.0*sgn*qp);
    qp   *= step;
    step *= q2;
    sgn  = -sgn;
  }
  return sum;
}

vec2 jacobi_cn_from_v(vec2 v){
  vec2 num = cscal(theta2(v), th4_0);
  vec2 den = cscal(theta4(v), th2_0);
  return cdiv(num, den);
}

vec2 diskFromSquare(vec2 z){
  vec2 v = csub(cmul(vec2(0.5, 0.5), z), vec2(1.0, 0.0));
  v = cscal(v, 0.5 * PI);
  vec2 cn = jacobi_cn_from_v(v);
  vec2 c  = vec2(1.0/SQRT2, -1.0/SQRT2);
  return cmul(c, cn);
}

vec3 color4(int id){
  if(id==0) return vec3(0.0, 0.0, 0.0);
  if(id==1) return vec3(1.0, 0.0, 0.0);
  return vec3(1.0, 0.8, 0.0);
}

void main(){
  vec2 R  = uResolution;
  vec2 ar = R / min(R.x, R.y);
  vec2 s  = vPos * ar;

  float dSquare = 1.0 - max(abs(s.x), abs(s.y));
  float pxs = fwidth(s.x) + fwidth(s.y);
  float gateSquare = smoothstep(0.0, 2.0*pxs, dSquare);

  vec3 col = vec3(1.0);
  if(dSquare > 0.0){
    vec2 z = diskFromSquare(s);
    float r2 = dot(z,z);

    if(r2 < 1.0){
      vec2 num = cadd(vec2(1.0,0.0), z);
      vec2 den = csub(vec2(1.0,0.0), z);
      vec2 w   = cdiv(num, den);
      vec2 zeta= vec2(-w.y, w.x);

      float x = zeta.x;
      float y = zeta.y;

      float eps = max(1e-12, fwidth(y));
      int   n   = int(floor(log2(max(y, eps))));
      int   pN  = (n & 1);
      float cells = exp2(float(-n));
      int   pJ  = int(mod(floor(x * cells), 3.0));

      int id = (pN*pJ + (1-pN)*(2-pJ))%3;
      col = color4(id);

      float fade = smoothstep(0.0, 3.0*eps, y);
      col = mix(vec3(1.0), col, fade);

      col = mix(vec3(1.0), col, gateSquare);
    }
  }

  gl_FragColor = vec4(col, 1.0);
}
