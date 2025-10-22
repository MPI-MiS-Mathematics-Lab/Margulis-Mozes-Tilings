#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;

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

void render(out vec4 O, in vec2 U){
  vec2 R = uResolution.xy;
  vec3 acc = vec3(0.0);

#if AA>1
  for(int a=0;a<AA;a++) for(int b=0;b<AA;b++){
    vec2 uv = (U + vec2(a,b)/float(AA));
    vec2 s  = (2.0*uv - R)/R.y;
#else
    vec2 s  = (2.0*U - R)/R.y;
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
      int   pN  = (n & 1);

      float cells = exp2(float(-n));
      int   pJ  = int(mod(floor(x * cells), 2.0));

      int id = (pN<<1) | pJ;
      vec3 tcol = color4(id);
      col = tcol;

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

  O = vec4(acc, 1.0);
}

void main() {
  vec4 outColor;
  render(outColor, gl_FragCoord.xy);
  gl_FragColor = outColor;
}
