#version 460 core

// The 27 pool: a slowly drifting aqua and deep-blue gradient with caustic
// light playing over the floor. Drawn in one pass, so the whole background
// costs a single full-screen draw a frame.

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;

// Where the pool is in its slow loop, 0 to 1. Every motion below turns a
// whole number of times per loop, so the water never jumps when it wraps.
uniform float uPhase;

out vec4 fragColor;

const float TAU = 6.28318530718;

const vec3 deep = vec3(0.0235, 0.0941, 0.2000); // 0xFF061833
const vec3 teal = vec3(0.0431, 0.3098, 0.4235); // 0xFF0B4F6C
const vec3 aqua = vec3(0.1804, 0.7686, 0.7765); // 0xFF2EC4C6
const vec3 navy = vec3(0.0431, 0.2275, 0.3608); // 0xFF0B3A5C
const vec3 foam = vec3(0.7490, 0.9647, 0.9490); // 0xFFBFF6F2

// Deep at both ends, shimmering aqua in the middle, its axis swinging
// slowly from side to side.
vec3 water(vec2 p, float a) {
  float shimmer = 0.5 + 0.5 * sin(a);
  vec2 begin = vec2(0.5 + cos(a) * 0.4, 0.0) * uSize;
  vec2 end = vec2(0.5 - cos(a) * 0.4, 1.0) * uSize;
  vec2 axis = end - begin;
  float t = clamp(dot(p - begin, axis) / dot(axis, axis), 0.0, 1.0);
  vec3 c1 = mix(teal, aqua, shimmer * 0.6);
  vec3 c2 = mix(aqua, navy, shimmer);
  if (t < 0.4) return mix(deep, c1, t / 0.4);
  if (t < 0.7) return mix(c1, c2, (t - 0.4) / 0.3);
  return mix(c2, deep, (t - 0.7) / 0.3);
}

// Light focused by the rippling surface into a wobbling net on the floor:
// a lattice of diamonds (where sin x + sin y is zero), warped twice so the
// cells bulge and pinch as the surface moves. [drift] slides the lattice
// itself, after the warp, so a drift of TAU is one whole cell.
float net(vec2 q, float a, vec2 drift) {
  q += 0.45 * vec2(sin(q.y * 0.9 + a), sin(q.x * 1.1 - 2.0 * a));
  q += 0.25 * vec2(sin(q.y * 1.7 - 3.0 * a), sin(q.x * 1.3 + a));
  q += drift;
  float f = abs(sin(q.x) + sin(q.y));
  return 1.0 - smoothstep(0.0, 0.3, f);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float a = uPhase * TAU;
  // Three cells across the screen, whatever its resolution.
  vec2 q = p / uSize.x * TAU * 3.0;
  float light = net(q, a, vec2(a, 0.0)) * 0.6 +
      net(mat2(0.8, -0.6, 0.6, 0.8) * q * 1.7, -a, vec2(0.0, 2.0 * a)) * 0.4;
  vec3 colour = water(p, a) + foam * pow(light, 1.5) * 0.16;
  fragColor = vec4(colour, 1.0);
}
