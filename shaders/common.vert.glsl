varying vec2 vPos;      // clip-space position in [-1,1]^2
void main() {
  vPos = position.xy;
  gl_Position = vec4(position.xy, 0.0, 1.0);
}

