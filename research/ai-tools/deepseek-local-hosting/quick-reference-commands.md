# Quick Reference Commands

Complete one-liner command lists for immediate implementation of DeepSeek local hosting on macOS. This serves as your quick reference guide for getting started and managing DeepSeek models locally.

## 🚀 Instant Setup (Choose One Method)

### Method 1: Ollama - Recommended for Most Users

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
brew services start ollama

# Pull and run DeepSeek Coder (best for development)
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M && ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Alternative: Pull and run DeepSeek Chat (best for general use)
ollama pull deepseek-chat:32b-q4_K_M && ollama run deepseek-chat:32b-q4_K_M
```

### Method 2: LM Studio - GUI Option

```bash
# Install LM Studio
brew install --cask lm-studio

# Open LM Studio, go to Model Browser, search "deepseek", download desired model
open -a "LM Studio"
```

### Method 3: Text Generation WebUI - Web Interface

```bash
# Install and run Text Generation WebUI
git clone https://github.com/oobabooga/text-generation-webui.git && cd text-generation-webui && ./start_macos.sh
```

### Method 4: llama.cpp - Maximum Performance

```bash
# Clone, compile, and download model
git clone https://github.com/ggerganov/llama.cpp.git && cd llama.cpp && make LLAMA_METAL=1 && curl -L "https://huggingface.co/deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct-q4_k_m.gguf" -o deepseek-model.gguf && ./llama-cli -m deepseek-model.gguf -p "Write a Python hello world program" -n 100
```

## 📦 Model Management

### Download Recommended Models

```bash
# Coding models (choose based on your RAM)
ollama pull deepseek-coder:6.7b-instruct-q4_K_M        # 8GB+ RAM
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M # 16GB+ RAM

# Chat models (choose based on your RAM)
ollama pull deepseek-chat:32b-q4_K_M                    # 32GB+ RAM
ollama pull deepseek-chat:67b-q4_K_M                    # 64GB+ RAM
```

### Model Operations

```bash
# List installed models
ollama list

# Remove a model
ollama rm deepseek-coder:6.7b-instruct-q4_K_M

# Show model information
ollama show deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Copy/duplicate a model
ollama cp deepseek-coder-v2:16b-lite-instruct-q4_K_M my-custom-deepseek
```

## 💬 Usage Commands

### Interactive Chat

```bash
# Start interactive chat session
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Run with custom parameters
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M --temperature 0.1 --num-ctx 4096

# One-time question
echo "Write a Python function to calculate fibonacci numbers" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M
```

### API Usage

```bash
# Simple API call
curl http://localhost:11434/api/generate -d '{"model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M", "prompt": "Write a hello world program", "stream": false}'

# Chat API call
curl http://localhost:11434/api/chat -d '{"model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M", "messages": [{"role": "user", "content": "Explain recursion in Python"}]}'

# Generate with parameters
curl http://localhost:11434/api/generate -d '{"model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M", "prompt": "Create a REST API", "temperature": 0.1, "max_tokens": 500, "stream": false}'
```

## ⚡ Performance Optimization

### Environment Variables for Optimal Performance

```bash
# Set optimal environment variables (add to ~/.zshrc)
export OLLAMA_MAX_LOADED_MODELS=1 && export OLLAMA_NUM_PARALLEL=1 && export OMP_NUM_THREADS=8 && echo "Environment optimized for DeepSeek"

# Apply immediately and persist
export OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_NUM_PARALLEL=1 OMP_NUM_THREADS=8 && echo 'export OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_NUM_PARALLEL=1 OMP_NUM_THREADS=8' >> ~/.zshrc
```

### Create Optimized Model Variants

```bash
# Create optimized coding model
echo 'FROM deepseek-coder-v2:16b-lite-instruct-q4_K_M
PARAMETER temperature 0.1
PARAMETER top_k 40
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
SYSTEM "You are an expert programmer. Provide clean, well-commented code."' | ollama create deepseek-coder-optimized -f -

# Create optimized chat model  
echo 'FROM deepseek-chat:32b-q4_K_M
PARAMETER temperature 0.7
PARAMETER top_k 50
PARAMETER top_p 0.95
PARAMETER num_ctx 4096
SYSTEM "You are a helpful AI assistant."' | ollama create deepseek-chat-optimized -f -
```

## 📊 System Monitoring

### Real-time Monitoring

```bash
# Monitor Ollama process in real-time
watch -n 2 'ps aux | grep ollama | grep -v grep && echo "Memory:" && vm_stat | grep free'

# Monitor CPU and memory usage
top -pid $(pgrep ollama) -s 5 -n 10

# Check GPU temperature (Apple Silicon)
while true; do sudo powermetrics --samplers smc -n 1 2>/dev/null | grep "GPU die temperature"; sleep 5; done
```

### Performance Testing

```bash
# Quick performance test
time echo "Write a Python function to sort an array" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# API performance test
time curl -s http://localhost:11434/api/generate -d '{"model": "deepseek-coder-v2:16b-lite-instruct-q4_K_M", "prompt": "Hello world", "stream": false}' | jq -r '.response'

# Memory usage test
echo "Before:" && vm_stat | grep free && ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "test" >/dev/null && echo "After:" && vm_stat | grep free
```

## 🔧 Service Management

### Ollama Service Control

```bash
# Start Ollama as service (auto-start on boot)
brew services start ollama

# Stop Ollama service
brew services stop ollama

# Restart Ollama service
brew services restart ollama

# Start Ollama manually (temporary)
ollama serve &

# Kill Ollama process
pkill ollama
```

### Health Checks

```bash
# Check if Ollama is running
pgrep -x ollama && echo "Ollama is running" || echo "Ollama is not running"

# Test API connectivity
curl -s http://localhost:11434/api/version && echo "API is working" || echo "API is not responding"

# Comprehensive health check
curl -s http://localhost:11434/api/version | jq '.' && ollama list | head -5 && echo "System Status: OK"
```

## 🛠️ Troubleshooting

### Common Issues - Quick Fixes

```bash
# Fix permission issues
sudo chown -R $(whoami) ~/.ollama && echo "Permissions fixed"

# Clear Ollama cache and restart
rm -rf ~/.ollama/tmp/* && brew services restart ollama && echo "Cache cleared and restarted"

# Check port conflicts
lsof -i :11434 && echo "Port 11434 is in use" || echo "Port 11434 is available"

# Verify Metal support (Apple Silicon)
python3 -c "import torch; print(f'Metal available: {torch.backends.mps.is_available()}')" 2>/dev/null || echo "PyTorch not installed"

# Free up memory
sudo purge && echo "System memory cleared"
```

### Error Diagnosis

```bash
# Check Ollama logs
cat ~/.ollama/logs/server.log | tail -20

# Check system resources
echo "CPU: $(ps -A -o %cpu | awk '{s+=$1} END {printf "%.1f%%", s}')" && echo "RAM: $(vm_stat | awk '/Pages free:/{print $3*4096/1024/1024 " MB free"}')"

# Verify model integrity
ollama list | grep deepseek | while read model _; do echo "Testing $model..." && ollama show "$model" >/dev/null && echo "✓ OK" || echo "✗ FAILED"; done
```

## 🔐 Security Commands

### Security Verification

```bash
# Check network bindings (should only show localhost)
lsof -i | grep ollama && echo "Network connections verified" || echo "No network connections"

# Verify no external connections
netstat -an | grep ESTABLISHED | grep -v "127.0.0.1\|::1" && echo "WARNING: External connections detected" || echo "✓ No external connections"

# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### Lock Down Security

```bash
# Ensure localhost-only access
export OLLAMA_HOST=127.0.0.1:11434 && echo 'export OLLAMA_HOST=127.0.0.1:11434' >> ~/.zshrc && echo "Locked to localhost"

# Set secure file permissions
chmod 750 ~/.ollama && find ~/.ollama -type f -exec chmod 640 {} \; && echo "Permissions secured"
```

## 📋 Model-Specific Commands

### DeepSeek-Coder Commands

```bash
# Quick coding session
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Write a Python class for a binary search tree"

# Code review session
echo "def bubble_sort(arr): 
    for i in range(len(arr)): 
        for j in range(0, len(arr)-i-1): 
            if arr[j] > arr[j+1]: 
                arr[j], arr[j+1] = arr[j+1], arr[j]
Review this code and suggest improvements" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Multi-language code generation
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Write the same quicksort algorithm in Python, JavaScript, and Go"
```

### DeepSeek-Chat Commands

```bash
# General conversation
ollama run deepseek-chat:32b-q4_K_M "Explain quantum computing in simple terms"

# Creative writing
ollama run deepseek-chat:32b-q4_K_M "Write a short story about AI and human collaboration"

# Problem solving
ollama run deepseek-chat:32b-q4_K_M "I need to organize a team meeting for 10 people. What should I consider?"
```

## 🔄 Automation Scripts

### One-Line Automation Setup

```bash
# Create startup script
echo '#!/bin/bash
ollama serve >/dev/null 2>&1 &
sleep 3
echo "DeepSeek ready! Run: ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M"' > ~/start-deepseek.sh && chmod +x ~/start-deepseek.sh && echo "Created ~/start-deepseek.sh"

# Create model switcher
echo '#!/bin/bash
models=($(ollama list | grep deepseek | awk "{print \$1}"))
echo "Available models:" && printf "%s\n" "${models[@]}" && read -p "Enter model number (1-${#models[@]}): " choice && ollama run "${models[$((choice-1))]}"' > ~/switch-model.sh && chmod +x ~/switch-model.sh && echo "Created ~/switch-model.sh"

# Create performance monitor
echo '#!/bin/bash
while true; do clear && echo "DeepSeek Performance Monitor" && ps aux | grep ollama | grep -v grep && echo "" && vm_stat | head -5 && sleep 5; done' > ~/monitor-deepseek.sh && chmod +x ~/monitor-deepseek.sh && echo "Created ~/monitor-deepseek.sh"
```

## 🎯 Quick Use Cases

### Development Workflow

```bash
# Code generation
echo "Create a REST API endpoint for user authentication in Express.js" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Code review
cat your_code.py | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Review this code and suggest improvements:"

# Documentation generation
echo "Generate documentation for this Python function: $(cat function.py)" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M
```

### Learning and Exploration

```bash
# Learn new concepts
ollama run deepseek-chat:32b-q4_K_M "Explain machine learning algorithms with practical examples"

# Get explanations
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Explain this code step by step: $(cat complex_algorithm.py)"

# Practice problems
ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Give me 5 coding challenges for practicing recursion"
```

## 📱 Integration Commands

### IDE Integration

```bash
# VS Code integration (add to settings.json)
echo '{
  "ollama.models": ["deepseek-coder-v2:16b-lite-instruct-q4_K_M"],
  "ollama.endpoint": "http://localhost:11434",
  "ollama.enabled": true
}' | jq '.' || echo "Install VS Code Ollama extension first"

# Vim integration (basic)
echo 'function! AskDeepSeek()
  let prompt = input("Ask DeepSeek: ")
  let response = system("echo \"" . prompt . "\" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M")
  echo response
endfunction
command! DeepSeek call AskDeepSeek()' >> ~/.vimrc && echo "DeepSeek command added to Vim"
```

### Terminal Integration

```bash
# Add alias for quick access
echo 'alias deepseek="ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M"
alias deepseek-chat="ollama run deepseek-chat:32b-q4_K_M"' >> ~/.zshrc && source ~/.zshrc && echo "Aliases added"

# Function for piped input
echo 'ask_deepseek() {
  if [ -p /dev/stdin ]; then
    cat | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "$@"
  else
    ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "$@"
  fi
}' >> ~/.zshrc && source ~/.zshrc && echo "Function added: ask_deepseek"
```

## 📊 Benchmarking Commands

### Performance Benchmarks

```bash
# Simple speed test
time echo "Count from 1 to 10 in Python" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M >/dev/null

# Throughput test
echo "Testing throughput..." && for i in {1..5}; do time echo "Generate Python code example $i" | ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M >/dev/null; done

# Memory benchmark
echo "Memory test:" && vm_stat | grep free && ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M "Generate a complex Python class" >/dev/null && vm_stat | grep free
```

## 🎯 Complete Workflow Examples

### Setup to First Use (3 commands)

```bash
# Complete setup and first run
curl -fsSL https://ollama.ai/install.sh | sh && ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M && echo "Setup complete! Starting chat..." && ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M
```

### Development Session Setup

```bash
# Optimized development environment
export OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_NUM_PARALLEL=1 OMP_NUM_THREADS=8 && ollama serve >/dev/null 2>&1 & && sleep 3 && echo "DeepSeek development environment ready!"
```

### Model Comparison

```bash
# Compare different model sizes
for model in "deepseek-coder:6.7b-instruct-q4_K_M" "deepseek-coder-v2:16b-lite-instruct-q4_K_M"; do echo "Testing $model:"; time echo "Write a quicksort algorithm" | ollama run "$model" >/dev/null; done
```

## 🆘 Emergency Commands

### Quick Recovery

```bash
# Complete reset and restart
pkill ollama && rm -rf ~/.ollama/tmp/* && brew services restart ollama && sleep 5 && ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M && echo "System recovered!"

# Free maximum memory
sudo purge && pkill ollama && sleep 5 && ollama serve & && echo "Memory freed and Ollama restarted"

# Network reset (if API issues)
pkill ollama && sleep 2 && OLLAMA_HOST=127.0.0.1:11434 ollama serve & && echo "Network reset complete"
```

## 📝 Notes

- Replace `deepseek-coder-v2:16b-lite-instruct-q4_K_M` with your preferred model
- Adjust `OMP_NUM_THREADS` based on your CPU core count
- Monitor memory usage with larger models (32B, 67B)
- All commands tested on macOS 13+ with Apple Silicon
- Some commands require `sudo` password for system monitoring

---

## Navigation

| Previous | Home | Back to Top |
|----------|------|-------------|
| [Best Practices and Security](./best-practices-security.md) | [DeepSeek Research](./README.md) | [↑ Quick Reference Commands](#quick-reference-commands) |

---

*Complete command reference for DeepSeek local hosting on macOS*  
*Last updated: January 2025*