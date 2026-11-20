shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
varying vec3 world;

float wave(vec2 p) {
    float shelter = mix(0.12, 0.48, smoothstep(155.0, 260.0, p.y));
    return shelter * (sin(p.x * 0.13 + p.y * 0.09 + clock * 1.1)
        + 0.38 * sin(p.x * -0.31 + p.y * 0.21 + clock * 1.8));
}
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += wave(p.xz);
    float dx = (wave(p.xz + vec2(0.2,0.0)) - wave(p.xz - vec2(0.2,0.0))) / 0.4;
    float dz = (wave(p.xz + vec2(0.0,0.2)) - wave(p.xz - vec2(0.0,0.2))) / 0.4;
    NORMAL = normalize(vec3(-dx, 1.0, -dz));
    world = p;
}
void fragment() {
    float ripple = sin(world.x * 1.4 + clock * 1.3) * sin(world.z * 1.9 - clock);
    ALBEDO = mix(vec3(0.035,0.16,0.20), vec3(0.09,0.29,0.34), ripple * 0.15 + 0.5);
    ROUGHNESS = 0.24;
    METALLIC = 0.28;
}
