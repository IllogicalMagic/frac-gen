#ifndef FRACGEN_COLOR_H_DEFINED__
#define FRACGEN_COLOR_H_DEFINED__

#include "Config.h"
#include "Norm.h"
#include "Types.h"

#include <tuple>
#include <utility>
#include <cmath>

class PointColor {
  ValType CircleCoordinate;
  int Iters;
  static constexpr double pi23 = 2.094395102;
public:
  using RGBColor = std::tuple<double, double, double>;

  PointColor(ValType V, int It):
    CircleCoordinate(V), Iters(It) {}

  PointColor(bool):
    CircleCoordinate(0.0, 0.0), Iters(0) {}

  RGBColor getRGB() const {
    RGBColor C;
    FloatType Arg = std::arg(CircleCoordinate);
    FloatType R = UsedNorm(CircleCoordinate);
    // Red - blue, blue - green, green - red
    if (std::cos(Arg) >= 0.5) {
      double Norm = Arg / pi23 + 1.5;
      std::get<0>(C) = Norm;
      std::get<2>(C) = 1.0 - Norm;
      // Add green color based on how far point is from center.
      std::get<1>(C) = (Epsilon - R) / Epsilon;
    } else if (Arg <= 0) {
      double Norm = Arg / pi23 + 0.5;
      std::get<2>(C) = Norm;
      std::get<1>(C) = 1.0 - Norm;
      std::get<0>(C) = (Epsilon - R) / Epsilon;
    } else {
      double Norm = Arg / pi23 - 0.5;
      std::get<1>(C) = Norm;
      std::get<0>(C) = 1.0 - Norm;
      std::get<2>(C) = (Epsilon - R) / Epsilon;
    }
    double Intensity = 1.0 - (std::log(static_cast<double>(Iters)) /
                              std::log(static_cast<double>(ItersLogBase)));
    std::get<0>(C) *= Intensity;
    std::get<1>(C) *= Intensity;
    std::get<2>(C) *= Intensity;
    return C;
  }
};

using PtColor = std::pair<bool, PointColor>;

#endif
