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

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord);

  vec3 col = vec3(0.06);  // Background

  // Draw the x-axis
  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

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
