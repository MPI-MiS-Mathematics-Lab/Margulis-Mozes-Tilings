#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2      uResolution;
uniform float     uThickness;
uniform sampler2D uTex1;
uniform sampler2D uTex2;
uniform sampler2D uTex3;
uniform sampler2D uTex4;
varying vec2      vPos;

#define AA 1

vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b,b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}

void main(){
  float hWidth = max(uThickness, 0.001);

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
      // ── Poincaré disk → UHP ──
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

      // ── Renormalized coordinates ──
      float xren = K * x;
      float yren = K * y;       // in [1, 2)

      float cell = floor(xren);
      float xmod = xren - cell; // in [0, 1)

      // ── 4-coloring ──
      int pN = (n & 1);
      int pJ = int(mod(cell, 2.0));
      int id = (pN << 1) | pJ;

      // ── Texture UV from tile-local coordinates ──
      vec2 tUV = vec2(xmod, clamp(yren - 1.0, 0.0, 1.0));

      // ── Sample the texture for this tile ──
      if(id == 0)      col = texture2D(uTex1, tUV).rgb;
      else if(id == 1) col = texture2D(uTex2, tUV).rgb;
      else if(id == 2) col = texture2D(uTex3, tUV).rgb;
      else             col = texture2D(uTex4, tUV).rgb;

      // ── Hyperbolic-thickness edge lines ──

      // Horizontal edges: horocycles at yren = 1 and 2
      float dH = min(yren - 1.0, 2.0 - yren) / yren;
      float pwH = fwidth(dH);
      float lineH = 1.0 - smoothstep(hWidth - pwH, hWidth + pwH, dH);

      // Vertical edges: geodesic rays at integer xren
      float dV = min(xmod, 1.0 - xmod) / yren;
      float pwV = fwidth(dV);
      float lineV = 1.0 - smoothstep(hWidth - pwV, hWidth + pwV, dV);

      float line = max(lineH, lineV);
      col = mix(col, vec3(0.15), line);

      // ── Fade near y = 0 ──
      float fade = smoothstep(0.0, 3.0*eps, y);
      col = mix(vec3(1.0), col, fade);

      // ── Disk boundary ──
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
