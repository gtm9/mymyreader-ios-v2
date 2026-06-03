#!/bin/sh
set -e

echo "========================================"
echo "Xcode Cloud Pre-Build Script"
echo "========================================"

# Install HuggingFace CLI
echo "Installing huggingface-cli..."
python3 -m pip install -U "huggingface_hub[cli]" --break-system-packages

# Create Models directory if it doesn't exist
# Note: ci_scripts run from the ci_scripts directory, so we go up one level
mkdir -p ../Models/Qwen3-TTS-12Hz-0.6B-Base-4bit

# Download the model using python3 module to bypass any $PATH issues
echo "Downloading Qwen3-TTS model from Hugging Face..."
python3 -m huggingface_hub.cli download mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit --local-dir ../Models/Qwen3-TTS-12Hz-0.6B-Base-4bit

echo "Pre-build script completed successfully."
