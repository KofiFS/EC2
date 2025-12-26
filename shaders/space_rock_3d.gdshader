shader_type canvas_item;

// 3D-style shader for SpaceRock actors with lighting and depth

uniform float light_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float rim_power : hint_range(0.0, 5.0) = 2.0;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.6;
uniform vec3 light_direction : hint_range(-1.0, 1.0) = vec3(0.5, -0.7, 0.5);
uniform vec3 rim_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    vec4 base_color = COLOR;
    
    // Calculate distance from center for radial effects
    vec2 center = vec2(0.5, 0.5);
    vec2 to_center = uv - center;
    float dist_from_center = length(to_center);
    float normalized_dist = dist_from_center * 2.0; // 0 to 1 from center to edge
    
    // Normalize light direction
    vec3 light_dir = normalize(light_direction);
    
    // Calculate 3D lighting based on position
    // Create a normal pointing outward from center
    vec2 normal_2d = normalize(to_center);
    vec3 normal = vec3(normal_2d, sqrt(1.0 - dot(normal_2d, normal_2d)));
    
    // Dot product for lighting
    float light_dot = dot(normal, light_dir);
    light_dot = clamp(light_dot, -1.0, 1.0);
    
    // Apply lighting - bright on top, dark on bottom
    float lighting = mix(0.3, 1.0, (light_dot + 1.0) * 0.5);
    lighting = mix(lighting, 1.0, 0.2); // Minimum brightness
    
    // Add radial gradient for depth
    float radial_gradient = 1.0 - normalized_dist * 0.3;
    
    // Rim lighting effect (edges glow)
    float rim = pow(1.0 - abs(light_dot), rim_power) * rim_intensity;
    rim *= smoothstep(0.7, 1.0, normalized_dist); // Only on edges
    
    // Shadow on bottom side
    float shadow = mix(1.0, 1.0 - shadow_intensity, max(0.0, -light_dot));
    
    // Combine all effects
    vec3 final_color = base_color.rgb;
    final_color *= lighting * radial_gradient * shadow;
    final_color += rim_color * rim;
    
    // Enhance saturation and contrast for 3D pop
    vec3 final = mix(vec3(dot(final_color, vec3(0.299, 0.587, 0.114))), final_color, 1.3);
    final = mix(final, final_color, 0.7); // Blend back to original
    
    // Apply light intensity
    final *= light_intensity;
    
    COLOR = vec4(final, base_color.a);
}

