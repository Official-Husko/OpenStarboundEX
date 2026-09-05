#version 140

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform sampler2D texture3;
uniform bool lightMapEnabled;
uniform vec2 lightMapSize;
uniform sampler2D lightMap;
uniform float lightMapMultiplier;
uniform float time;

in vec2 fragmentTextureCoordinate;
flat in int fragmentTextureIndex;
in vec4 fragmentColor;
in float fragmentLightMapMultiplier;
in vec2 fragmentLightMapCoordinate;
flat in float fragmentLiquidScrollSpeed;

out vec4 outColor;

vec4 cubic(float v) {
  vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
  vec4 s = n * n * n;
  float x = s.x;
  float y = s.y - 4.0 * s.x;
  float z = s.z - 4.0 * s.y + 6.0 * s.x;
  float w = 6.0 - x - y - z;
  return vec4(x, y, z, w);
}

vec4 bicubicSample(sampler2D tex, vec2 texcoord, vec2 texscale) {
  texcoord = texcoord - vec2(0.5, 0.5);

  float fx = fract(texcoord.x);
  float fy = fract(texcoord.y);
  texcoord.x -= fx;
  texcoord.y -= fy;

  vec4 xcubic = cubic(fx);
  vec4 ycubic = cubic(fy);

  vec4 c = vec4(texcoord.x - 0.5, texcoord.x + 1.5, texcoord.y - 0.5, texcoord.y + 1.5);
  vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
  vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

  vec4 sample0 = texture(tex, vec2(offset.x, offset.z) * texscale);
  vec4 sample1 = texture(tex, vec2(offset.y, offset.z) * texscale);
  vec4 sample2 = texture(tex, vec2(offset.x, offset.w) * texscale);
  vec4 sample3 = texture(tex, vec2(offset.y, offset.w) * texscale);

  float sx = s.x / (s.x + s.y);
  float sy = s.z / (s.z + s.w);

  return mix(
    mix(sample3, sample2, sx),
    mix(sample1, sample0, sx), sy);
}

vec3 sampleLight(vec2 coord, vec2 scale) {
  //soften super bright lights a little
  const float threshold = 1.0;
  vec3 rgb = bicubicSample(lightMap, coord, scale).rgb;
  vec3 lower = min(rgb, threshold);
  vec3 upper = max(rgb, threshold) - threshold;
  return lower + (upper / (vec3(1.) + upper));
}

void main() {
  vec2 sampleCoordinate = fragmentTextureCoordinate;

  if (fragmentLiquidScrollSpeed > 0.0) {
    // Water wave/shine: liquid textures (see e.g. /liquids/watertex.png)
    // are soft repeating light/dark gradient bands, not detailed water
    // photos - they're clearly meant to be animated by scrolling, which is
    // exactly what the long-unused textureMovementFactor field is for. This
    // is the SAME value (never a per-tile computed one) for every tile of a
    // given liquid, so every tile scrolls in lockstep with its neighbors -
    // no seams, no patchwork.
    //
    // A pure linear scroll alone looks like a conveyor belt - too even and
    // predictable. Real displacement instead: sample-point offset built
    // from several sine terms at different, deliberately non-matching
    // frequencies and speeds in both axes, so no two points on the surface
    // are ever moving the exact same way at the exact same time. Still
    // fully seamless (every input is fragmentTextureCoordinate/time, never
    // a per-tile value).
    vec2 p = fragmentTextureCoordinate;
    float speed = fragmentLiquidScrollSpeed * 0.045;

    float dx = sin(p.y * 0.6 + time * speed * 1.3) * 0.30
             + sin(p.y * 1.7 - time * speed * 0.6 + 2.0) * 0.15
             + time * speed * 0.5;
    float dy = sin(p.x * 0.4 - time * speed * 0.9 + 1.1) * 0.18
             + sin(p.x * 1.1 + time * speed * 1.7 + 3.0) * 0.09;

    sampleCoordinate.x += dx;
    sampleCoordinate.y += dy;
  }

  vec4 texColor;
  if (fragmentTextureIndex == 3)
    texColor = texture(texture3, sampleCoordinate);
  else if (fragmentTextureIndex == 2)
    texColor = texture(texture2, sampleCoordinate);
  else if (fragmentTextureIndex == 1)
    texColor = texture(texture1, sampleCoordinate);
  else
    texColor = texture(texture0, sampleCoordinate);

  if (texColor.a <= 0.0)
    discard;

  vec4 finalColor = texColor * fragmentColor;

  float finalLightMapMultiplier = fragmentLightMapMultiplier * lightMapMultiplier;
  if (texColor.a == 0.99607843137)
    finalColor.a = fragmentColor.a;
  else if (lightMapEnabled && finalLightMapMultiplier > 0.0)
    finalColor.rgb *= sampleLight(fragmentLightMapCoordinate, 1.0 / lightMapSize) * finalLightMapMultiplier;
  outColor = finalColor;
}
