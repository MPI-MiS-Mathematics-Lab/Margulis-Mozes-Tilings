#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2 uResolution;
varying vec2 vPos;

// 3 colors for valid 3-coloring
vec3 color3(int id) {
  if(id == 0) return vec3(0.93, 0.40, 0.40);  // red
  if(id == 1) return vec3(0.42, 0.72, 0.98);  // blue
  return vec3(0.52, 0.92, 0.56);              // green
}

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

// Implements the AlphaEvolve coloring algorithm:
// color = (h + count_of_1s_in_base3(l) - final_l) % 3
int getColor(int h, int l) {
  int h_increment = 0;
  int current_l = l;

  // Trace l back to base case (l == 0 or l == -1)
  // This counts the number of '1' digits in base-3 representation
  for (int i = 0; i < 32; i++) {
    if (current_l == 0 || current_l == -1) break;

    // Floor division: floor(l / 3)
    int quotient = int(floor(float(current_l) / 3.0));
    // Remainder: l - quotient * 3 (gives floor modulo)
    int remainder = current_l - quotient * 3;

    // Count '1' digits in base-3
    if (remainder == 1) h_increment++;
    current_l = quotient;
  }

  int final_l = current_l;  // Either 0 or -1

  // color = (h + h_increment - final_l) % 3
  int result = h + h_increment - final_l;
  result = int(mod(float(result), 3.0));
  return result;
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

  int colorId = getColor(h, l);
  vec3 tileColor = color3(colorId);

  float fade = smoothstep(0.0, 3.0 * eps, p.y);
  col = mix(col, tileColor, fade);

  gl_FragColor = vec4(col, 1.0);
}
