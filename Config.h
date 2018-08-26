#ifndef FRACTAL_CONFIG_H
#define FRACTAL_CONFIG_H

constexpr int OffsetX = 0;
constexpr int OffsetY = 0;

constexpr double CX = 0;
constexpr double CY = 0;

constexpr int MinX = -500 + OffsetX;
constexpr int MaxX = 500 + OffsetX;
constexpr int XLen = MaxX - MinX;
constexpr int MinY = -500 + OffsetY;
constexpr int MaxY = 500 + OffsetY;
constexpr int YLen = MaxY - MinY;

constexpr double Scale = 20.0;

constexpr int MaxIters = 100;

constexpr int CheckOnEveryNIters = 0x0;

constexpr int GlobalDefaultPrec = 10;

#endif
