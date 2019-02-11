#include "Color.h"
#include "Config.h"
#include "Norm.h"
#include "Methods.hpp"
#include "TypeHelpers.hpp"
#include "Types.h"

#include <iostream>
#include <utility>
#include <vector>

#include <cassert>
#include <cmath>
#include <cstdlib>

auto getFractal() -> std::vector<PtColor> {
  std::vector<PtColor> ColorIdxs;
  ColorIdxs.reserve(XLen * YLen);

  struct Func {
    ValType operator()(ValType Pt) {
      static auto Fn = [](ValType Pt) -> ValType {
        <%= expr %>
      };
      return Fn(Pt);
    }

    static ValType diff(ValType Pt) {
      static auto FnDiff = [](ValType Pt) -> ValType {
        <%= expr_diff %>
      };
      return FnDiff(Pt);
    }
  };

  static auto ColorFn = [](ValType Pt, int Iters) {
    return PointColor(Pt, Iters);
  };

  using Method = CalcNext<%= method %>;

  for (int i = -XLen / 2; i < XLen / 2; ++i) {
    FloatType X = static_cast<FloatType>(i) / Scale + CX;
    for (int j = -YLen / 2; j < YLen / 2; ++j) {
      FloatType Y = static_cast<FloatType>(j) / Scale + CY;
      ColorIdxs.emplace_back(getPointIndexN<Method>(Func(), UsedNorm, ColorFn, ValType(X, Y)));
    }
    std::cerr << '.';
  }
  std::cerr << '\n';

  return ColorIdxs;
}
