#ifndef FRACGEN_SUPPORT_HPP_DEFINED__
#define FRACGEN_SUPPORT_HPP_DEFINED__

#include "Types.h"

#include <algorithm>
#include <array>

#include <cassert>

template<typename T, T Num, typename = std::enable_if_t<std::is_integral_v<T>, void>>
constexpr T nextPow2() {
  static_assert(!(Num & (1 << (sizeof(Num) * 8 - 1))), "Too big number");
  if (Num == 0)
    return 1;
  T Res = 1;
  while ((Res <<= 1) < Num);
  return Res;
}

// Specialized always full circular buffer.
template<typename T, IdxType Size>
class CircularBuffer {
  static constexpr IdxType StorageSize = nextPow2<IdxType, Size>();
  static constexpr IdxType Mask = StorageSize - 1;
  static_assert((Mask & (Mask + 1)) == 0, "Mask should be power of 2 minus one!");

  std::array<T, StorageSize> Data;
  IdxType Begin = 0;

  IdxType getIdx(IdxType Idx) const {
    assert(Idx < Size && "Idx is out of range");
    return (Begin + Idx) & Mask;
  }
public:
  // Sorry, no default ctor.
  CircularBuffer() = delete;

  template<typename GenTy>
  CircularBuffer(GenTy Generator) {
    std::generate(Data.begin(), Data.begin() + Size, Generator);
  }

  const T &operator[](IdxType Idx) const {
    return Data[getIdx(Idx)];
  }

  T &operator[](IdxType Idx) {
    return Data[getIdx(Idx)];
  }

  const T &front() const {
    return Data[Begin];
  }

  T &front() {
    return Data[Begin];
  }

  void push_back(const T &Val) {
    Begin = getIdx(1);
    (*this)[Size - 1] = Val;
  }

  void push_back(T &&Val) {
    Begin = getIdx(1);
    (*this)[Size - 1] = std::move(Val);
  }
};

#endif
