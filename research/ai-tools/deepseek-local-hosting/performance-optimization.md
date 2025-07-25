# Performance Optimization

Comprehensive guide to optimizing DeepSeek model performance on macOS systems for maximum speed, efficiency, and resource utilization.

## Hardware Optimization

### Apple Silicon Performance

#### Mac Performance Tiers

| Mac Model | RAM | Unified Memory | GPU Cores | Recommended Models |
|-----------|-----|----------------|-----------|-------------------|
| **MacBook Air M1** | 8-16GB | Shared | 7-8 | DeepSeek-Coder 6.7B |
| **MacBook Pro M1 Pro** | 16-32GB | Shared | 14-16 | DeepSeek-Coder-V2 16B |
| **MacBook Pro M1 Max** | 32-64GB | Shared | 24-32 | DeepSeek-Chat 32B |
| **Mac Studio M1 Ultra** | 64-128GB | Shared | 48-64 | DeepSeek-Chat 67B |
| **Mac Studio M2 Ultra** | 64-192GB | Shared | 60-76 | DeepSeek-V3 (quantized) |

#### Metal Performance Optimization

**Verify Metal Acceleration**:
```bash
# Check Metal support
python3 -c "
import torch
print(f'Metal available: {torch.backends.mps.is_available()}')
print(f'Metal built: {torch.backends.mps.is_built()}')
"

# Check GPU information
system_profiler SPDisplaysDataType | grep -E "(Metal|GPU)"
```

**Enable Metal in Ollama**:
```bash
# Metal is enabled by default on Apple Silicon
# Verify with model info
ollama show deepseek-coder-v2:16b-lite-instruct-q4_K_M --verbose | grep -i metal
```

### Memory Optimization

#### RAM Usage Guidelines

**Model Memory Requirements**:
```bash
# Check current memory usage
vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+):\s+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'

# Estimate model memory usage
# Rule of thumb: Model size × 1.2 = minimum RAM needed
# DeepSeek-Coder-V2 16B Q4_K_M ≈ 9GB file × 1.2 = ~11GB RAM minimum
```

**Optimize Memory Allocation**:
```bash
# Configure Ollama memory settings
export OLLAMA_MAX_VRAM=8192  # 8GB for GPU
export OLLAMA_MAX_LOADED_MODELS=1  # Only keep one model loaded
export OLLAMA_NUM_PARALLEL=1  # Reduce parallel requests

# Add to ~/.zshrc
echo 'export OLLAMA_MAX_LOADED_MODELS=1' >> ~/.zshrc
echo 'export OLLAMA_NUM_PARALLEL=1' >> ~/.zshrc
```

#### Memory Monitoring

```bash
# Real-time memory monitoring script
cat > ~/monitor-memory.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "=== Memory Usage Monitor ==="
  date
  echo ""
  
  # System memory
  vm_stat | head -10
  
  echo ""
  echo "=== Process Memory Usage ==="
  ps aux | grep -E "(ollama|llama)" | grep -v grep
  
  echo ""
  echo "=== GPU Memory (if available) ==="
  system_profiler SPDisplaysDataType | grep -A 3 "Metal"
  
  sleep 3
done
EOF

chmod +x ~/monitor-memory.sh
~/monitor-memory.sh
```

### CPU Optimization

#### Thread Configuration

```bash
# Optimize thread count for your CPU
sysctl hw.ncpu  # Check CPU core count

# Configure optimal threads
export OMP_NUM_THREADS=8  # Set to physical cores (not hyperthreads)
export MKL_NUM_THREADS=8
export OPENBLAS_NUM_THREADS=8

# For Apple Silicon (example M2 Pro - 10 cores)
export OMP_NUM_THREADS=10
```

#### Process Priority

```bash
# Run Ollama with higher priority
sudo nice -n -10 ollama serve

# Or renice running process
sudo renice -n -10 $(pgrep ollama)
```

## Model Optimization

### Quantization Selection

#### Quantization Impact Analysis

| Quantization | File Size | Memory Use | Quality | Speed | Best For |
|-------------|-----------|------------|---------|-------|----------|
| **Q2_K** | ~3GB | ~4GB | ⭐⭐ | ⭐⭐⭐⭐⭐ | Testing, limited RAM |
| **Q4_0** | ~5GB | ~6GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | Balanced, general use |
| **Q4_K_M** | ~5GB | ~6GB | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | **Recommended** |
| **Q5_K_M** | ~6GB | ~7GB | ⭐⭐⭐⭐ | ⭐⭐⭐ | Higher quality |
| **Q6_K** | ~7GB | ~8GB | ⭐⭐⭐⭐⭐ | ⭐⭐ | Best quality |
| **Q8_0** | ~9GB | ~10GB | ⭐⭐⭐⭐⭐ | ⭐⭐ | Near-original quality |

**Recommended Quantizations**:
```bash
# For most users (best balance)
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_K_M

# For high-quality results (if RAM allows)
ollama pull deepseek-coder-v2:16b-lite-instruct-q5_K_M

# For limited RAM systems
ollama pull deepseek-coder-v2:16b-lite-instruct-q4_0

# For maximum quality (64GB+ RAM)
ollama pull deepseek-coder-v2:16b-lite-instruct-q6_K
```

### Model Parameter Tuning

#### Create Optimized Modelfiles

**For Coding Tasks**:
```bash
cat > Modelfile.coding << 'EOF'
FROM deepseek-coder-v2:16b-lite-instruct-q4_K_M

# Optimize for code generation
PARAMETER temperature 0.1        # Low randomness for precise code
PARAMETER top_k 40              # Focus on most likely tokens
PARAMETER top_p 0.9             # Nucleus sampling
PARAMETER repeat_penalty 1.05   # Slight penalty for repetition
PARAMETER num_ctx 8192          # Large context for code files

# System prompt for coding
SYSTEM "You are DeepSeek Coder, an expert programming assistant. Provide clean, efficient, well-commented code. Focus on best practices and explain your reasoning."
EOF

ollama create deepseek-coder-optimized -f Modelfile.coding
```

**For General Chat**:
```bash
cat > Modelfile.chat << 'EOF'
FROM deepseek-chat:32b-q4_K_M

# Optimize for conversation
PARAMETER temperature 0.7        # More creative responses
PARAMETER top_k 50              # Broader token selection
PARAMETER top_p 0.95            # Higher nucleus sampling
PARAMETER repeat_penalty 1.1    # Prevent repetitive responses
PARAMETER num_ctx 4096          # Standard context length

SYSTEM "You are DeepSeek, a helpful, harmless, and honest AI assistant."
EOF

ollama create deepseek-chat-optimized -f Modelfile.chat
```

### Context Length Optimization

#### Dynamic Context Sizing

```bash
# Test different context lengths
contexts=(1024 2048 4096 8192 16384)

for ctx in "${contexts[@]}"; do
  echo "Testing context length: $ctx"
  time ollama run deepseek-coder-v2:16b-lite-instruct-q4_K_M \
    --num-ctx $ctx \
    "Write a Python class with multiple methods" >/dev/null
done
```

## Software Optimization

### Ollama Optimization

#### Configuration File

```bash
# Create Ollama configuration directory
mkdir -p ~/.ollama

# Create optimized configuration
cat > ~/.ollama/config.json << 'EOF'
{
  "max_vram": 8192,
  "max_loaded_models": 1,
  "num_parallel": 1,
  "keep_alive": 300,
  "host": "127.0.0.1",
  "port": 11434,
  "origins": ["*"],
  "num_ctx": 4096,
  "num_batch": 512,
  "num_gqa": 1,
  "num_gpu": 1,
  "main_gpu": 0,
  "low_vram": false,
  "f16_kv": true,
  "vocab_only": false,
  "use_mmap": true,
  "use_mlock": false,
  "embedding_only": false,
  "numa": false
}
EOF
```

#### Service Optimization

```bash
# Create optimized launch script
cat > ~/launch-ollama-optimized.sh << 'EOF'
#!/bin/bash

# Set environment variables for optimal performance
export OLLAMA_MAX_VRAM=8192
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_KEEP_ALIVE=5m
export OLLAMA_HOST=0.0.0.0:11434

# Set system optimization
export OMP_NUM_THREADS=8
export MALLOC_ARENA_MAX=4

# Launch with high priority
echo "Starting Ollama with optimized settings..."
sudo nice -n -10 ollama serve
EOF

chmod +x ~/launch-ollama-optimized.sh
```

### System-Level Optimization

#### macOS Performance Settings

```bash
# Disable swap file writing (SSD longevity)
sudo sysctl vm.swapusage=0

# Increase file descriptor limits
ulimit -n 8192

# Optimize network buffer sizes
sudo sysctl -w net.inet.tcp.sendspace=1048576
sudo sysctl -w net.inet.tcp.recvspace=1048576

# Make changes persistent
echo 'kern.maxfiles=65536' | sudo tee -a /etc/sysctl.conf
echo 'kern.maxfilesperproc=32768' | sudo tee -a /etc/sysctl.conf
```

#### Thermal Management

```bash
# Monitor CPU temperature
sudo powermetrics --samplers smc -n 1 | grep -i temp

# Create thermal monitoring script
cat > ~/monitor-thermal.sh << 'EOF'
#!/bin/bash
while true; do
  temp=$(sudo powermetrics --samplers smc -n 1 2>/dev/null | grep "CPU die temperature" | awk '{print $4}')
  if [[ -n "$temp" ]]; then
    echo "$(date): CPU Temperature: ${temp}°C"
    if (( $(echo "$temp > 85" | bc -l) )); then
      echo "WARNING: High temperature detected!"
    fi
  fi
  sleep 10
done
EOF

chmod +x ~/monitor-thermal.sh
```

## Benchmark Testing

### Performance Testing Suite

```bash
# Create comprehensive benchmark script
cat > ~/benchmark-deepseek.sh << 'EOF'
#!/bin/bash

MODEL="deepseek-coder-v2:16b-lite-instruct-q4_K_M"
RESULTS_FILE="benchmark_results_$(date +%Y%m%d_%H%M%S).txt"

echo "DeepSeek Performance Benchmark - $(date)" > $RESULTS_FILE
echo "Model: $MODEL" >> $RESULTS_FILE
echo "System: $(uname -a)" >> $RESULTS_FILE
echo "RAM: $(system_profiler SPHardwareDataType | grep Memory | awk '{print $2" "$3}')" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Test 1: Simple code generation
echo "=== Test 1: Simple Code Generation ===" >> $RESULTS_FILE
start_time=$(date +%s.%N)
result=$(echo "Write a Python function to calculate factorial" | ollama run $MODEL --verbose 2>&1)
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
echo "Duration: ${duration}s" >> $RESULTS_FILE
echo "Output length: $(echo "$result" | wc -c) characters" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Test 2: Complex algorithm
echo "=== Test 2: Complex Algorithm ===" >> $RESULTS_FILE
start_time=$(date +%s.%N)
result=$(echo "Implement a binary search tree with insert, delete, and search operations in Python" | ollama run $MODEL --verbose 2>&1)
end_time=$(date +%s.%N)
duration=$(echo "$end_time - $start_time" | bc)
echo "Duration: ${duration}s" >> $RESULTS_FILE
echo "Output length: $(echo "$result" | wc -c) characters" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Test 3: Memory usage test
echo "=== Test 3: Memory Usage ===" >> $RESULTS_FILE
before_mem=$(vm_stat | awk '/Pages free:/ {print $3}' | tr -d '.')
echo "Starting memory test with model: $MODEL"
ollama run $MODEL "Generate a large Python class with 10 methods" >/dev/null 2>&1 &
sleep 10
after_mem=$(vm_stat | awk '/Pages free:/ {print $3}' | tr -d '.')
mem_used=$((($before_mem - $after_mem) * 4096 / 1024 / 1024))  # Convert to MB
echo "Memory used: ${mem_used}MB" >> $RESULTS_FILE
pkill -f "ollama run"

echo "Benchmark complete. Results saved to: $RESULTS_FILE"
cat $RESULTS_FILE
EOF

chmod +x ~/benchmark-deepseek.sh
~/benchmark-deepseek.sh
```

### Load Testing

```bash
# Concurrent request testing
cat > ~/load-test.sh << 'EOF'
#!/bin/bash

MODEL="deepseek-coder-v2:16b-lite-instruct-q4_K_M"
CONCURRENT_REQUESTS=3
TEST_DURATION=60  # seconds

echo "Starting load test with $CONCURRENT_REQUESTS concurrent requests..."

# Function to send single request
send_request() {
  local id=$1
  local start_time=$(date +%s.%N)
  
  curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$MODEL\",
      \"prompt\": \"Write a Python function to sort array using method $id\",
      \"stream\": false
    }" > /dev/null
    
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)
  echo "Request $id completed in ${duration}s"
}

# Start concurrent requests
for i in $(seq 1 $CONCURRENT_REQUESTS); do
  send_request $i &
done

wait
echo "Load test completed"
EOF

chmod +x ~/load-test.sh
```

## Monitoring and Analytics

### Performance Metrics Collection

```bash
# Create metrics collection script
cat > ~/collect-metrics.sh << 'EOF'
#!/bin/bash

METRICS_FILE="metrics_$(date +%Y%m%d_%H%M%S).log"
DURATION=${1:-300}  # Default 5 minutes

echo "Collecting metrics for ${DURATION} seconds..."
echo "Timestamp,CPU%,Memory_MB,GPU_Temp,Tokens_Per_Sec" > $METRICS_FILE

start_time=$(date +%s)
while true; do
  current_time=$(date +%s)
  if [ $((current_time - start_time)) -gt $DURATION ]; then
    break
  fi
  
  # Collect metrics
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
  memory_mb=$(ps aux | awk '/ollama/ {sum+=$6} END {print sum/1024}')
  gpu_temp=$(sudo powermetrics --samplers smc -n 1 2>/dev/null | grep "GPU die temperature" | awk '{print $4}' | tr -d '°C')
  
  echo "$timestamp,$cpu_usage,$memory_mb,$gpu_temp," >> $METRICS_FILE
  
  sleep 5
done

echo "Metrics collected in: $METRICS_FILE"
EOF

chmod +x ~/collect-metrics.sh
```

### Real-time Dashboard

```bash
# Install dependencies for dashboard
brew install python3
pip3 install matplotlib pandas

# Create dashboard script
cat > ~/performance-dashboard.py << 'EOF'
#!/usr/bin/env python3
import matplotlib.pyplot as plt
import pandas as pd
import time
import subprocess
import os
from datetime import datetime

def collect_system_metrics():
    """Collect real-time system metrics"""
    # CPU usage
    cpu_cmd = "ps -A -o %cpu | awk '{s+=$1} END {print s}'"
    cpu_usage = float(subprocess.getoutput(cpu_cmd) or 0)
    
    # Memory usage for Ollama
    mem_cmd = "ps aux | awk '/ollama/ {sum+=$6} END {print sum/1024}'"
    memory_mb = float(subprocess.getoutput(mem_cmd) or 0)
    
    return {
        'timestamp': datetime.now(),
        'cpu_usage': cpu_usage,
        'memory_mb': memory_mb
    }

def create_dashboard():
    """Create real-time performance dashboard"""
    plt.ion()  # Enable interactive mode
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    timestamps = []
    cpu_data = []
    memory_data = []
    
    for _ in range(60):  # Run for 60 iterations
        metrics = collect_system_metrics()
        
        timestamps.append(metrics['timestamp'])
        cpu_data.append(metrics['cpu_usage'])
        memory_data.append(metrics['memory_mb'])
        
        # Keep only last 20 data points
        if len(timestamps) > 20:
            timestamps = timestamps[-20:]
            cpu_data = cpu_data[-20:]
            memory_data = memory_data[-20:]
        
        # Clear and update plots
        ax1.clear()
        ax2.clear()
        
        ax1.plot(timestamps, cpu_data, 'b-', marker='o')
        ax1.set_title('CPU Usage (%)')
        ax1.set_ylabel('Percentage')
        ax1.grid(True)
        
        ax2.plot(timestamps, memory_data, 'r-', marker='s')
        ax2.set_title('Memory Usage (MB)')
        ax2.set_ylabel('Megabytes')
        ax2.grid(True)
        
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.pause(5)  # Update every 5 seconds
    
    plt.ioff()
    plt.show()

if __name__ == "__main__":
    print("Starting DeepSeek Performance Dashboard...")
    create_dashboard()
EOF

chmod +x ~/performance-dashboard.py
```

## Optimization Verification

### Before/After Comparison

```bash
# Create optimization test script
cat > ~/test-optimization.sh << 'EOF'
#!/bin/bash

MODEL="deepseek-coder-v2:16b-lite-instruct-q4_K_M"
TEST_PROMPT="Write a Python class for a binary tree with insert, search, and delete methods"

echo "=== DeepSeek Optimization Test ==="
echo "Model: $MODEL"
echo "Test prompt: $TEST_PROMPT"
echo ""

# Test 1: Default settings
echo "Testing with default settings..."
unset OLLAMA_MAX_VRAM OLLAMA_NUM_PARALLEL OMP_NUM_THREADS

start_time=$(date +%s.%N)
result=$(echo "$TEST_PROMPT" | ollama run $MODEL 2>/dev/null)
end_time=$(date +%s.%N)
default_duration=$(echo "$end_time - $start_time" | bc)

echo "Default performance: ${default_duration}s"
echo "Output length: $(echo "$result" | wc -c) characters"
echo ""

# Test 2: Optimized settings
echo "Testing with optimized settings..."
export OLLAMA_MAX_VRAM=8192
export OLLAMA_NUM_PARALLEL=1
export OMP_NUM_THREADS=8

start_time=$(date +%s.%N)
result=$(echo "$TEST_PROMPT" | ollama run $MODEL 2>/dev/null)
end_time=$(date +%s.%N)
optimized_duration=$(echo "$end_time - $start_time" | bc)

echo "Optimized performance: ${optimized_duration}s"
echo "Output length: $(echo "$result" | wc -c) characters"
echo ""

# Calculate improvement
improvement=$(echo "scale=2; (($default_duration - $optimized_duration) / $default_duration) * 100" | bc)
echo "Performance improvement: ${improvement}%"
EOF

chmod +x ~/test-optimization.sh
```

## Troubleshooting Performance Issues

### Common Performance Problems

#### Slow Generation Speed

```bash
# Check if model is using GPU acceleration
ollama ps | grep -i metal

# Verify sufficient RAM
vm_stat | grep "Pages free"

# Check CPU usage during generation
top -pid $(pgrep ollama) -l 5

# Test with smaller model
ollama pull deepseek-coder:6.7b-instruct-q4_K_M
```

#### High Memory Usage

```bash
# Monitor memory growth over time
while true; do
  ps aux | awk '/ollama/ {print strftime("%Y-%m-%d %H:%M:%S"), $6/1024 " MB"}'
  sleep 10
done

# Restart Ollama to clear memory leaks
pkill ollama
sleep 5
ollama serve &
```

#### Thermal Throttling

```bash
# Monitor CPU frequency during load
while true; do
  freq=$(sysctl -n hw.cpufrequency_max)
  temp=$(sudo powermetrics --samplers smc -n 1 2>/dev/null | grep "CPU die temperature" | awk '{print $4}')
  echo "$(date): Freq: ${freq}Hz, Temp: ${temp}"
  sleep 5
done

# If throttling occurs, reduce concurrent requests
export OLLAMA_NUM_PARALLEL=1
```

## Best Practices Summary

### Hardware Recommendations

1. **16GB+ RAM minimum** for DeepSeek models
2. **Apple Silicon preferred** for Metal acceleration  
3. **SSD storage** for fast model loading
4. **Good cooling** to prevent thermal throttling

### Software Configuration

1. **Use Q4_K_M quantization** for best balance
2. **Limit parallel requests** to 1-2 maximum
3. **Set appropriate context length** (4096-8192)
4. **Monitor memory usage** regularly
5. **Use optimized Modelfiles** for specific tasks

### Performance Monitoring

1. **Benchmark before optimization**
2. **Monitor key metrics** (CPU, memory, temperature)
3. **Test different configurations**
4. **Document performance improvements**

---

## Navigation

| Previous | Home | Next |
|----------|------|------|
| [macOS Installation Guide](./macos-installation-guide.md) | [DeepSeek Research](./README.md) | [Best Practices and Security](./best-practices-security.md) |

---

*Performance optimization guide tested on Apple Silicon and Intel Macs*  
*Sources: Ollama documentation, Apple Developer guides, performance benchmarks*