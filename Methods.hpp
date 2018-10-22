#ifndef FRACGEN_ITER_METHODS_DEFINED__
#define FRACGEN_ITER_METHODS_DEFINED__

#include "Config.h"
#include "TypeHelpers.hpp"
#include "Types.h"

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

template<typename T, T Num, typename = std::enable_if_t<std::is_integral_v<T>, void>>
constexpr T nextPow2() {
  static_assert(!(Num & (1 << (sizeof(Num) * 8 - 1))), "Too big number");
  if (Num == 0)
    return 1;
  T Res = 1;
  while ((Res <<= 1) < Num);
  return Res;
}

template<IdxType Mask>
struct IdxGetT {
private:
  IdxType Cur = 0;
public:
  IdxGetT() = default;
  IdxType operator()(IdxType Idx) { return (Cur + Idx) & Mask; }
  void operator++() { Cur = (Cur + 1) & Mask; }
};

template<typename FnT, typename NormT, IdxType Degree = 7>
struct CalcNextSidi {
  static constexpr IdxType UsedPts = Degree + 1;
  static constexpr IdxType StorageSize = nextPow2<IdxType, UsedPts>();

  using IdxGetTy = IdxGetT<StorageSize - 1>;
  using FnTy = CopyOrRefT<FnT>;
  using NormTy = CopyOrRefT<NormT>;

private:
  static constexpr IdxType PNum = UsedPts;
  // Differences window.
  ValType DW[PNum][StorageSize];
  ValType Diffs[Degree];

public:
  CalcNextSidi(FnTy Fn, ValType Pts[]) {
    for (IdxType i = 0; i < PNum; ++i)
      DW[0][i] = Fn(Pts[i]);

    for (IdxType i = 1; i < PNum; ++i)
      for (IdxType j = i; j < PNum; ++j) {
        DW[i][j] = (DW[i - 1][j] - DW[i - 1][j - 1]) / (Pts[j] - Pts[j - i]);
      }

    for (IdxType i = 0; i < Degree; ++i)
      Diffs[i] = Pts[Degree] - Pts[i];
  }

  ValType get(FnTy Fn, NormTy Norm,
              ValType Pts[], IdxGetTy IdxGet) {
    IdxType Cur = IdxGet(Degree);

    ValType Last = DW[Degree][Cur];
    ValType Drv = Last;
    for (IdxType j = Degree - 1; j > 0; --j) {
      Drv *= Diffs[j - 1];
      Last = DW[j][IdxGet(j)] + Last * Pts[j]; // Probably an error. TODO: check.
      Drv += Last;
    }

    return Pts[Cur] + DW[0][Cur] / Drv;
  }

  void update(FnTy Fn, ValType Pts[], IdxGetTy IdxGet) {
    // Renew table.
    DW[0][IdxGet(Degree)] = Fn(Pts[IdxGet(Degree)]);
    for (IdxType j = 1; j < PNum; ++j) {
      DW[j][IdxGet(Degree + j)] =
        (DW[j - 1][IdxGet(Degree + j)] - DW[j - 1][IdxGet(Degree + j - 1)]) /
        (Pts[IdxGet(Degree)] - Pts[IdxGet(Degree - j)]);
    }
  }
};

template<typename FnT, typename NormT>
struct CalcNextMuller {
  static constexpr IdxType UsedPts = 3;
  static constexpr IdxType StorageSize = nextPow2<IdxType, UsedPts>();

  using IdxGetTy = IdxGetT<StorageSize - 1>;
  using FnTy = CopyOrRefT<FnT>;
  using NormTy = CopyOrRefT<NormT>;

  CalcNextMuller(FnTy Fn, ValType Pts[]) {}

  ValType get(FnTy Fn, NormTy Norm,
              ValType Pts[], IdxGetTy IdxGet) {
    ValType P0 = Pts[IdxGet(0)];
    ValType P1 = Pts[IdxGet(1)];
    ValType P2 = Pts[IdxGet(2)];

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

  void update(FnTy Fn, ValType Pts[], IdxGetTy IdxGet) {}

};

template<typename Method, typename ColorFnTy>
static PtColor
getPointIndexN(typename Method::FnTy Fn,
               typename Method::NormTy Norm,
               CopyOrRefT<ColorFnTy> ColorFn,
               ValType Init) {
  constexpr IdxType UsedPts = Method::UsedPts;
  constexpr IdxType Size = Method::StorageSize;

  ValType Pts[Size];
  Pts[0] = Init;
  for (unsigned i = 1; i < UsedPts; ++i)
    Pts[i] = calcNextSteffensonL<decltype(Fn)>(Fn, Pts[i - 1]);

  Method Mth(Fn, Pts);

  typename Method::IdxGetTy IdxGet;
  for (int i = 0; i < MaxIters; ++i) {
    ValType Next = Mth.get(Fn, Norm, Pts, IdxGet);
    if (std::isnan(Next.real()) || std::isnan(Next.imag()))
      break;

    if (Norm(Fn(Next)) < Epsilon)
      return {true, ColorFn(Next)};

    ++IdxGet;
    Pts[IdxGet(UsedPts)] = Next;

    Mth.update(Fn, Pts, IdxGet);
  }

  return {false, 0.0};
}

#endif
