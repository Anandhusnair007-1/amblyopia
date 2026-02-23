"""
Amblyopia Care System — Integration Layer
=========================================
6 ML/AI integration modules for Aravind Eye Hospital screening pipeline.

Available integrations:
  • RealESRGANIntegration   — eye image super-resolution
  • ZeroDCEIntegration      — low-light enhancement
  • DeblurGANIntegration    — motion/focus deblurring
  • WhisperIntegration      — multi-language speech → text
  • RNNoiseIntegration      — audio noise suppression
  • YOLOIntegration         — eye/face detection and strabismus signals
"""
from __future__ import annotations

__version__ = "1.0.0"
__all__ = [
    "RealESRGANIntegration",
    "ZeroDCEIntegration",
    "DeblurGANIntegration",
    "WhisperIntegration",
    "RNNoiseIntegration",
    "YOLOIntegration",
]
