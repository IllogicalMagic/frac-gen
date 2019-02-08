#ifndef FRACGEN_NORMS_H_DEFINED___
#define FRACGEN_NORMS_H_DEFINED___

#include "Types.h"

#include <cmath>

// P-norms {{

// p == 2.
static inline
FloatType norm2(ValType V) {
  return std::abs(V);
}

// p == 1.
static inline
FloatType norm1(ValType V) {
  return std::abs(V.real()) + std::abs(V.imag());
}

// p == inf.
static inline
FloatType normInf(ValType V) {
  return std::max(std::abs(V.real()), std::abs(V.imag()));
}

// }} p-norms.

// Just a random combination of basic norms.
// Should be a norm too.
static inline
FloatType normC(ValType V) {
  return 3.0 * std::abs(V.real()) + std::sqrt(2.0 * std::abs(V.imag()) + std::pow(std::abs(V.real()), 5.0));
}

// Used norm is here.
#include "Norm.X.h"

#endif
