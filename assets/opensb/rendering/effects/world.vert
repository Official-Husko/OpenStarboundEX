#version 140

uniform vec2 textureSize0;
uniform vec2 textureSize1;
uniform vec2 textureSize2;
uniform vec2 textureSize3;
uniform vec2 screenSize;
uniform mat3 vertexTransform;
uniform bool vertexRounding;
uniform vec2 lightMapSize;
uniform vec2 lightMapScale;
uniform vec2 lightMapOffset;

in vec2 vertexPosition;
in vec2 vertexTextureCoordinate;
in vec4 vertexColor;
in int vertexData;

out vec2 fragmentTextureCoordinate;
flat out int fragmentTextureIndex;
out vec4 fragmentColor;
out float fragmentLightMapMultiplier;
out vec2 fragmentLightMapCoordinate;
out vec2 fragmentFlow;

void main() {
  vec2 screenPosition = (vertexTransform * vec3(vertexPosition, 1.0)).xy;

  if (vertexRounding) {
    if (((vertexData >> 3) & 0x1) == 1)
      screenPosition.x = round(screenPosition.x);
    if (((vertexData >> 4) & 0x1) == 1)
      screenPosition.y = round(screenPosition.y);
  }
  
  fragmentLightMapMultiplier = float((vertexData >> 2) & 0x1);
  int vertexTextureIndex = vertexData & 0x3;
  fragmentLightMapCoordinate = (screenPosition - lightMapOffset) / lightMapScale;
  if (vertexTextureIndex == 3)
    fragmentTextureCoordinate = vertexTextureCoordinate / textureSize3;
  else if (vertexTextureIndex == 2)
    fragmentTextureCoordinate = vertexTextureCoordinate / textureSize2;
  else if (vertexTextureIndex == 1)
    fragmentTextureCoordinate = vertexTextureCoordinate / textureSize1;
  else
    fragmentTextureCoordinate = vertexTextureCoordinate / textureSize0;

  fragmentTextureIndex = vertexTextureIndex;
  fragmentColor = vertexColor;

  // Bits 5-12 hold a quantized flow angle (0-255 -> 0..2pi), bits 13-18 hold
  // quantized flow strength (0-63 -> 0..1). Both are zero for anything that
  // isn't a flowing liquid tile, which collapses fragmentFlow to (0,0).
  float flowAngle = float((vertexData >> 5) & 0xFF) / 255.0 * 6.28318530718 - 3.14159265359;
  float flowSpeed = float((vertexData >> 13) & 0x3F) / 63.0;
  fragmentFlow = vec2(cos(flowAngle), sin(flowAngle)) * flowSpeed;

  gl_Position = vec4(screenPosition / screenSize * 2.0 - 1.0, 0.0, 1.0);
}
