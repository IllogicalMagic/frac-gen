#ifndef FRACGEN_ITER_METHODS_DEFINED__
#define FRACGEN_ITER_METHODS_DEFINED__

#include "Config.h"
#include "Support.hpp"
#include "TypeHelpers.hpp"
#include "Types.h"

#include <random>
#include <type_traits>
#include <utility>

#include <cmath>

// Erroneus steffenson's method. Helper for bootstrap stages.
template<typename FnTy>
static ValType calcNextSteffensonL(CopyOrRefT<FnTy> Fn, ValType Pt) {
  ValType Tmp = Fn(Pt);
  ValType Tmp2 = Fn(Tmp);
  return Pt - (Tmp * Tmp) / (Tmp2 - Tmp);
}

template<typename FnT, typename NormT, IdxType Degree = 7>
struct CalcNextSidi {
  static constexpr IdxType UsedPts = Degree + 1;

  using FnTy = CopyOrRefT<FnT>;
  using NormTy = CopyOrRefT<NormT>;

private:
  static constexpr IdxType PNum = UsedPts;
  static constexpr IdxType StorageSize = nextPow2<IdxType, PNum>();
  static constexpr IdxType Mask = StorageSize - 1;
  static_assert((Mask & (Mask + 1)) == 0, "Mask should be power of 2 minus one!");

  // Differences window.
  // Should it be separated into another class???
  // DW has following structure (example for 4 points):
  // f0    f1    f2    f3
  //       f10   f21   f32
  //            f210  f321
  //                  f3210
  // To add next point just forget diagonal elements
  // and update next column using previous elements:
  //  f4    f1    f2    f3
  //  f43         f21   f32
  // f432              f321
  // f4321
  // Guaranteed to be fast and correct.
  ValType DW[PNum][StorageSize];
  IdxType DWPos = 0;
  ValType Diffs[Degree];

  IdxType getDWIdx(IdxType Idx) {
    // TODO: fix indices and add an assertion.
    return (DWPos + Idx) & Mask;
  }

  void advanceDWIdx() {
    DWPos = getDWIdx(1);
  }

public:
  template<typename PtCont>
  CalcNextSidi(FnTy Fn, const PtCont &Pts) {
    for (IdxType i = 0; i < PNum; ++i)
      DW[0][i] = Fn(Pts[i]);

    for (IdxType i = 1; i < PNum; ++i)
      for (IdxType j = i; j < PNum; ++j) {
        DW[i][j] = (DW[i - 1][j] - DW[i - 1][j - 1]) / (Pts[j] - Pts[j - i]);
      }

    for (IdxType i = 0; i < Degree; ++i)
      Diffs[i] = Pts[Degree] - Pts[i];
  }

  template<typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    IdxType Cur = getDWIdx(Degree);

    // Calculation of polynomial derivative at given point.
    // The following was noticed:
    // Poly in Newton's form can be rewritten as:
    // f0 + (x - x0)(f10 + (x - x1)(f210 + (x - x2)(f321 + ...))).
    // It has repetitive pattern so it can be recursively calculated
    // starting from innermost expression.
    // Example for 4 points:
    // [f10 + (x - x1)(f210 + (x - x2)f3210)] +
    //  f10(x - x0)([f210 + (x - x2)f3210] +
    //               f210(x - x1)[f3210]).
    ValType Last = DW[Degree][Cur];
    ValType Drv = Last;
    for (IdxType j = Degree - 1; j > 0; --j) {
      Drv *= Diffs[j - 1] * DW[j][getDWIdx(j)];
      Last = DW[j][getDWIdx(j)] + Diffs[j] * Last;
      Drv += Last;
    }

    return Pts[Degree] + DW[0][Cur] / Drv;
  }

  template<typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {
    advanceDWIdx();

    for (IdxType i = 0; i < Degree; ++i)
      Diffs[i] = Pts[Degree] - Pts[i];

    // Renew table.
    // Just update one last column.
    DW[0][getDWIdx(Degree)] = Fn(Pts[Degree]);
    for (IdxType j = 1; j < PNum; ++j) {
      DW[j][getDWIdx(Degree)] =
        (DW[j - 1][getDWIdx(Degree)] - DW[j - 1][getDWIdx(Degree - j)]) /
        (Diffs[Degree - j]);
    }

  }
};

template<typename FnT, typename NormT>
struct CalcNextMuller {
  static constexpr IdxType UsedPts = 3;

  using FnTy = CopyOrRefT<FnT>;
  using NormTy = CopyOrRefT<NormT>;

  template<typename PtCont>
  CalcNextMuller(FnTy Fn, const PtCont &Pts) {}

  template<typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    ValType P0 = Pts[0];
    ValType P1 = Pts[1];
    ValType P2 = Pts[2];

    ValType F0 = Fn(P0);
    ValType F1 = Fn(P1);
    ValType F2 = Fn(P2);

    ValType F21 = (F2 - F1) / (P2 - P1);
    ValType F20 = (F2 - F0) / (P2 - P0);
    ValType F10 = (F1 - F0) / (P1 - P0);
    ValType F210 = (F21 - F10) / (P2 - P0);
  
    ValType W = F21 + F20 + F10;
    ValType Den = std::sqrt(W * W - 4.0 * F2 * F210);
    Den = std::fmax(Norm(W - Den), Norm(W + Den));
    return P2 - 2.0 * F2 / Den;
  }

  template<typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {}
};

template<typename Method, typename ColorFnTy>
static PtColor
getPointIndexN(typename Method::FnTy Fn,
               typename Method::NormTy Norm,
               CopyOrRefT<ColorFnTy> ColorFn,
               ValType Init) {
  constexpr IdxType UsedPts = Method::UsedPts;

  CircularBuffer<ValType, UsedPts> Pts([Fn, Pt = Init]() mutable -> ValType {
      ValType Old = Pt;
      Pt = calcNextSteffensonL<decltype(Fn)>(Fn, Pt);
      return Old;
    });

  Method Mth(Fn, Pts);

  for (int i = 0; i < MaxIters; ++i) {
    ValType Next = Mth.get(Fn, Norm, Pts);
    if (std::isnan(Next.real()) || std::isnan(Next.imag()))
      break;

    if (Norm(Fn(Next)) < Epsilon)
      return {true, ColorFn(Next)};

    Pts.push_back(Next);

    Mth.update(Fn, Pts);
  }

  return {false, 0.0};
}

#endif
