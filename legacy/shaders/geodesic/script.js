/**
 * Hyperbolic Geodesic — script.js
 *
 * Drag the two endpoints in either view (UHP or Poincaré disc).
 * Points are stored in UHP coordinates and synced to uniforms uP1, uP2.
 */

// Must match the constants in common.glsl
const UHP_SCALE  = 4.0;
const UHP_YOFF   = 1.5;
const DISC_SCALE = 2.5;

const points = [
  [-0.5, 1.2],   // uP1 in UHP coords
  [ 0.8, 0.6],   // uP2 in UHP coords
];

let dragging = -1;
let wasPressed = false;

// ─── Coordinate conversions (pixel → model) ─────────────────────────────────

function pixelToUHP(mx, my, w, h) {
  const s = Math.min(w, h);
  return [
    (mx - w * 0.5) / s * UHP_SCALE,
    (my - h * 0.5) / s * UHP_SCALE + UHP_YOFF,
  ];
}

function pixelToDisc(mx, my, w, h) {
  const s = Math.min(w, h);
  return [
    (mx - w * 0.5) / s * DISC_SCALE,
    (my - h * 0.5) / s * DISC_SCALE,
  ];
}

// Cayley inverse: disc → UHP,  z = i(1+w)/(1−w)
function discToUHP(u, v) {
  const a = -v, b = 1 + u;
  const c = 1 - u, d = -v;
  const denom = c * c + d * d;
  if (denom < 1e-8) return [0, 1];
  return [(a * c + b * d) / denom, (b * c - a * d) / denom];
}

function dist2(a, b) {
  const dx = a[0] - b[0], dy = a[1] - b[1];
  return dx * dx + dy * dy;
}

// ─── Engine hooks ────────────────────────────────────────────────────────────

export function setup(api) {
  api.setUniformValue('uP1', points[0]);
  api.setUniformValue('uP2', points[1]);
}

export function onFrame(api) {
  if (!api.getCrossViewState) return;

  const uhp  = api.getCrossViewState('uhp');
  const disc = api.getCrossViewState('disc');

  let pressed = false;
  let uhpPos  = null;

  // Check UHP view mouse
  if (uhp && uhp.mousePressed) {
    pressed = true;
    const [w, h] = uhp.resolution;
    uhpPos = pixelToUHP(uhp.mouse[0], uhp.mouse[1], w, h);
  }
  // Check disc view mouse
  else if (disc && disc.mousePressed) {
    pressed = true;
    const [w, h] = disc.resolution;
    const [du, dv] = pixelToDisc(disc.mouse[0], disc.mouse[1], w, h);
    if (du * du + dv * dv < 1.0) {
      uhpPos = discToUHP(du, dv);
    }
  }

  if (pressed && uhpPos && uhpPos[1] > 0.01) {
    if (!wasPressed) {
      // Mouse-down: pick the nearest endpoint
      const d0 = dist2(uhpPos, points[0]);
      const d1 = dist2(uhpPos, points[1]);
      dragging = d0 < d1 ? 0 : 1;
    }
    // Move the dragged point
    points[dragging][0] = uhpPos[0];
    points[dragging][1] = Math.max(uhpPos[1], 0.01);

    api.setUniformValue('uP1', [...points[0]]);
    api.setUniformValue('uP2', [...points[1]]);
  }

  if (!pressed) {
    dragging = -1;
  }
  wasPressed = pressed;
}
