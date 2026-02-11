void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Map pixel → disc coordinates
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    vec2 p  = uv * DISC_SCALE;

    float pixel = DISC_SCALE / min(iResolution.x, iResolution.y);
    float aa    = 1.5 * pixel;
    float r2    = dot(p, p);

    // Outside disc → exterior + boundary ring
    if (r2 > 1.0) {
        float bdist = abs(length(p) - 1.0);
        vec3 c = mix(BOUNDARY_COLOR, EXTERIOR_COLOR, smoothstep(pixel * 0.5, pixel * 2.0, bdist));
        fragColor = vec4(c, 1.0);
        return;
    }

    vec3 col = BG_COLOR;

    // Boundary circle (inside edge)
    float bdist = 1.0 - length(p);
    col = mix(BOUNDARY_COLOR, col, smoothstep(pixel * 0.5, pixel * 2.0, bdist));

    // Convert UHP endpoints to disc
    vec2 w1 = uhpToDisc(uP1);
    vec2 w2 = uhpToDisc(uP2);

    // Geodesic segment with correct hyperbolic width
    float geoDist  = geodesicSDF_Disc(p, w1, w2);
    float conformal = max((1.0 - r2) * 0.5, 0.0);          // (1 − |z|²)/2
    float hypThick  = uLineWidth * conformal;
    float geoLine   = smoothstep(hypThick + aa, max(hypThick - aa, 0.0), geoDist);
    col = mix(col, GEODESIC_COLOR, geoLine);

    // Endpoint A
    float ptR  = 0.1;
    float c1   = max((1.0 - dot(w1, w1)) * 0.5, 0.001);
    float d1   = length(p - w1);
    float er1  = ptR * c1;
    col = mix(col, POINT_A_COLOR, smoothstep(er1 + aa, max(er1 - aa, 0.0), d1));

    // Endpoint B
    float c2   = max((1.0 - dot(w2, w2)) * 0.5, 0.001);
    float d2   = length(p - w2);
    float er2  = ptR * c2;
    col = mix(col, POINT_B_COLOR, smoothstep(er2 + aa, max(er2 - aa, 0.0), d2));

    fragColor = vec4(col, 1.0);
}
