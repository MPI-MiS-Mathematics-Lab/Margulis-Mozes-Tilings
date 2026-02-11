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
  float hWidth = max(uThickness, 0.001);

  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord);

  vec3 col = vec3(0.06);

  // ── x-axis line ──
  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

  if(p.y > 0.0){
    float x = p.x;
    float y = p.y;

    float eps = max(1e-6, fwidth(y));
    float yClamped = max(y, eps);
    int   n   = int(floor(log2(yClamped)));
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
    vec3 texCol;
    if(id == 0)      texCol = texture2D(uTex1, tUV).rgb;
    else if(id == 1) texCol = texture2D(uTex2, tUV).rgb;
    else if(id == 2) texCol = texture2D(uTex3, tUV).rgb;
    else             texCol = texture2D(uTex4, tUV).rgb;

    float fade = smoothstep(0.0, 3.0 * eps, y);
    col = mix(col, texCol, fade);

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
    col = mix(col, vec3(0.15), line * fade);
  }

  gl_FragColor = vec4(col, 1.0);
}
