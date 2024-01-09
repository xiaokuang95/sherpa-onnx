// sherpa-onnx/csrc/speaker-embedding-extractor-impl.h
//
// Copyright (c)  2023  Xiaomi Corporation

#ifndef SHERPA_ONNX_CSRC_SPEAKER_EMBEDDING_EXTRACTOR_IMPL_H_
#define SHERPA_ONNX_CSRC_SPEAKER_EMBEDDING_EXTRACTOR_IMPL_H_

#include <memory>
#include <string>
#include <vector>

#include "sherpa-onnx/csrc/speaker-embedding-extractor.h"

namespace sherpa_onnx {

class SpeakerEmbeddingExtractorImpl {
 public:
  virtual ~SpeakerEmbeddingExtractorImpl() = default;

  static std::unique_ptr<SpeakerEmbeddingExtractorImpl> Create(
      const SpeakerEmbeddingExtractorConfig &config);

  virtual int32_t Dim() const = 0;

  virtual std::unique_ptr<OnlineStream> CreateStream() const = 0;

  virtual bool IsReady(OnlineStream *s) const = 0;

  virtual std::vector<float> Compute(OnlineStream *s) const = 0;
};

}  // namespace sherpa_onnx

#endif  // SHERPA_ONNX_CSRC_SPEAKER_EMBEDDING_EXTRACTOR_IMPL_H_