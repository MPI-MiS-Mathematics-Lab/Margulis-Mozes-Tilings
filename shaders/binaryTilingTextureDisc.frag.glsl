#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
uniform sampler2D uTexture;
varying vec2 vPos;

// Complex division helper: (a / b)
vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b, b);
  return vec2(
    (a.x * b.x + a.y * b.y) / d,
    (a.y * b.x - a.x * b.y) / d
  );
}

// Map from Poincaré disk to upper half-plane via Cayley transform.
vec2 diskToUhp(vec2 z){
  vec2 num = vec2(1.0 + z.x, z.y);
  vec2 den = vec2(1.0 - z.x, -z.y);
  vec2 w = cdiv(num, den);     // (1 + z) / (1 - z)
  return vec2(-w.y, w.x);      // multiply by i to land in the UHP
}

void main(){
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 R = uResolution.xy;
  vec2 s = (2.0 * fragCoord - R) / R.y;

  vec3 col = vec3(0.06);

  float r2 = dot(s, s);
  float boundary = smoothstep(1.0 - 4.0 * fwidth(r2), 1.0, r2);
  col = mix(col, vec3(0.85), boundary);

  if (r2 >= 1.0) {
    gl_FragColor = vec4(col, 1.0);
    return;
  }

  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(s.x), abs(s.x));
  col = mix(col, vec3(0.85), axis);

  vec2 p = diskToUhp(s);

  float eps = max(1e-6, fwidth(p.y));
  float yClamped = max(p.y, eps);
  float level = floor(log2(yClamped));
  float scale = exp2(-level);

  vec2 base = p * scale;
  float u = fract(base.x);
  float v = clamp(base.y - 1.0, 0.0, 1.0);

  vec3 tex = texture2D(uTexture, vec2(u, v)).rgb;

  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tex, fade);

  gl_FragColor = vec4(col, 1.0);
}
