shader_type canvas_item;

// Bubble effect shader - makes circles look like 2D bubbles with animated highlights and gradients
// Enhanced with squash & stretch physics support

uniform float bubble_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float highlight_size : hint_range(0.0, 1.0) = 0.3;
uniform float highlight_intensity : hint_range(0.0, 1.0) = 0.9;
uniform vec2 highlight_position = vec2(-0.3, -0.3);
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;

// Squash & stretch parameters
uniform vec2 velocity_direction = vec2(1.0, 0.0); // Normalized direction of movement
uniform float velocity_magnitude : hint_range(0.0, 1.0) = 0.0; // Normalized velocity (0-1)
uniform float stretch_intensity : hint_range(1.0, 3.0) = 1.5; // How much to stretch
uniform float squash_intensity : hint_range(0.3, 0.9) = 0.7; // How much to squash perpendicular
uniform float wobble_intensity : hint_range(0.0, 0.1) = 0.05; // Idle wobble amount

void fragment() {
    vec2 uv = UV;
    vec4 base_color = COLOR;
    float t = TIME * animation_speed;
    
    // Calculate distance from center
    vec2 center = vec2(0.5, 0.5);
    vec2 to_center = uv - center;
    float dist_from_center = length(to_center);
    float normalized_dist = dist_from_center * 2.0; // 0 to 1 from center to edge
    
    // Apply squash & stretch distortion to UV coordinates
    // This makes the shader effects work better with the deformed geometry
    vec2 velocity_dir = normalize(velocity_direction);
    if (length(velocity_dir) < 0.1) {
        velocity_dir = vec2(1.0, 0.0); // Default direction if no movement
    }
    
    // Calculate stretch factor based on velocity
    float stretch_factor = 1.0;
    float squash_factor = 1.0;
    
    if (velocity_magnitude > 0.01) {
        // Moving - apply stretch in direction of movement
        stretch_factor = 1.0 + (stretch_intensity - 1.0) * velocity_magnitude;
        squash_factor = 1.0 - (1.0 - squash_intensity) * velocity_magnitude;
    } else {
        // Idle - apply subtle wobble
        float wobble = sin(t * 2.0) * wobble_intensity;
        stretch_factor = 1.0 + wobble;
        squash_factor = 1.0 - wobble;
    }
    
    // Transform UV coordinates based on movement direction and stretch
    vec2 dir_perp = vec2(-velocity_dir.y, velocity_dir.x); // Perpendicular to movement
    vec2 stretch_axis = velocity_dir;
    vec2 squash_axis = dir_perp;
    
    // Apply deformation to UV space (for shader effects only, actual geometry is handled by scale)
    vec2 deformed_uv = uv;
    vec2 from_center = uv - center;
    float proj_stretch = dot(from_center, stretch_axis);
    float proj_squash = dot(from_center, squash_axis);
    
    // Deform the UV coordinates
    deformed_uv = center + stretch_axis * proj_stretch * stretch_factor + squash_axis * proj_squash * squash_factor;
    
    // Use deformed UV for distance calculations (subtle effect)
    vec2 to_center_deformed = deformed_uv - center;
    float dist_deformed = length(to_center_deformed);
    float normalized_dist_deformed = dist_deformed * 2.0;
    
    // Use original distance for most calculations, but blend with deformed for subtle effect
    float dist_blend = mix(dist_from_center, dist_deformed, 0.3);
    float normalized_dist_blend = dist_blend * 2.0;
    
    // Create radial gradient - darker at edges, lighter in center
    float radial_gradient = 1.0 - normalized_dist_blend * 0.4;
    
    // Create vertical gradient - lighter at top (like light from above)
    // Adjust gradient direction based on movement for more dynamic look
    float vertical_gradient = 1.0 - (deformed_uv.y - 0.5) * 0.6;
    
    // Combine gradients for bubble effect
    float bubble_gradient = mix(radial_gradient, vertical_gradient, 0.5);
    bubble_gradient = mix(0.3, 1.0, bubble_gradient); // Minimum brightness
    
    // Animated highlight spot (like light reflection on bubble)
    // Position highlight based on movement direction for more realistic effect
    vec2 highlight_offset = highlight_position;
    if (velocity_magnitude > 0.1) {
        // When moving, position highlight opposite to movement (like light from behind)
        highlight_offset = -velocity_dir * 0.3 + vec2(sin(t * 0.3) * 0.05, cos(t * 0.2) * 0.05);
    } else {
        // When idle, use default animated position
        highlight_offset = highlight_position + vec2(sin(t * 0.3) * 0.05, cos(t * 0.2) * 0.05);
    }
    vec2 highlight_pos = center + highlight_offset * 0.2;
    float highlight_dist = length(deformed_uv - highlight_pos);
    
    // Animated highlight size - pulsing effect, more intense when moving fast
    float highlight_pulse = sin(t * 2.0) * 0.05;
    float speed_boost = velocity_magnitude * 0.1; // Slightly larger highlight when moving fast
    float animated_highlight_size = highlight_size + highlight_pulse + speed_boost;
    float highlight = smoothstep(animated_highlight_size, 0.0, highlight_dist);
    highlight *= highlight_intensity;
    highlight *= smoothstep(1.0, 0.5, normalized_dist_blend); // Only show on visible part
    
    // Animated rim light effect (edge glow) - more intense when moving
    float rim_pulse = 0.3 + sin(t * 1.5) * 0.1;
    float rim_boost = velocity_magnitude * 0.2; // Brighter rim when moving
    float rim = smoothstep(0.9, 1.0, normalized_dist_blend) * (rim_pulse + rim_boost);
    
    // Animated shimmer effect - subtle wave across the bubble
    // Make shimmer follow movement direction
    float shimmer_dir = dot(deformed_uv - center, velocity_dir);
    float shimmer = sin(shimmer_dir * 5.0 + t * 2.0) * 0.05 + 1.0;
    shimmer = smoothstep(0.7, 1.0, normalized_dist_blend) * shimmer; // Only on outer area
    
    // Combine all effects
    vec3 final_color = base_color.rgb;
    final_color *= bubble_gradient * bubble_intensity * shimmer;
    final_color += vec3(1.0) * highlight; // White highlight
    final_color += base_color.rgb * rim; // Rim glow
    
    // Add subtle transparency at edges for bubble effect
    float edge_alpha = smoothstep(1.0, 0.85, normalized_dist_blend);
    float final_alpha = base_color.a * edge_alpha;
    
    COLOR = vec4(final_color, final_alpha);
}

