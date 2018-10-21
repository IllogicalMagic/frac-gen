#ifndef FRACGEN_TYPE_HELPERS_DEFINED__
#define FRACGEN_TYPE_HELPERS_DEFINED__

#include <type_traits>

namespace Detail {

template<typename Ty, bool Copy>
struct CopyOrRefImpl {
  using Type = Ty;
};

template<typename Ty>
struct CopyOrRefImpl<Ty, false> {
  using Type = const Ty&;
};

}

template<typename Ty>
struct CopyOrRef {
  using DerefTy = std::remove_reference_t<Ty>;
  using Type =
    typename Detail::CopyOrRefImpl<DerefTy, (std::is_trivially_copyable_v<DerefTy> && sizeof(DerefTy) <= 8)>::Type;
};

template<typename Ty>
using CopyOrRefT = typename CopyOrRef<Ty>::Type;

#endif
