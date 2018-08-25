#ifndef FRACTAL_TYPES_H
#define FRACTAL_TYPES_H

#include <complex>
#include <sstream>
#include <type_traits>
#include <vector>

using FloatType = double;
using ValType = std::complex<FloatType>;
// Coefficients of polynom starting from lowest power.
// e.g. poly[0] is a constant (c*x^0).
using PolyType = std::vector<ValType>;

/* using PtColor = std::pair<int, unsigned>; */
using PtColor = std::pair<bool, double>;

#endif
