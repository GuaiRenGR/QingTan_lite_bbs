#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uLevel;
uniform float uBeat;
uniform float uDynamic;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform vec4 uColor4;

out vec4 fragColor;

float gradientNoise(vec2 uv) {
  return fract(52.9829189 * fract(dot(uv, vec2(0.06711056, 0.00583715))));
}

vec2 animatedPoint(vec2 point, float pointOffset, float beatEase) {
  float x = point.x + sin(uTime + point.y) * pointOffset;
  float y = point.y + cos(uTime + x) * pointOffset;
  vec2 push = vec2(x, y) - vec2(0.5) + vec2(0.0001);
  float pushLength = length(push);
  if (pushLength > 0.0) {
    vec2 shifted = vec2(x, y) + push * (beatEase * 0.118 / pushLength);
    x = shifted.x;
    y = shifted.y;
  }
  return vec2(x, y);
}

float fieldWeight(vec2 uv, vec2 point, float radius) {
  vec2 delta = uv - point;
  float radiusSq = max(radius * radius, 0.0001);
  float weight = 1.0 / (1.0 + dot(delta, delta) / radiusSq * 9.3);
  return weight * weight;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  float levelEase = smoothstep(0.04, 0.82, uLevel);
  float beatEase = smoothstep(0.03, 0.62, uBeat);
  float motionEase = clamp(0.42 * levelEase + 0.82 * beatEase, 0.0, 1.0);
  float zoom = 1.0 + 0.024 * levelEase + 0.105 * beatEase;
  uv = (uv - vec2(0.5)) / zoom + vec2(0.5);

  vec2 globalMotion = motionEase * 0.006 * vec2(
    sin(uTime * 1.9),
    cos(uTime * 1.6)
  );
  uv -= globalMotion;

  float pointOffset = 0.10 * uDynamic +
    0.022 * levelEase +
    0.108 * beatEase;
  float radiusMultiplier = 1.0 + 0.045 * levelEase + 0.220 * beatEase;

  vec2 p0 = animatedPoint(vec2(0.52, 0.46), pointOffset, beatEase);
  vec2 p1 = animatedPoint(vec2(0.14, 0.32), pointOffset, beatEase);
  vec2 p2 = animatedPoint(vec2(0.92, 0.30), pointOffset, beatEase);
  vec2 p3 = animatedPoint(vec2(0.26, 0.88), pointOffset, beatEase);
  vec2 p4 = animatedPoint(vec2(0.84, 0.86), pointOffset, beatEase);

  float w0 = fieldWeight(uv, p0, 0.92 * radiusMultiplier);
  float w1 = fieldWeight(uv, p1, 0.74 * radiusMultiplier);
  float w2 = fieldWeight(uv, p2, 0.76 * radiusMultiplier);
  float w3 = fieldWeight(uv, p3, 0.80 * radiusMultiplier);
  float w4 = fieldWeight(uv, p4, 0.84 * radiusMultiplier);
  float weightSum = max(w0 + w1 + w2 + w3 + w4, 0.0001);

  vec3 color = (
    uColor0.rgb * w0 +
    uColor1.rgb * w1 +
    uColor2.rgb * w2 +
    uColor3.rgb * w3 +
    uColor4.rgb * w4
  ) / weightSum;
  float pulse = clamp(0.68 * levelEase + 0.32 * beatEase, 0.0, 1.0);
  color = clamp((color - 0.5) * (1.08 + 0.05 * pulse) + 0.5, 0.0, 1.0);
  color += (gradientNoise(fragCoord) - 0.5) * (4.0 / 255.0);
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
