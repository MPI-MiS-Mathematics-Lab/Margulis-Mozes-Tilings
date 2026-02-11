#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
varying vec2 vPos;

// Branching factor: each tile has N children.
// Must be ODD (3, 5, 7, ...) for a valid 3-coloring.
#define N 5

vec3 color3(int id) {
  if(id == 0) return vec3(0.93, 0.40, 0.40);
  if(id == 1) return vec3(0.42, 0.72, 0.98);
  return vec3(0.52, 0.92, 0.56);
}

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

// Generalized AlphaEvolve coloring for odd branching factor N:
// color = (h + count_of_odd_digits_in_baseN(l) - final_l) % 3
//
// For base 3, "odd digits" = {1} → original algorithm.
// For base 5, "odd digits" = {1, 3}.
// For base 7, "odd digits" = {1, 3, 5}. Etc.
int getColor(int h, int l) {
  int h_increment = 0;
  int current_l = l;

  for (int i = 0; i < 40; i++) {
    if (current_l == 0 || current_l == -1) break;

    // Floor division and modulo (correct for negative l)
    int quotient = int(floor(float(current_l) / float(N)));
    int remainder = current_l - quotient * N;

    // Count odd digits in base N
    if ((remainder & 1) == 1) h_increment++;
    current_l = quotient;
  }

  int final_l = current_l;

  int result = h + h_increment - final_l;
  result = int(mod(float(result), 3.0));
  return result;
}

void main() {
  vec2 fragCoord = (vPos * 0.5 + 0.5) * uResolution;
  vec2 p = toWorld(fragCoord);

  vec3 col = vec3(0.06);

  float axis = 1.0 - smoothstep(0.0, 2.0 * fwidth(p.y), abs(p.y));
  col = mix(col, vec3(0.85), axis);

  float eps = max(1e-6, fwidth(p.y));
  float yClamped = max(p.y, eps);

  float logNy = log(yClamped) / log(float(N));
  int n = int(floor(logNy));
  int h = -n;

  float cells = pow(float(N), float(-n));
  int l = int(floor((p.x + 0.5) * cells));

  int colorId = getColor(h, l);
  vec3 tileColor = color3(colorId);

  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tileColor, fade);

  gl_FragColor = vec4(col, 1.0);
}
