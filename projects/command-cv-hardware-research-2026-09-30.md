---
type: project
domain: computer-vision
created: 2026-09-30
updated: 2026-09-30
status: CAPTURED - hardware choice for resuming Command CV (project shelved 09-30 for lack of compute)
tags:
  - project
  - command-cv
  - hardware
  - external-research
---

# Command CV - which machine to buy (research 2026-09-30)

Why this exists: Zac shelved Command CV on 2026-09-30 ("we dont have enough computer here").
The laptop is an RTX 3050 Ti, 4 GB VRAM, ~2-4 GB free disk. A v4 epoch on 53k crops took
~1,400 s. He is buying an AMD machine (Ryzen AI Max / Ryzen 9) and asked which stack is
best for this workload: YOLO ball detector training in PyTorch/Ultralytics + heavy video decode.

## Source 1 - Strix Halo (Ryzen AI Max+ 395) vs RTX 4090, community benchmarks
- https://llm-tracker.info/AMD-Strix-Halo-(Ryzen-AI-Max+-395)-GPU-Performance
- https://www.modemguides.com/blogs/ai-infrastructure/ryzen-ai-max-395-local-llm-reality-check
- 16 Zen 5 cores, 40-CU RDNA 3.5 iGPU, up to 128 GB unified memory. Measured memory
  bandwidth ~210-220 GB/s, about a QUARTER of an RTX 4090. AMD's "2x faster than a 4090"
  claim is a 70B LLM that does not fit in 24 GB; on models that DO fit, the 4090 is several
  times faster.
- Takeaway for us: our model is tiny (YOLO11n, <1 GB VRAM). Big memory buys nothing;
  bandwidth and raw compute are what we need, and there the 4090-class card wins.

## Source 2 - ROCm support for Strix Halo (gfx1151)
- https://github.com/ROCm/ROCm/issues/6034
- https://medium.com/@GenerationAI/pytorch-with-rocm-7-for-windows-on-amd-ryzen-ai-max-395-strix-halo-radeon-8060s-gfx1151-1ba069edc2c4
- As of early 2026 gfx1151 is NOT on AMD's official ROCm support matrix; PyTorch runs from
  NIGHTLY wheels (rocm.nightlies.amd.com/v2/gfx1151). One tracker issue logs 93 experiments
  and 5 bf16 bugs.
- Takeaway for us: every script we have assumes CUDA (`--device 0`, ultralytics defaults).
  ROCm nightly = debugging the toolchain instead of the model. Same failure class as the
  6-day "no GPU" blocker (`probe-capability-before-accepting-a-blocker.md`).

## Source 3 - Apple M4 Pro/Max (MPS) for YOLO training
- https://github.com/ultralytics/ultralytics/issues/22778
- https://scalastic.io/en/apple-silicon-vs-nvidia-cuda-ai-2025/
- Ultralytics user: M4 Max trains YOLO11s-cls at ~1/6 the speed of an NVIDIA card
  (1.8 it/s). ResNet-50: M3/M4 Max 45-50 s vs RTX 4090 15 s. MPS lacks some ops (CPU
  fallback). Very power-efficient.
- Takeaway for us: fine for inference/demo, 3x+ slower to train, and non-CUDA. Not for this.

## Source 4 - RTX 5090 vs 4090, price and speed (2026)
- https://www.spheron.network/blog/rtx-5090-vs-rtx-4090/
- https://insiderllm.com/guides/rtx-5090-local-ai-benchmarks/
- 5090: 32 GB GDDR7, 1,792 GB/s, 45-75% faster than a 4090 on training; street price
  ~$3,900-4,400 (Aug 2026) vs $1,999 MSRP. Used 4090 ~$900-1,100 for ~80-85% of a 5090.
- Takeaway for us: a used 4090 (or new 5080/5070 Ti class) is the value pick; our model
  never needs more than 24 GB.

## Recommendation (for Zac)
- Desktop, Ryzen 9 (9950X or similar) + NVIDIA RTX card (used 4090 best value, 5090 if
  money no object), 64 GB RAM, 4 TB NVMe (video is 1-2 GB per game).
- Expected: ~6-10x the laptop per epoch; disk stops being the limit.
- Ryzen AI Max+ 395 box = great for big local LLMs, wrong tool for CUDA vision training.
- Mac mini/Studio = wrong tool here.

Related: [[command-cv-status]] · [[command-cv-external-research]] · [[pytorch-training-pipeline]]
