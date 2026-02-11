#ifdef GL_ES
precision highp float;
#endif

#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

uniform vec2  uResolution;
uniform float uThickness;
uniform float uChildren;
varying vec2  vPos;

vec3 color4(int id){
  if(id==0) return vec3(0.93,0.40,0.40);
  if(id==1) return vec3(0.42,0.72,0.98);
  if(id==2) return vec3(0.52,0.92,0.56);
  return vec3(0.95,0.86,0.45);
}

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

vec2 cadd(vec2 a, vec2 b){ return a + b; }
vec2 csub(vec2 a, vec2 b){ return a - b; }
vec2 cdiv(vec2 a, vec2 b){
  float d = dot(b,b);
  return vec2((a.x*b.x + a.y*b.y)/d, (a.y*b.x - a.x*b.y)/d);
}

float asinh1(float x){
  return log(x + sqrt(x*x + 1.0));
}

float signedDistanceToGeodesic(float a, float b, vec2 z){
  float c = 0.5*(a + b);
  float r = 0.5*abs(b - a);
  float dx = z.x - c;
  return asinh1((dx*dx + z.y*z.y - r*r) / (2.0 * r * max(z.y, 1e-6)));
}

float distanceToVertical(float x0, vec2 z){
  float dx = abs(z.x - x0);
  return asinh1(dx / max(z.y, 1e-6));
}

void main(){
  float childF = max(uChildren, 2.0);
  float hWidth = max(uThickness, 0.001);
  float logBase = log2(childF);

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
    int   n   = int(floor(log2(yClamped) / logBase));
    float K   = pow(childF, float(-n));

    // ── Renormalized coordinates (pre-cap) ──
    float xren = K * x;
    float yren = K * y;       // in [1, childF)

    float cell = floor(xren);
    float xmod = xren - cell;
    float ymod = yren;

    // ── Save pre-cap state for edges ──
    float yrenOrig = yren;
    float xmodOrig = xmod;

    // ── N-ary cap geometry ──
    float rb2 = 1.0 + 1.0 / (4.0 * childF * childF);
    float r0  = sqrt(rb2);

    bool underCap = false;
    float dCapHyp = 1e10;

    for(int k = 0; k < 4; k++){
      if(float(k) < childF){
        float ck = (2.0 * float(k) + 1.0) / (2.0 * childF);
        float dx = xmod - ck;
        float d2 = dx*dx + ymod*ymod;
        if(d2 < rb2) underCap = true;

        float a = ck - r0;
        float b = ck + r0;
        float d = abs(signedDistanceToGeodesic(a, b, vec2(xmod, ymod)));
        dCapHyp = min(dCapHyp, d);
      }
    }

    if(underCap){
      n    -= 1;
      xren *= childF;
      yren *= childF;
      cell  = floor(xren);
      xmod  = xren - cell;
    }

    // ── Tile coloring ──
    int pN = int(mod(float(n) + 4096.0, 2.0));
    int pJ = int(mod(cell, childF));

    int id = int(mod(float(pN * 2 + pJ), 4.0));
    vec3 tileColor = color4(id);

    float fade = smoothstep(0.0, 3.0 * eps, y);
    col = mix(col, tileColor, fade);

    // ── Hyperbolic-thickness edge lines ──
    // Top edge: geodesic from (0, childF) to (1, childF) in pre-cap cell coords
    float topR   = sqrt(0.25 + childF*childF);
    float dTop   = abs(signedDistanceToGeodesic(0.5 - topR, 0.5 + topR, vec2(xmodOrig, yrenOrig)));
    float pwTop  = fwidth(dTop);
    float lineTop = 1.0 - smoothstep(hWidth - pwTop, hWidth + pwTop, dTop);

    // Vertical edges are true geodesics x = const.
    float dV = min(distanceToVertical(0.0, vec2(xmod, yren)), distanceToVertical(1.0, vec2(xmod, yren)));
    float pwV = fwidth(dV);
    float lineV = 1.0 - smoothstep(hWidth - pwV, hWidth + pwV, dV);

    // Cap boundaries are geodesic circles orthogonal to the boundary.
    float pwC = fwidth(dCapHyp);
    float lineC = 1.0 - smoothstep(hWidth - pwC, hWidth + pwC, dCapHyp);

    float line = max(max(lineTop, lineV), lineC);
    col = mix(col, vec3(0.15), line * fade);
  }

  gl_FragColor = vec4(col, 1.0);
}
