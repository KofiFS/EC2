shader_type canvas_item;

// Space background shader with 3D depth, twinkling stars, nebulae, and parallax scrolling

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float nebula_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float depth_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float enable_scroll : hint_range(0.0, 1.0) = 1.0;
uniform float enable_twinkle : hint_range(0.0, 1.0) = 1.0;
uniform float enable_nebula_drift : hint_range(0.0, 1.0) = 1.0;
uniform float enable_parallax : hint_range(0.0, 1.0) = 1.0;

// Color theme - Purple/Blue
uniform vec3 nebula_color1 : source_color = vec3(0.102, 0.039, 0.243);
uniform vec3 nebula_color2 : source_color = vec3(0.176, 0.106, 0.412);
uniform vec3 star_color : source_color = vec3(0.8, 0.85, 1.0);
uniform vec3 accent_color : source_color = vec3(0.545, 0.361, 0.965);

// Hash functions for randomness
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

// Noise function for nebulae
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal brownian motion for nebulae with depth
float fbm(vec2 p, float t, float depth_factor, vec2 base_uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // 3D Parallax for nebulae - use UV-based parallax
    vec2 uv_center = vec2(0.5, 0.5);
    vec2 uv_offset = (base_uv - uv_center) * depth_factor * 0.15 * enable_parallax;
    p += uv_offset;
    
    for (int i = 0; i < 5; i++) {
        vec2 drift = vec2(t * 0.02, t * 0.01) * float(i + 1) * 0.3 * (1.0 + depth_factor * 0.4) * enable_nebula_drift;
        value += amplitude * noise(p * frequency + drift);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Star layer with depth-based size and parallax
float stars(vec2 uv, float scale, float t, float layer_speed, float depth_factor, vec2 base_uv) {
    vec2 scaled_uv = uv * scale;
    
    // 3D Parallax effect - use UV-based parallax
    vec2 uv_center = vec2(0.5, 0.5);
    vec2 uv_offset = (base_uv - uv_center) * depth_factor * 0.25 * enable_parallax;
    scaled_uv += uv_offset;
    
    // Parallax scroll - depth affects speed
    scaled_uv.y += t * layer_speed * (1.0 + depth_factor * 0.5) * enable_scroll;
    
    vec2 grid = floor(scaled_uv);
    vec2 grid_uv = fract(scaled_uv);
    
    float star = 0.0;
    float h = hash(grid);
    
    // Only create stars in some cells based on density
    if (h < star_density * 0.3) {
        vec2 star_pos = vec2(hash(grid + 0.5), hash2(grid + 0.5));
        float dist = length(grid_uv - star_pos);
        
        // Twinkle effect
        float twinkle = 1.0;
        float twinkle_speed = hash(grid * 2.0) * 3.0 + 1.0;
        float twinkle_offset = hash(grid * 3.0) * 6.28;
        twinkle = mix(1.0, 0.5 + 0.5 * sin(t * twinkle_speed + twinkle_offset), enable_twinkle);
        
        // Depth-based size - closer stars are larger
        float base_size = 0.015 + hash(grid * 4.0) * 0.02;
        float size = base_size * (1.0 + depth_factor * 0.8);
        star = smoothstep(size, 0.0, dist) * twinkle;
        
        // Add depth-based brightness - closer stars are brighter
        star *= (1.0 + depth_factor * 0.5);
    }
    
    return star;
}

// Bright star with glow and depth
float bright_star(vec2 uv, float scale, float t, float depth_factor, vec2 base_uv) {
    vec2 scaled_uv = uv * scale;
    
    // 3D Parallax for bright stars - use UV-based parallax
    vec2 uv_center = vec2(0.5, 0.5);
    vec2 uv_offset = (base_uv - uv_center) * depth_factor * 0.3 * enable_parallax;
    scaled_uv += uv_offset;
    
    scaled_uv.y += t * 0.05 * (1.0 + depth_factor * 0.3) * enable_scroll;
    
    vec2 grid = floor(scaled_uv);
    vec2 grid_uv = fract(scaled_uv);
    
    float star = 0.0;
    float h = hash(grid + 100.0);
    
    // Very few bright stars
    if (h < 0.03) {
        vec2 star_pos = vec2(hash(grid + 50.5), hash2(grid + 50.5));
        float dist = length(grid_uv - star_pos);
        
        // Pulse effect
        float pulse_speed = hash(grid * 5.0) * 0.5 + 0.3;
        float pulse = 0.7 + 0.3 * sin(t * pulse_speed);
        
        // Depth-based size
        float core_size = 0.04 * (1.0 + depth_factor * 0.6);
        float glow_size = 0.15 * (1.0 + depth_factor * 0.8);
        
        // Core
        star = smoothstep(core_size, 0.0, dist) * pulse;
        
        // Glow - larger for closer stars
        star += smoothstep(glow_size, 0.0, dist) * 0.3 * pulse * (1.0 + depth_factor);
        
        // Cross flare - depth affects size
        float flare_size = 0.12 * (1.0 + depth_factor * 0.5);
        float flare_width = 0.25 * (1.0 + depth_factor * 0.3);
        float flare_x = smoothstep(flare_size, 0.0, abs(grid_uv.y - star_pos.y)) * smoothstep(flare_width, 0.0, abs(grid_uv.x - star_pos.x));
        float flare_y = smoothstep(flare_size, 0.0, abs(grid_uv.x - star_pos.x)) * smoothstep(flare_width, 0.0, abs(grid_uv.y - star_pos.y));
        star += (flare_x + flare_y) * 0.3 * pulse * (1.0 + depth_factor * 0.5);
    }
    
    return star;
}

void fragment() {
    float t = TIME * time_scale;
    vec2 uv = UV;
    
    // Base dark background
    vec3 color = vec3(0.0, 0.0, 0.02);
    
    // Far nebulae layers (deepest)
    float nebula1 = fbm(uv * 2.0 + vec2(0.0, 0.0), t, 0.0, uv) * nebula_intensity;
    float nebula2 = fbm(uv * 3.0 + vec2(5.0, 3.0), t * 0.7, 0.2, uv) * nebula_intensity;
    float nebula3 = fbm(uv * 1.5 + vec2(10.0, 7.0), t * 0.5, 0.4, uv) * nebula_intensity;
    
    // Apply nebula colors with depth-based intensity
    color += nebula_color1 * nebula1 * 0.8 * max(0.0, 1.0 - 0.3 * depth_intensity);
    color += nebula_color2 * nebula2 * 0.6 * max(0.0, 1.0 - 0.2 * depth_intensity);
    color += mix(nebula_color1, nebula_color2, 0.5) * nebula3 * 0.4 * max(0.0, 1.0 - 0.1 * depth_intensity);
    
    // Star layers with different depths and parallax speeds
    float stars1 = stars(uv, 50.0, t, 0.02, 0.0, uv);
    float stars2 = stars(uv, 30.0, t, 0.05, 0.3, uv);
    float stars3 = stars(uv, 15.0, t, 0.08, 0.6, uv);
    float stars4 = stars(uv, 8.0, t, 0.12, 1.0, uv);
    
    // Combine star layers with depth-based weighting
    float all_stars = stars1 * 0.4 + stars2 * 0.6 + stars3 * 0.8 + stars4;
    color += star_color * all_stars;
    
    // Bright stars with glow at different depths
    float bright1 = bright_star(uv, 8.0, t, 0.3, uv);
    float bright2 = bright_star(uv, 5.0, t, 0.8, uv);
    
    color += accent_color * (bright1 * 1.2 + bright2 * 1.8);
    color += vec3(1.0) * (bright1 * 0.4 + bright2 * 0.6);
    
    // Add depth-based atmospheric fog effect
    vec2 uv_center = vec2(0.5, 0.5);
    float center_dist = length(uv - uv_center);
    float fog_intensity = clamp(center_dist * 0.15 * depth_intensity, 0.0, 0.2);
    color = mix(color, vec3(0.05, 0.05, 0.1), fog_intensity);
    
    // Add subtle depth-based color shift
    vec3 depth_tint = mix(nebula_color2, accent_color, clamp(center_dist * 0.3, 0.0, 1.0));
    color = mix(color, depth_tint, clamp(0.1 * depth_intensity, 0.0, 0.1));
    
    // Clamp final color to prevent over-brightening
    color = clamp(color, vec3(0.0), vec3(1.0));
    
    COLOR = vec4(color, 1.0);
}
