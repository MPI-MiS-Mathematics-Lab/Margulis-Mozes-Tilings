#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
uniform sampler2D uTexture;
varying vec2 vPos;

vec2 toWorld(vec2 fragCoord){
  const vec2 minBounds = vec2(-6.0, 0.0);
  const vec2 maxBounds = vec2(6.0, 8.0);
  vec2 size = maxBounds - minBounds;
  float scale = uResolution.y / size.y;
  float centerX = 0.5 * (minBounds.x + maxBounds.x);
  float worldX = (fragCoord.x - 0.5 * uResolution.x) / scale + centerX;
  float worldY = (fragCoord.y / scale) + minBounds.y;
  return vec2(worldX, worldY);
}

void main(){
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord);

  vec3 col = vec3(0.06);

  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

  if (p.y <= 0.0) {
    gl_FragColor = vec4(col, 1.0);
    return;
  }

  float eps = max(1e-6, fwidth(p.y));
  float yClamped = max(p.y, eps);
  float level = floor(log2(yClamped));
  float scale = exp2(-level);

  vec2 base = p * scale;
  float yBase = base.y;

  float u = fract(base.x);
  float v = clamp(yBase - 1.0, 0.0, 1.0);

  vec3 tex = texture2D(uTexture, vec2(u, v)).rgb;
  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tex, fade);

  gl_FragColor = vec4(col, 1.0);
}
