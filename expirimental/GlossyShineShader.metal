#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 glossyShine(
    float2 position,
    half4 color,
    float2 size,
    float2 tilt,
    float intensity,
    float shineSize
) {
    // Normalize position to 0-1 range
    float2 uv = position / size;

    // Calculate light direction based on device tilt
    // This creates a directional shine perpendicular to the tilt
    float2 lightDir = normalize(float2(tilt.x, tilt.y));

    // Create perpendicular direction (rotated 90 degrees) for the stripe
    float2 stripeDir = float2(-lightDir.y, lightDir.x);

    // Distance from center
    float2 centerDelta = uv - float2(0.5, 0.5);

    // Project position onto the stripe direction to get distance from stripe
    float stripeDistance = abs(dot(centerDelta, stripeDir));

    // Create soft, diffuse stripe that runs perpendicular to the light direction
    // This matches the orientation of the stroke gradient
    // Made wider and more diffuse
    float shine = 1.0 - smoothstep(0.0, shineSize * 0.7, stripeDistance);

    // Apply gentle falloff along the stripe length as well
    // Made longer for more coverage
    float lengthDistance = abs(dot(centerDelta, lightDir));
    float lengthFade = 1.0 - smoothstep(0.0, shineSize * 2.0, lengthDistance);

    // Combine perpendicular stripe with length fade
    shine *= lengthFade;

    // Apply very gentle curve for soft, natural falloff
    // Made even softer
    shine = pow(shine, 0.6);

    // Apply intensity
    shine *= intensity;

    // Add shine to original color
    half4 shineColor = half4(1.0, 1.0, 1.0, shine);

    // Blend shine with original color using screen blend mode for realistic glossy effect
    half3 blended = half3(1.0) - (half3(1.0) - color.rgb) * (half3(1.0) - shineColor.rgb * shineColor.a);

    return half4(blended, color.a);
}
