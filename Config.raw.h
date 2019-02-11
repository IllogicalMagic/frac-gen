#ifndef FRACTAL_CONFIG_H
#define FRACTAL_CONFIG_H

#include "Types.h"

constexpr FloatType CX = <%= c_x %>;
constexpr FloatType CY = <%= c_y %>;

constexpr int XLen = <%= xlen %>;
constexpr int YLen = <%= ylen %>;

constexpr FloatType Scale = <%= scale %>;

constexpr int MaxIters = <%= iters %>;
constexpr int ItersLogBase = 1000;

constexpr FloatType Epsilon = <%= epsilon %>;

#endif
