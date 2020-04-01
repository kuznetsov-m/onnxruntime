// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "core/providers/cuda/cuda_common.h"
#include "core/providers/cuda/cu_inc/common.cuh"
#include "core/providers/cuda/tensor/onehot.h"

namespace onnxruntime {
namespace cuda {

template <typename in_type, typename out_type>
__global__ void _OneHotImpl(
    const in_type* indices_data,
    const fast_divmod fdm_depth_suffix,
    const fast_divmod fdm_suffix,
    const int64_t depth_val,
    const out_type on_value,
    const out_type off_value,
    out_type* output_data,
    CUDA_LONG N) {
  CALCULATE_ELEMENTWISE_INDEX_OR_EXIT(id, N);

  int prefix_index, prefix_offset;
  fdm_depth_suffix.divmod(id, prefix_index, prefix_offset);

  int depth_index, suffix_index;
  fdm_suffix.divmod(prefix_offset, depth_index, suffix_index);

  CUDA_LONG indices_index = prefix_index * fdm_suffix.d_ + suffix_index;

  // handle negative index
  in_type adjusted_indice = (indices_data[indices_index] + depth_val) % depth_val;

  output_data[id] = (adjusted_indice == in_type(depth_index)) ? on_value : off_value;
}

template <typename in_type, typename out_type>
void OneHotImpl(
    const in_type* indices_data,
    const fast_divmod fdm_depth_suffix,
    const fast_divmod fdm_suffix,
    const int64_t depth_val,
    const out_type on_value,
    const out_type off_value,
    out_type* output_data,
    size_t count) {
  int blocksPerGrid = (int)(ceil(static_cast<float>(count) / GridDim::maxThreadsPerBlock));
  CUDA_LONG N = static_cast<CUDA_LONG>(count);
  _OneHotImpl<in_type, out_type><<<blocksPerGrid, GridDim::maxThreadsPerBlock, 0>>>(
    indices_data,
    fdm_depth_suffix,
    fdm_suffix,
    depth_val,
    on_value,
    off_value,
    output_data,
    N);
}

#define SPECIALIZED_OneHotImpl(in_type, out_type) \
  template void OneHotImpl(                       \
    const in_type* indices_data,                  \
    const fast_divmod fdm_depth_suffix,           \
    const fast_divmod fdm_suffix,                 \
    const int64_t depth_val,                      \
    const out_type on_value,                      \
    const out_type off_value,                     \
    out_type* output_data,                        \
    size_t count);

SPECIALIZED_OneHotImpl(int64_t, int64_t)
SPECIALIZED_OneHotImpl(int64_t, float)
SPECIALIZED_OneHotImpl(int32_t, float)

}  // namespace cuda
}  // namespace onnxruntime