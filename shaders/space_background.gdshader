shader_type canvas_item;

// Space background shader with twinkling stars, nebulae, and parallax scrolling

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float nebula_intensity : hint_range(0.0, 1.0) = 0.6;
uniform bool enable_scroll = true;
uniform bool enable_twinkle = true;
uniform bool enable_nebula_drift = true;

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

// Fractal brownian motion for nebulae
float fbm(vec2 p, float t) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 5; i++) {
        vec2 drift = enable_nebula_drift ? vec2(t * 0.02, t * 0.01) * float(i + 1) * 0.3 : vec2(0.0);
        value += amplitude * noise(p * frequency + drift);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Star layer
float stars(vec2 uv, float scale, float t, float layer_speed) {
    vec2 scaled_uv = uv * scale;
    
    // Parallax scroll
    if (enable_scroll) {
        scaled_uv.y += t * layer_speed;
    }
    
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
        if (enable_twinkle) {
            float twinkle_speed = hash(grid * 2.0) * 3.0 + 1.0;
            float twinkle_offset = hash(grid * 3.0) * 6.28;
            twinkle = 0.5 + 0.5 * sin(t * twinkle_speed + twinkle_offset);
        }
        
        float size = 0.02 + hash(grid * 4.0) * 0.03;
        star = smoothstep(size, 0.0, dist) * twinkle;
    }
    
    return star;
}

// Bright star with glow
float bright_star(vec2 uv, float scale, float t) {
    vec2 scaled_uv = uv * scale;
    
    if (enable_scroll) {
        scaled_uv.y += t * 0.05;
    }
    
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
        
        // Core
        star = smoothstep(0.05, 0.0, dist) * pulse;
        
        // Glow
        star += smoothstep(0.2, 0.0, dist) * 0.3 * pulse;
        
        // Cross flare
        float flare_x = smoothstep(0.15, 0.0, abs(grid_uv.y - star_pos.y)) * smoothstep(0.3, 0.0, abs(grid_uv.x - star_pos.x));
        float flare_y = smoothstep(0.15, 0.0, abs(grid_uv.x - star_pos.x)) * smoothstep(0.3, 0.0, abs(grid_uv.y - star_pos.y));
        star += (flare_x + flare_y) * 0.3 * pulse;
    }
    
    return star;
}

void fragment() {
    float t = TIME * time_scale;
    vec2 uv = UV;
    
    // Base dark background
    vec3 color = vec3(0.0, 0.0, 0.02);
    
    // Nebulae layers
    float nebula1 = fbm(uv * 2.0 + vec2(0.0, 0.0), t) * nebula_intensity;
    float nebula2 = fbm(uv * 3.0 + vec2(5.0, 3.0), t * 0.7) * nebula_intensity;
    float nebula3 = fbm(uv * 1.5 + vec2(10.0, 7.0), t * 0.5) * nebula_intensity;
    
    // Apply nebula colors
    color += nebula_color1 * nebula1 * 0.8;
    color += nebula_color2 * nebula2 * 0.6;
    color += mix(nebula_color1, nebula_color2, 0.5) * nebula3 * 0.4;
    
    // Star layers with different parallax speeds
    float stars1 = stars(uv, 50.0, t, 0.02);  // Distant layer
    float stars2 = stars(uv, 30.0, t, 0.05);  // Middle layer
    float stars3 = stars(uv, 15.0, t, 0.08);  // Close layer
    
    // Combine star layers
    float all_stars = stars1 * 0.5 + stars2 * 0.7 + stars3;
    color += star_color * all_stars;
    
    // Bright stars with glow
    float bright = bright_star(uv, 8.0, t);
    color += accent_color * bright * 1.5;
    color += vec3(1.0) * bright * 0.5;  // White core
    
    COLOR = vec4(color, 1.0);
}

