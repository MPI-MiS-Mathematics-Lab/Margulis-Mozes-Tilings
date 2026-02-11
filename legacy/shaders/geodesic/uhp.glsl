void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Map pixel → UHP coordinates
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    vec2 p  = vec2(uv.x * UHP_SCALE, uv.y * UHP_SCALE + UHP_YOFF);

    float pixel = UHP_SCALE / min(iResolution.x, iResolution.y);
    float aa    = 1.5 * pixel;

    // Below x-axis → exterior
    if (p.y < 0.0) {
        // Draw x-axis boundary line
        float axD = abs(p.y);
        vec3 c = mix(BOUNDARY_COLOR, EXTERIOR_COLOR, smoothstep(pixel * 0.5, pixel * 2.0, axD));
        fragColor = vec4(c, 1.0);
        return;
    }

    vec3 col = BG_COLOR;

    // X-axis boundary
    col = mix(BOUNDARY_COLOR, col, smoothstep(pixel * 0.5, pixel * 2.0, p.y));

    // Geodesic segment with correct hyperbolic width
    float geoDist     = geodesicSDF_UHP(p, uP1, uP2);
    float hypThick    = uLineWidth * max(p.y, 0.001);   // Euclidean half-width = hyp_width × y
    float geoLine     = smoothstep(hypThick + aa, max(hypThick - aa, 0.0), geoDist);
    col = mix(col, GEODESIC_COLOR, geoLine);

    // Endpoint A (constant hyperbolic radius)
    float ptR   = 0.1;
    float eucR1 = ptR * uP1.y;
    float d1    = length(p - uP1);
    col = mix(col, POINT_A_COLOR, smoothstep(eucR1 + aa, max(eucR1 - aa, 0.0), d1));

    // Endpoint B
    float eucR2 = ptR * uP2.y;
    float d2    = length(p - uP2);
    col = mix(col, POINT_B_COLOR, smoothstep(eucR2 + aa, max(eucR2 - aa, 0.0), d2));

    fragColor = vec4(col, 1.0);
}
