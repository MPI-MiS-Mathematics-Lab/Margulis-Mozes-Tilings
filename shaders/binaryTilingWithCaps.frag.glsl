#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
varying vec2 vPos;

#define AA 1

vec3 color4(int id){
  if(id==0) return vec3(0.93,0.40,0.40);
  if(id==1) return vec3(0.42,0.72,0.98);
  if(id==2) return vec3(0.52,0.92,0.56);
  return vec3(0.95,0.86,0.45);
}

vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b,b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}

void main(){
  vec2 R = uResolution;
  vec3 acc = vec3(0.0);

#if AA>1
  for(int A=0;A<AA;A++) for(int B=0;B<AA;B++){
    vec2 uv = (vPos*0.5 + 0.5) * R + vec2(float(A), float(B))/float(AA);
    vec2 s  = (2.0*uv - R)/R.y;
#else
    vec2 uv = (vPos*0.5 + 0.5) * R;
    vec2 s  = (2.0*uv - R)/R.y;
#endif

    float r2 = dot(s,s);

    vec3 col = vec3(1.0);

    if(r2 < 1.0){
      vec2 z   = s;
      vec2 num = vec2(1.0, 0.0) + z;
      vec2 den = vec2(1.0, 0.0) - z;
      vec2 w   = cdiv(num, den);
      vec2 zeta= vec2(-w.y, w.x);

      float x = zeta.x;
      float y = zeta.y;

      float eps = max(1e-12, fwidth(y));
      int   n   = int(floor(log2(max(y, eps))));
      float K   = exp2(float(-n));

      float xren = K * x;
      float yren = K * y;

      float cell = floor(xren);

      float xmod = xren - cell;
      float ymod = yren;

      const float c0  = 0.25;
      const float c1  = 0.75;
      const float rb2 = 1.0 + 0.25*0.25;

      bool underCap =
        ((xmod - c0)*(xmod - c0) + ymod*ymod < rb2) ||
        ((xmod - c1)*(xmod - c1) + ymod*ymod < rb2);

      if(underCap){
        n    -= 1;
        xren *= 2.0;
        yren *= 2.0;
        cell  = floor(xren);
      }

      int pN = (n & 1);
      int pJ = int(mod(cell, 2.0));

      int id = (pN<<1) | pJ;
      col = color4(id);

      float fade = smoothstep(0.0, 3.0*eps, y);
      col = mix(vec3(1.0), col, fade);

      float dr = 1.0 - sqrt(r2);
      float px = fwidth(s.x) + fwidth(s.y);
      float edge = smoothstep(0.0, 2.0*px, dr);
      col = mix(vec3(1.0), col, edge);
    }

    acc += col;

#if AA>1
  }
  acc /= float(AA*AA);
#endif

  gl_FragColor = vec4(acc,1.0);
}
