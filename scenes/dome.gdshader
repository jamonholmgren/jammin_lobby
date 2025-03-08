// Ghost swirl shader for debugging collision shapes in the Godot editor.
// By Jamon Holmgren (jammin.games)

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_front, diffuse_lambert, specular_schlick_ggx;

uniform vec4 swirl_color : source_color = vec4(0.3, 0.7, 1.0, 0.3);
uniform float swirl_speed : hint_range(0.1, 2.0) = 1.0;
uniform float swirl_scale : hint_range(1.0, 10.0) = 5.0;

void fragment() {
    // Create swirling UV coordinates
    vec2 centered_uv = UV * 2.0 - 1.0;
    float angle = atan(centered_uv.y, centered_uv.x);
    float radius = length(centered_uv);
    
    // Create the swirl effect with rotation
    float swirl = sin(radius * swirl_scale + angle * 2.0 - TIME * swirl_speed) * 0.5 + 0.5;
    
    // Mix the colors with stronger effect
    vec4 final_color = swirl_color;
    final_color.a = swirl * (1.0 - radius * 0.7);
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a * 0.8;
    EMISSION = final_color.rgb * swirl;
    METALLIC = 0.0;
    ROUGHNESS = 0.2;
} 
