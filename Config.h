#ifndef FRACTAL_CONFIG_H
#define FRACTAL_CONFIG_H

#include "Types.h"

constexpr int OffsetX = 0;
constexpr int OffsetY = 0;

constexpr FloatType CX = 0;
constexpr FloatType CY = 0;

constexpr int MinX = -500 + OffsetX;
constexpr int MaxX = 500 + OffsetX;
constexpr int XLen = MaxX - MinX;
constexpr int MinY = -500 + OffsetY;
constexpr int MaxY = 500 + OffsetY;
constexpr int YLen = MaxY - MinY;

constexpr FloatType Scale = 20.0;

constexpr int MaxIters = 100;

constexpr FloatType Epsilon = 0.05;

#endif
