#ifndef FRACGEN_ITER_METHODS_DEFINED__
#define FRACGEN_ITER_METHODS_DEFINED__

#include "Config.h"
#include "Support.hpp"
#include "TypeHelpers.hpp"
#include "Types.h"

#include <functional>
#include <random>
#include <type_traits>
#include <utility>

#include <cmath>
#include <cstdlib>

struct CalcNextNewton {
  static constexpr IdxType UsedPts = 1;

  template<typename FnTy, typename PtCont>
  CalcNextNewton(FnTy Fn, const PtCont &Pts) {}

  template<typename FnTy, typename NormTy, typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    ValType FnRes = Fn(Pts.front());
    ValType DiffRes = Fn.diff(Pts.front());
    return Pts.front() - FnRes / DiffRes;
  }

  template<typename FnTy, typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {}
};

struct CalcNextChord {
  static constexpr IdxType UsedPts = 1;

private:
  ValType InitPt;
  ValType FnInit;

public:
  template<typename FnTy, typename PtCont>
  CalcNextChord(FnTy Fn, const PtCont &Pts):
    InitPt(Pts.front()), FnInit(Fn(InitPt)) {}

  template<typename FnTy, typename NormTy, typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    ValType F0 = Fn(Pts.front());
    return Pts.front() - FnInit * (InitPt - Pts.front()) / (FnInit - F0);
  }

  template<typename FnTy, typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {}
};

// Steffenson's method. Helper for bootstrap stages.
struct CalcNextSteffenson {
  static constexpr IdxType UsedPts = 1;

  template<typename FnTy, typename PtCont>
  CalcNextSteffenson(FnTy Fn, const PtCont &Pts) {}

  template<typename FnTy, typename NormTy, typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    ValType Tmp = Fn(Pts.front());
    ValType Tmp2 = Fn(Pts.front() + Tmp);
    return Pts.front() - (Tmp * Tmp) / (Tmp2 - Tmp);
  }

  template<typename FnTy, typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {}
};

template<IdxType Degree = 7>
struct CalcNextSidi {
  static constexpr IdxType UsedPts = Degree + 1;

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

  IdxType getDWIdx(IdxType Idx) const {
    assert(Idx < PNum && "Idx is out of range");
    return (DWPos + Idx) & Mask;
  }

  void advanceDWIdx() {
    DWPos = getDWIdx(1);
  }

public:
  template<typename FnTy, typename PtCont>
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

  template<typename FnTy, typename NormTy, typename PtCont>
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

  template<typename FnTy, typename PtCont>
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

struct CalcNextMuller {
  static constexpr IdxType UsedPts = 3;

  template<typename FnTy, typename PtCont>
  CalcNextMuller(FnTy Fn, const PtCont &Pts) {}

  template<typename FnTy, typename NormTy, typename PtCont>
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

  template<typename FnTy, typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {}
};

template<typename I, typename... Methods>
struct CalcNextMixed;

template<size_t... Probs, typename... Methods>
struct CalcNextMixed<std::index_sequence<Probs...>, Methods...> : Methods... {
  static_assert(sizeof...(Probs) == sizeof...(Methods), "Wrong mixed parameters");
  static constexpr IdxType UsedPts = std::max({Methods::UsedPts...});

  template<typename FnTy, typename PtCont>
  CalcNextMixed(FnTy Fn, const PtCont &Pts): Methods(Fn, Pts)... {}

private:
  template<typename T, typename FnTy, typename NormTy, typename PtCont>
  ValType lambdaHelper(FnTy Fn, NormTy Norm, const PtCont &Pt) {
    return this->T::get(Fn, Norm, Pt);
  }

public:
  template<typename FnTy, typename NormTy, typename PtCont>
  ValType get(FnTy Fn, NormTy Norm, const PtCont &Pts) {
    static std::mt19937 Rnd(static_cast<unsigned>(Norm(Fn(Pts.front()))));
    static std::discrete_distribution<size_t> Distr({Probs...});
    using HelperTy = ValType (CalcNextMixed::*)(FnTy, NormTy, const PtCont &);
    static const HelperTy MethArr[] = {&CalcNextMixed::lambdaHelper<Methods, FnTy, NormTy, PtCont>...};

    return (this->*MethArr[Distr(Rnd)])(Fn, Norm, Pts);
  }

  template<typename FnTy, typename PtCont>
  void update(FnTy Fn, const PtCont &Pts) {
    int X[] = {(this->Methods::update(Fn, Pts), 0)...};
    (void) X;
  }
};

template<typename Method, typename FnTy, typename NormTy, typename ColorFnTy>
static PtColor
getPointIndexN(FnTy Fn, NormTy Norm, ColorFnTy ColorFn, ValType Init) {
  constexpr IdxType UsedPts = Method::UsedPts;

  CircularBuffer<ValType, UsedPts> Pts([Fn, Norm, Pt = Init]() mutable -> ValType {
      const CircularBuffer<ValType, 1> PtBuf([Pt]() -> ValType {
          return Pt;
        });

      CalcNextSteffenson Stf(Fn, PtBuf);
      Pt = Stf.get(Fn, Norm, PtBuf);
      return PtBuf.front();
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
