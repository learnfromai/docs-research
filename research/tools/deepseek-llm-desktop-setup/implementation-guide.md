# Implementation Guide: Complete DeepSeek LLM Desktop Setup

## 🎯 Step-by-Step Implementation Roadmap

### Phase 1: Hardware Assembly and System Preparation

#### Week 1: Hardware Procurement and Assembly

**Day 1-2: Component Procurement**
1. **Order Components** based on chosen tier from [Hardware Specifications](./hardware-specifications.md)
2. **Verify Compatibility** using manufacturer QVL lists
3. **Plan Assembly Workspace** with anti-static precautions

**Recommended Build Order:**
```
1. Install CPU in motherboard
2. Install RAM modules (slots 2&4 for dual channel)
3. Mount CPU cooler
4. Install motherboard in case
5. Install power supply
6. Install storage devices
7. Install graphics card last
8. Connect all power and data cables
9. Initial power-on test
```

**Day 3-4: System Assembly**
```bash
# Pre-assembly checklist
- [ ] Anti-static wrist strap or mat
- [ ] Phillips head screwdrivers
- [ ] Thermal paste (if not pre-applied)
- [ ] Cable ties for management
- [ ] Motherboard manual for connector reference
```

**Day 5-7: Initial System Testing**
```bash
# BIOS/UEFI Configuration
1. Enable XMP/DOCP for RAM
2. Set boot priority (USB first for OS installation)
3. Enable AMD-V virtualization
4. Verify all components detected
5. Monitor temperatures under load
```

#### Week 2: Operating System Installation and Configuration

**Day 1-2: Ubuntu 22.04 LTS Installation**

Follow the detailed steps in [Operating System Setup](./operating-system-setup.md):

1. **Create Installation Media**
```bash
# Download and verify ISO
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso
sha256sum ubuntu-22.04.3-desktop-amd64.iso
```

2. **BIOS Configuration for Linux**
```
- Set UEFI mode (not Legacy)
- Disable Secure Boot temporarily
- Enable IOMMU support
- Set PCIe to Gen 4.0 for NVMe
```

3. **Installation Configuration**
```
Partition Scheme:
/boot/efi    512MB
/boot       1GB
/           50GB
/home       100GB
/opt        1.8TB (for models)
swap        32GB (file-based)
```

**Day 3-4: Post-Installation System Setup**
```bash
# Essential updates
sudo apt update && sudo apt upgrade -y

# Install development tools
sudo apt install -y build-essential git curl wget vim htop

# Install NVIDIA drivers
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt install -y nvidia-driver-535

# Reboot and verify
sudo reboot
nvidia-smi
```

**Day 5-7: System Optimization**
```bash
# Kernel parameter optimization
sudo nano /etc/default/grub
# Add: GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt"
sudo update-grub

# Memory optimization
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf

# GPU persistence
sudo systemctl enable nvidia-persistenced
```

### Phase 2: LLM Environment Setup

#### Week 3: Development Environment Configuration

**Day 1-2: Python Environment Setup**
```bash
# Install pyenv for version management
curl https://pyenv.run | bash

# Add to shell configuration
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Python 3.11
pyenv install 3.11.6
pyenv global 3.11.6

# Create virtual environment
python -m venv ~/venv/deepseek-llm
source ~/venv/deepseek-llm/bin/activate
```

**Day 3-4: Docker and Container Setup**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker

# Test GPU in container
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi
```

**Day 5-7: Framework Installation**
```bash
# Activate virtual environment
source ~/venv/deepseek-llm/bin/activate

# Install PyTorch with CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Install Transformers ecosystem
pip install transformers accelerate bitsandbytes einops sentencepiece

# Install serving frameworks
pip install vllm fastapi uvicorn gradio streamlit

# Verify installation
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
python -c "import transformers; print('Transformers OK')"
python -c "import vllm; print('vLLM OK')"
```

#### Week 4: DeepSeek Model Deployment

**Day 1-2: Ollama Setup (Beginner-Friendly Path)**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Configure Ollama
sudo mkdir -p /etc/ollama
sudo tee /etc/ollama/config.yaml << EOF
models_path: "/opt/models/ollama"
host: "0.0.0.0:11434"
gpu_layers: -1
num_ctx: 8192
temperature: 0.2
EOF

# Create model directory
sudo mkdir -p /opt/models/ollama
sudo chown ollama:ollama /opt/models/ollama

# Start and enable service
sudo systemctl enable ollama
sudo systemctl start ollama

# Install DeepSeek models
ollama pull deepseek-coder:6.7b
ollama pull deepseek-coder:33b  # If sufficient hardware
```

**Day 3-4: Performance Optimization Setup (Advanced Path)**
```bash
# Create model storage
sudo mkdir -p /opt/models/deepseek
sudo chown $USER:$USER /opt/models/deepseek

# Download models using HuggingFace Hub
pip install huggingface_hub
huggingface-cli download deepseek-ai/deepseek-coder-6.7b-base --local-dir /opt/models/deepseek/deepseek-coder-6.7b

# Create vLLM startup script
cat << 'EOF' > ~/start-deepseek-vllm.sh
#!/bin/bash
MODEL_PATH="/opt/models/deepseek/deepseek-coder-6.7b"
source ~/venv/deepseek-llm/bin/activate

python -m vllm.entrypoints.openai.api_server \
    --model $MODEL_PATH \
    --host 0.0.0.0 \
    --port 8000 \
    --gpu-memory-utilization 0.85 \
    --max-num-seqs 256 \
    --dtype half
EOF

chmod +x ~/start-deepseek-vllm.sh
```

**Day 5-7: Testing and Validation**
```bash
# Performance testing
cat << 'EOF' > ~/test_deepseek_performance.py
import requests
import time
import json

def test_api_endpoint(endpoint="http://localhost:11434/api/generate"):
    test_prompts = [
        "def fibonacci(n):",
        "class BinarySearchTree:",
        "# Create a REST API using FastAPI\n"
    ]
    
    for prompt in test_prompts:
        print(f"Testing: {prompt}")
        start_time = time.time()
        
        payload = {
            "model": "deepseek-coder:6.7b",
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0.2, "num_ctx": 2048}
        }
        
        response = requests.post(endpoint, json=payload)
        response_time = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            print(f"  Time: {response_time:.2f}s")
            print(f"  Response: {result.get('response', 'N/A')[:100]}...")
        else:
            print(f"  Error: {response.status_code}")
        print()

if __name__ == "__main__":
    test_api_endpoint()
EOF

python ~/test_deepseek_performance.py
```

### Phase 3: Coding Agent Integration

#### Week 5: Development Tool Integration

**Day 1-2: VS Code and Cursor Setup**
```bash
# Install VS Code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

sudo apt update
sudo apt install -y code

# Install Cursor (AI-focused editor)
wget -O cursor.deb https://downloader.cursor.sh/linux/appImage/x64
sudo dpkg -i cursor.deb

# Configure local LLM endpoints
code --install-extension continue.continue
# Configure Continue extension to use local endpoint
```

**Day 3-4: API Integration Setup**
```bash
# Create unified API gateway
cat << 'EOF' > ~/deepseek_gateway.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import json
from typing import List, Optional

app = FastAPI(title="DeepSeek Gateway", version="1.0.0")

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str = "deepseek-coder"
    messages: List[ChatMessage]
    temperature: float = 0.2
    max_tokens: int = 1000

class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[dict]

# Ollama backend adapter
def call_ollama(messages, model="deepseek-coder:6.7b"):
    # Convert chat messages to single prompt
    prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])
    prompt += "\nassistant: "
    
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2}
    }
    
    response = requests.post("http://localhost:11434/api/generate", json=payload)
    response.raise_for_status()
    
    return response.json()["response"]

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def create_chat_completion(request: ChatCompletionRequest):
    try:
        response_content = call_ollama(request.messages)
        
        return ChatCompletionResponse(
            id=f"chatcmpl-{int(time.time())}",
            created=int(time.time()),
            model=request.model,
            choices=[{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_content
                },
                "finish_reason": "stop"
            }]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
EOF

# Install dependencies and start gateway
pip install fastapi uvicorn
python ~/deepseek_gateway.py &
```

**Day 5-7: Cline.bot Integration**
```bash
# Install Node.js for Cline
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Create Cline configuration
mkdir -p ~/.config/cline
cat << 'EOF' > ~/.config/cline/config.json
{
  "apiEndpoint": "http://localhost:8001/v1",
  "model": "deepseek-coder",
  "temperature": 0.2,
  "maxTokens": 2000,
  "systemPrompt": "You are an expert software engineer. Provide clear, efficient code solutions with explanations."
}
EOF
```

### Phase 4: Production Setup and Optimization

#### Week 6: Performance Tuning and Monitoring

**Day 1-2: System Monitoring Setup**
```bash
# Install monitoring tools
sudo apt install -y htop btop nvtop iotop nethogs

# Create comprehensive monitoring dashboard
cat << 'EOF' > ~/monitor_dashboard.py
import psutil
import subprocess
import time
import curses
from datetime import datetime

def get_gpu_info():
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total', '--format=csv,noheader,nounits'], 
                              capture_output=True, text=True)
        return result.stdout.strip().split('\n')
    except:
        return ["GPU info unavailable"]

def get_deepseek_processes():
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'cmdline']):
        try:
            if any(keyword in ' '.join(proc.info['cmdline']) for keyword in ['ollama', 'vllm', 'deepseek']):
                processes.append(proc.info)
        except:
            pass
    return processes

def main(stdscr):
    curses.curs_set(0)  # Hide cursor
    stdscr.nodelay(1)   # Non-blocking input
    
    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()
        
        # Header
        stdscr.addstr(0, 0, f"DeepSeek System Monitor - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        stdscr.addstr(1, 0, "=" * min(width-1, 80))
        
        row = 3
        
        # System Info
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        
        stdscr.addstr(row, 0, f"CPU Usage: {cpu_percent:.1f}%")
        row += 1
        stdscr.addstr(row, 0, f"RAM Usage: {memory.percent:.1f}% ({memory.used // (1024**3):.1f}GB / {memory.total // (1024**3):.1f}GB)")
        row += 2
        
        # GPU Info
        stdscr.addstr(row, 0, "GPU Status:")
        row += 1
        for gpu_line in get_gpu_info():
            if len(gpu_line.strip()) > 0:
                stdscr.addstr(row, 2, gpu_line)
                row += 1
        row += 1
        
        # DeepSeek Processes
        stdscr.addstr(row, 0, "DeepSeek Processes:")
        row += 1
        processes = get_deepseek_processes()
        for proc in processes[:5]:  # Show top 5
            stdscr.addstr(row, 2, f"PID: {proc['pid']} | CPU: {proc['cpu_percent']:.1f}% | MEM: {proc['memory_percent']:.1f}% | {proc['name']}")
            row += 1
            if row >= height - 2:
                break
        
        stdscr.addstr(height-1, 0, "Press 'q' to quit")
        stdscr.refresh()
        
        # Check for quit
        key = stdscr.getch()
        if key == ord('q'):
            break
        
        time.sleep(1)

if __name__ == "__main__":
    curses.wrapper(main)
EOF

# Make executable and create shortcut
chmod +x ~/monitor_dashboard.py
echo "alias deepmon='python3 ~/monitor_dashboard.py'" >> ~/.bashrc
```

**Day 3-4: Performance Optimization**
```bash
# CPU governor optimization
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# GPU performance mode
nvidia-smi -pm 1
nvidia-smi -pl 400  # Adjust power limit as needed

# I/O scheduler optimization for NVMe
echo 'none' | sudo tee /sys/block/nvme*/queue/scheduler

# Create performance profile script
cat << 'EOF' > ~/optimize_for_llm.sh
#!/bin/bash
echo "Applying LLM performance optimizations..."

# CPU performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# GPU performance
nvidia-smi -pm 1
nvidia-smi -pl 400

# Memory optimization
echo 1 | sudo tee /proc/sys/vm/drop_caches
echo 10 | sudo tee /proc/sys/vm/swappiness

# I/O optimization
for disk in /sys/block/nvme*; do
    echo none | sudo tee $disk/queue/scheduler
    echo 2 | sudo tee $disk/queue/rq_affinity
done

echo "Optimizations applied!"
EOF

chmod +x ~/optimize_for_llm.sh
```

**Day 5-7: Automated Deployment Scripts**
```bash
# Create comprehensive startup script
cat << 'EOF' > ~/start_deepseek_stack.sh
#!/bin/bash

# Configuration
LOG_DIR="$HOME/logs/deepseek"
mkdir -p $LOG_DIR

# Function to check if service is running
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo "✓ $1 is running"
        return 0
    else
        echo "✗ $1 is not running"
        return 1
    fi
}

# Apply system optimizations
echo "Applying system optimizations..."
~/optimize_for_llm.sh

# Start Ollama service
echo "Starting Ollama service..."
sudo systemctl start ollama
sleep 5

if check_service "ollama"; then
    echo "Ollama started successfully"
else
    echo "Failed to start Ollama"
    exit 1
fi

# Start API gateway
echo "Starting API gateway..."
source ~/venv/deepseek-llm/bin/activate
nohup python ~/deepseek_gateway.py > $LOG_DIR/gateway.log 2>&1 &
sleep 3

if check_service "deepseek_gateway.py"; then
    echo "API Gateway started successfully"
else
    echo "Failed to start API Gateway"
fi

# Test endpoints
echo "Testing endpoints..."
sleep 5

# Test Ollama
if curl -s http://localhost:11434/api/version > /dev/null; then
    echo "✓ Ollama API responsive"
else
    echo "✗ Ollama API not responding"
fi

# Test Gateway
if curl -s http://localhost:8001/docs > /dev/null; then
    echo "✓ Gateway API responsive"
else
    echo "✗ Gateway API not responding"
fi

echo "DeepSeek stack startup complete!"
echo "Logs available in: $LOG_DIR"
echo "Monitor with: ~/monitor_dashboard.py"
EOF

chmod +x ~/start_deepseek_stack.sh

# Create systemd service for auto-start
sudo tee /etc/systemd/system/deepseek-stack.service << EOF
[Unit]
Description=DeepSeek LLM Stack
After=network.target

[Service]
Type=oneshot
User=$USER
ExecStart=$HOME/start_deepseek_stack.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable deepseek-stack.service
```

## 🎯 Validation and Testing Checklist

### System Validation Steps

```bash
# Complete system validation script
cat << 'EOF' > ~/validate_deepseek_setup.sh
#!/bin/bash

echo "DeepSeek LLM Setup Validation"
echo "============================="

# Hardware validation
echo "1. Hardware Check:"
echo "   CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "   RAM: $(free -h | grep 'Mem:' | awk '{print $2}')"
echo "   GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader)"

# Software validation
echo -e "\n2. Software Check:"
echo "   OS: $(lsb_release -d | cut -d':' -f2 | xargs)"
echo "   Kernel: $(uname -r)"
echo "   NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
echo "   CUDA: $(nvcc --version 2>/dev/null | grep 'release' | awk '{print $6}' | cut -d',' -f1 || echo 'Not found')"

# Service validation
echo -e "\n3. Service Check:"
systemctl is-active ollama >/dev/null 2>&1 && echo "   ✓ Ollama service active" || echo "   ✗ Ollama service inactive"
pgrep -f "deepseek_gateway.py" >/dev/null 2>&1 && echo "   ✓ API Gateway running" || echo "   ✗ API Gateway not running"

# API validation
echo -e "\n4. API Test:"
if curl -s http://localhost:11434/api/version >/dev/null; then
    echo "   ✓ Ollama API responding"
else
    echo "   ✗ Ollama API not responding"
fi

if curl -s http://localhost:8001/docs >/dev/null; then
    echo "   ✓ Gateway API responding"
else
    echo "   ✗ Gateway API not responding"
fi

# Model validation
echo -e "\n5. Model Test:"
MODEL_TEST=$(curl -s -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-coder:6.7b","prompt":"def hello():","stream":false}' \
  | jq -r '.response' 2>/dev/null)

if [ ! -z "$MODEL_TEST" ] && [ "$MODEL_TEST" != "null" ]; then
    echo "   ✓ Model inference working"
    echo "   Sample output: ${MODEL_TEST:0:50}..."
else
    echo "   ✗ Model inference failed"
fi

echo -e "\n6. Performance Test:"
python3 -c "
import time
import requests
import json

start_time = time.time()
try:
    response = requests.post('http://localhost:11434/api/generate', 
                           json={'model': 'deepseek-coder:6.7b', 'prompt': 'def test():', 'stream': False})
    if response.status_code == 200:
        end_time = time.time()
        result = response.json()
        print(f'   ✓ Response time: {end_time - start_time:.2f}s')
        print(f'   Generated tokens: {len(result.get(\"response\", \"\").split())} words')
    else:
        print('   ✗ API request failed')
except Exception as e:
    print(f'   ✗ Performance test failed: {e}')
"

echo -e "\nValidation complete!"
EOF

chmod +x ~/validate_deepseek_setup.sh
~/validate_deepseek_setup.sh
```

## 🚀 Success Criteria

### Performance Benchmarks
- **Response Time**: <3 seconds for simple code generation tasks
- **Throughput**: >15 tokens/second sustained performance
- **Memory Usage**: <80% GPU VRAM utilization
- **Availability**: >99% uptime for local inference server

### Integration Success
- **VS Code Integration**: Working Continue extension with local endpoint
- **API Compatibility**: OpenAI-compatible endpoints responding correctly
- **Development Workflow**: Natural language to code generation working seamlessly

### System Stability
- **Thermal Management**: CPU <85°C, GPU <80°C under sustained load
- **Power Consumption**: Within PSU specifications
- **Error Rates**: <1% failed inference requests

---

**Previous:** [DeepSeek Installation Guide](./deepseek-installation-guide.md) | **Next:** [Performance Optimization](./performance-optimization.md)