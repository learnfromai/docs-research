# macOS Installation Guide

Step-by-step installation instructions for hosting DeepSeek models locally on macOS systems.

## Pre-Installation Requirements

### System Requirements

#### Minimum Configuration
- **macOS**: 10.15 (Catalina) or later
- **RAM**: 16GB (for 7B models)
- **Storage**: 20GB free space
- **Processor**: Intel Core i5 or Apple Silicon (M1/M2/M3)

#### Recommended Configuration
- **macOS**: 13.0 (Ventura) or later
- **RAM**: 32GB+ (for larger models)
- **Storage**: 100GB+ free space (SSD preferred)
- **Processor**: Apple Silicon (M2 Pro/Max/Ultra)

### Development Tools

```bash
# Install Xcode Command Line Tools (required)
xcode-select --install

# Install Homebrew (recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Verify installation
brew --version
```

## Installation Methods

### Method 1: Ollama (Recommended) ⭐

**Why Ollama?**
- Simplest installation and management
- Excellent macOS optimization
- Active development and support
- Built-in model management

#### Step 1: Install Ollama

```bash
# Option A: Official installer script
curl -fsSL https://ollama.ai/install.sh | sh

# Option B: Homebrew (recommended)
brew install ollama

# Option C: Manual download
# Visit https://ollama.ai/download and download macOS installer
```

#### Step 2: Start Ollama Service

```bash
# Start Ollama as a service (auto-starts on boot)
brew services start ollama

# Or start manually (temporary)
ollama serve

# Verify Ollama is running
curl http://localhost:11434/api/version
```

#### Step 3: Install DeepSeek Models

```bash
# List available DeepSeek models
ollama list | grep -i deepseek

# Pull recommended models
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M   # Best for coding
ollama pull deepseek-chat:32b-q4_K_M                     # Good for general chat
ollama pull deepseek-coder:6.7b-instruct-q4_K_M          # Lighter coding model

# Check downloaded models
ollama list
```

#### Step 4: Test Installation

```bash
# Interactive chat
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# API test
curl http://localhost:11434/api/generate -d '{
  "model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M",
  "prompt": "Write a Python function to reverse a string",
  "stream": false
}' | jq '.'
```

#### Ollama Configuration

**Create custom Modelfile for optimization**:

```bash
# Create Modelfile
cat > Modelfile << EOF
FROM deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Set parameters for better performance on Apple Silicon
PARAMETER num_ctx 4096
PARAMETER temperature 0.1
PARAMETER top_k 40
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1

SYSTEM "You are DeepSeek, a helpful AI assistant specialized in coding and programming tasks."
EOF

# Create custom model
ollama create deepseek-coder-optimized -f Modelfile

# Run optimized model
ollama run deepseek-coder-optimized
```

### Method 2: LM Studio (GUI Option) ⭐

**Why LM Studio?**
- User-friendly graphical interface
- Excellent model management
- Built-in performance monitoring
- No command-line experience required

#### Step 1: Install LM Studio

```bash
# Install via Homebrew Cask
brew install --cask lm-studio

# Or download manually from https://lmstudio.ai/
```

#### Step 2: Download DeepSeek Models

1. **Launch LM Studio**
2. **Navigate to Model Browser** (📦 tab)
3. **Search for "deepseek"**
4. **Download recommended models**:
   - `deepseek-coder-v2-lite-instruct` (best for coding)
   - `deepseek-chat-67b` (if you have sufficient RAM)
   - `deepseek-coder-6.7b-instruct` (lighter option)

#### Step 3: Configure and Run

1. **Switch to Chat tab** (💬)
2. **Select your downloaded model**
3. **Adjust settings**:
   - **Context Length**: 4096 tokens
   - **Temperature**: 0.1 for coding, 0.7 for chat
   - **GPU Acceleration**: Auto (should detect Metal)
4. **Start chatting**

#### Step 4: API Server Setup

1. **Navigate to Server tab** (🌐)
2. **Select your model**
3. **Configure port** (default: 1234)
4. **Start server**
5. **Test API**:

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-coder-v2-lite-instruct",
    "messages": [
      {"role": "user", "content": "Write a Python function to sort a list"}
    ]
  }'
```

### Method 3: llama.cpp (Advanced) ⭐⭐⭐

**Why llama.cpp?**
- Maximum performance and efficiency
- Extensive customization options
- Direct model control
- Best for advanced users

#### Step 1: Install Dependencies

```bash
# Install build tools
brew install cmake
brew install make

# Clone llama.cpp repository
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
```

#### Step 2: Compile for Apple Silicon

```bash
# Compile with Metal support (Apple Silicon)
make LLAMA_METAL=1

# Or compile with Accelerate framework
make LLAMA_ACCELERATE=1

# For Intel Macs, use OpenBLAS
# brew install openblas
# make LLAMA_OPENBLAS=1
```

#### Step 3: Download DeepSeek Models

```bash
# Create models directory
mkdir -p models

# Download GGUF models from Hugging Face
# DeepSeek-Coder-V2-Lite-Instruct (recommended)
curl -L "https://huggingface.co/deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct-q4_k_m.gguf" -o models/deepseek-coder-v2-lite-q4_k_m.gguf

# DeepSeek-Chat (if sufficient RAM)
curl -L "https://huggingface.co/deepseek-ai/DeepSeek-Chat-GGUF/resolve/main/DeepSeek-Chat-32b-q4_k_m.gguf" -o models/deepseek-chat-32b-q4_k_m.gguf
```

#### Step 4: Run Models

```bash
# Interactive chat
./llama-cli \
  -m models/deepseek-coder-v2-lite-q4_k_m.gguf \
  -p "Write a Python function to calculate factorial" \
  -n 500 \
  --ctx-size 4096 \
  --temp 0.1 \
  --top-k 40 \
  --top-p 0.9

# Start server
./llama-server \
  -m models/deepseek-coder-v2-lite-q4_k_m.gguf \
  --port 8080 \
  --host 0.0.0.0 \
  --ctx-size 4096 \
  --n-gpu-layers 35
```

#### Step 5: Performance Testing

```bash
# Benchmark model performance
./llama-perplexity \
  -m models/deepseek-coder-v2-lite-q4_k_m.gguf \
  -f prompts/coding-test.txt \
  --ctx-size 4096

# Monitor GPU usage (Apple Silicon)
sudo powermetrics --samplers smc --sample-rate 1000 | grep -i gpu
```

### Method 4: Text Generation WebUI ⭐⭐⭐

**Why Text Generation WebUI?**
- Feature-rich web interface
- Advanced parameter control
- Plugin ecosystem
- Model comparison features

#### Step 1: Install Python Environment

```bash
# Install Python 3.10+ (required)
brew install python@3.10

# Create virtual environment
python3.10 -m venv text-gen-webui
source text-gen-webui/bin/activate

# Upgrade pip
pip install --upgrade pip
```

#### Step 2: Clone and Install

```bash
# Clone repository
git clone https://github.com/oobabooga/text-generation-webui.git
cd text-generation-webui

# Run automatic installer
./start_macos.sh

# Or manual installation
pip install torch torchvision torchaudio
pip install -r requirements.txt
```

#### Step 3: Download Models

```bash
# Create models directory
mkdir -p models

# Download using included script
python download-model.py deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF \
  --output-folder models/

# Or download manually to models/ directory
```

#### Step 4: Launch Interface

```bash
# Start web interface
python server.py --listen --model deepseek-coder-v2-lite-instruct

# Access at http://localhost:7860

# Or with specific settings
python server.py \
  --listen \
  --model deepseek-coder-v2-lite-instruct \
  --load-in-4bit \
  --gpu-memory 8 \
  --cpu-memory 16
```

## Advanced Configuration

### Environment Variables

```bash
# Ollama configuration
export OLLAMA_HOST=0.0.0.0:11434
export OLLAMA_MODELS=/Users/$(whoami)/ollama-models
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=2

# llama.cpp optimization
export LLAMA_METAL=1
export LLAMA_CUBLAS=0

# Add to ~/.zshrc or ~/.bash_profile for persistence
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc
```

### Performance Optimization

#### For Apple Silicon Macs

```bash
# Enable Metal Performance Shaders
export PYTORCH_ENABLE_MPS_FALLBACK=1

# Optimize memory allocation
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

# Set thread count for optimal performance
export OMP_NUM_THREADS=8  # Adjust based on your CPU cores
```

#### Memory Management

```bash
# Check available memory
vm_stat | head -5

# Monitor memory usage while running models
while true; do
  echo "$(date): $(vm_stat | awk '/Pages free/ {print $3}' | tr -d .)00 KB free"
  sleep 5
done
```

### Automation Scripts

#### Auto-start Script

```bash
# Create startup script
cat > ~/start-deepseek.sh << 'EOF'
#!/bin/bash

# Start Ollama if not running
if ! pgrep -x "ollama" > /dev/null; then
    echo "Starting Ollama..."
    ollama serve &
    sleep 3
fi

# Ensure DeepSeek model is available
if ! ollama list | grep -q "deepseek-coder-v2"; then
    echo "Downloading DeepSeek Coder V2..."
    ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M
fi

echo "DeepSeek is ready!"
echo "Run: ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M"
EOF

chmod +x ~/start-deepseek.sh

# Run the script
~/start-deepseek.sh
```

#### Model Switching Script

```bash
# Create model switching script
cat > ~/switch-deepseek-model.sh << 'EOF'
#!/bin/bash

echo "Available DeepSeek models:"
ollama list | grep deepseek

echo ""
read -p "Enter model name to run: " model_name

if ollama list | grep -q "$model_name"; then
    echo "Starting $model_name..."
    ollama run "$model_name"
else
    echo "Model not found. Available models:"
    ollama list | grep deepseek
fi
EOF

chmod +x ~/switch-deepseek-model.sh
```

## Troubleshooting

### Common Issues

#### "Permission denied" errors
```bash
# Fix permissions for Ollama
sudo chown -R $(whoami) ~/.ollama

# Fix permissions for models directory  
sudo chown -R $(whoami) ~/ollama-models
```

#### Metal acceleration not working
```bash
# Verify Metal support
python3 -c "import torch; print(torch.backends.mps.is_available())"

# Check GPU information
system_profiler SPDisplaysDataType | grep "Metal"
```

#### Out of memory errors
```bash
# Check memory usage
vm_stat

# Use smaller model
ollama pull deepseek-coder:6.7b-instruct-q4_K_M

# Or use lower precision
ollama pull deepseek-coder-v2:16b-lite-instruct-q2_K
```

#### Port conflicts
```bash
# Check what's using port 11434
lsof -i :11434

# Use different port
OLLAMA_HOST=127.0.0.1:11435 ollama serve
```

### Performance Issues

#### Slow inference
```bash
# Check CPU and memory usage
top -pid $(pgrep ollama)

# Verify model is using GPU acceleration
ollama show deepseek-coder-v2:16b-lite-instruct-q4_K_M --verbose
```

#### High memory usage
```bash
# Monitor memory over time
watch -n 1 'vm_stat | head -5'

# Use model with better quantization
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_0  # Lower memory
```

## Verification Tests

### Basic Functionality Test

```bash
# Test basic chat
echo "Write a hello world program in Python" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Test API endpoint
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M",
    "prompt": "def fibonacci(n):",
    "stream": false
  }'
```

### Performance Benchmark

```bash
# Time a simple generation
time echo "Write a Python function to sort an array using quicksort" | \
  ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M
```

### Memory Usage Test

```bash
# Monitor memory during model load
echo "Before loading model:"
vm_stat | grep "Pages free"

ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Hello" >/dev/null

echo "After loading model:"
vm_stat | grep "Pages free"
```

## Next Steps

1. **Choose your preferred method** based on technical comfort level
2. **Install and test** with simple prompts
3. **Configure optimization settings** for your hardware
4. **Set up automation scripts** for convenience
5. **Move to the next guide**: [Performance Optimization](./performance-optimization.md)

---

## Navigation

| Previous | Home | Next |
|----------|------|------|
| [Hosting Options Comparison](./hosting-options-comparison.md) | [DeepSeek Research](./README.md) | [Performance Optimization](./performance-optimization.md) |

---

*Installation guide verified on macOS 14.0+ with Apple Silicon and Intel processors*  
*Sources: Official documentation, community guides, Apple Developer documentation*