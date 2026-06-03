#!/bin/sh
set -e

echo "========================================"
echo "Xcode Cloud Pre-Build Script"
echo "========================================"

# Install HuggingFace Hub python package
echo "Installing huggingface_hub..."
python3 -m pip install -U huggingface_hub --break-system-packages

# Create Models directory if it doesn't exist
# Note: ci_scripts run from the ci_scripts directory, so we go up one level
mkdir -p ../Models/Qwen3-TTS-12Hz-0.6B-Base-4bit

# Download the model using python3 script to completely bypass any CLI errors
echo "Downloading Qwen3-TTS model from Hugging Face..."
python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit', local_dir='../Models/Qwen3-TTS-12Hz-0.6B-Base-4bit')"

echo "Pre-build script completed successfully."
