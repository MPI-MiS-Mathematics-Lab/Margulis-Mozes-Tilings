#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
uniform sampler2D uTex1;
uniform sampler2D uTex2;
uniform sampler2D uTex3;
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

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 R = uResolution.xy;
  vec2 s = (2.0 * fragCoord - R) / R.y;

  vec3 col = vec3(0.06);  // Background

  float r2 = dot(s, s);
  float boundary = smoothstep(1.0 - 4.0 * fwidth(r2), 1.0, r2);
  col = mix(col, vec3(0.85), boundary);

  if (r2 >= 1.0) {
    gl_FragColor = vec4(col, 1.0);
    return;
  }

  // Draw a vertical axis for orientation
  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(s.x), abs(s.x));
  col = mix(col, vec3(0.85), axis);

  vec2 p = diskToUhp(s);

  float eps = max(1e-6, fwidth(p.y));
  float yClamped = max(p.y, eps);

  // Compute level n using log base 3 (instead of log base 2)
  float log3y = log(yClamped) / log(3.0);
  int n = int(floor(log3y));

  // h is the tree level: h=0 for root (1 tile), h=1 for children (3 tiles), etc.
  int h = -n;

  // Cells per unit x at this level: 3^h
  float cells = pow(3.0, float(-n));

  // Horizontal index l, offset so root (l=0) is centered at x=0
  int l = int(floor((p.x + 0.5) * cells));

  float xLocal = fract((p.x + 0.5) * cells);
  float yRen = p.y * pow(3.0, float(-n));
  float yLocal = clamp((yRen - 1.0) * 0.5, 0.0, 1.0);
  vec2 uv = vec2(xLocal, yLocal);

  float rnd = hash21(vec2(float(h), float(l)));
  int texId = int(floor(rnd * 3.0));

  vec3 tex = texture2D(uTex1, uv).rgb;
  if (texId == 1) {
    tex = texture2D(uTex2, uv).rgb;
  } else if (texId == 2) {
    tex = texture2D(uTex3, uv).rgb;
  }

  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tex, fade);

  gl_FragColor = vec4(col, 1.0);
}
