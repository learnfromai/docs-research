# Troubleshooting Guide: DeepSeek LLM Desktop Setup

## 🔧 Hardware Issues

### CPU-Related Problems

#### High CPU Temperatures (>85°C)
**Symptoms:**
- CPU throttling during inference
- Reduced performance under sustained load
- System instability or unexpected shutdowns

**Diagnosis:**
```bash
# Check CPU temperature
sensors | grep -A 3 "Tctl\|Package"

# Monitor temperature during load
watch -n 1 'sensors | grep "Tctl\|Package"'

# Check thermal throttling
dmesg | grep -i "thermal\|throttl"

# Verify CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Solutions:**
```bash
# 1. Check thermal paste application
# Physical inspection required - reapply if needed

# 2. Verify cooler mounting
# Ensure proper contact and mounting pressure

# 3. Adjust CPU power limits
echo 95 | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq

# 4. Improve case airflow
# Add/reposition case fans for better airflow

# 5. Reduce CPU voltage (undervolting)
# Use tools like ryzenadj for Ryzen CPUs
sudo ryzenadj --tctl-temp=85 --stapm-limit=65000 --fast-limit=75000
```

#### Memory Compatibility Issues
**Symptoms:**
- System fails to POST with new RAM
- Random crashes or blue screens
- Memory not running at rated speeds

**Diagnosis:**
```bash
# Check detected memory
sudo dmidecode --type memory | grep -E "Size|Speed|Type"

# Test memory stability
sudo apt install memtester
sudo memtester 1G 1  # Test 1GB for 1 pass

# Check memory speed
sudo lshw -class memory | grep -E "clock|width"

# Verify XMP/DOCP profile
sudo dmidecode -t memory | grep -E "Configured Clock Speed"
```

**Solutions:**
```bash
# 1. Enable XMP/DOCP in BIOS
# Access BIOS and enable memory profile

# 2. Manual memory timing configuration
# Set memory speed, timings, and voltage manually

# 3. Test single memory stick
# Boot with one stick to isolate faulty module

# 4. Check motherboard QVL
# Verify memory is on motherboard's qualified vendor list

# 5. Update BIOS
# Latest BIOS often improves memory compatibility
```

### GPU-Related Problems

#### NVIDIA Driver Issues
**Symptoms:**
- `nvidia-smi` command not found
- CUDA initialization failures
- Poor inference performance

**Diagnosis:**
```bash
# Check if NVIDIA GPU is detected
lspci | grep -i nvidia

# Check driver installation
nvidia-smi
cat /proc/driver/nvidia/version

# Check CUDA installation
nvcc --version
python -c "import torch; print(torch.cuda.is_available())"

# Check GPU temperature and power
nvidia-smi -q -d TEMPERATURE,POWER
```

**Solutions:**
```bash
# 1. Reinstall NVIDIA drivers
sudo apt purge nvidia-* libnvidia-*
sudo apt autoremove
sudo apt install nvidia-driver-535  # or latest version

# 2. Install CUDA toolkit
sudo apt install nvidia-cuda-toolkit

# 3. Verify NVIDIA container runtime
docker run --rm --gpus all nvidia/cuda:11.8-base nvidia-smi

# 4. Reset GPU settings
nvidia-smi -r  # Reset GPU
sudo systemctl restart nvidia-persistenced

# 5. Check power supply adequacy
# Ensure PSU can handle GPU power requirements
```

#### GPU Overheating (>80°C)
**Symptoms:**
- GPU thermal throttling
- Reduced inference performance
- Artifacts or crashes during inference

**Diagnosis:**
```bash
# Monitor GPU temperature continuously
watch -n 1 'nvidia-smi --query-gpu=temperature.gpu,power.draw,clocks.gr --format=csv,noheader'

# Check thermal throttling
nvidia-smi -q | grep -A 3 "Clocks Throttle Reasons"

# Monitor GPU clocks under load
nvidia-smi dmon -s puctv -i 0
```

**Solutions:**
```bash
# 1. Increase fan speed
nvidia-smi -i 0 -pl 80  # Reduce power limit to 80%

# 2. Custom fan curve (if supported)
# Use MSI Afterburner or similar tools

# 3. Improve case ventilation
# Ensure adequate airflow over GPU

# 4. Undervolt GPU
# Use tools like MSI Afterburner to reduce voltage

# 5. Clean GPU cooler
# Remove dust from heatsink and fans
```

## 💾 Software Issues

### Operating System Problems

#### Ubuntu Boot Issues After Installation
**Symptoms:**
- System fails to boot after installation
- GRUB menu doesn't appear
- Kernel panic on boot

**Diagnosis:**
```bash
# Boot from live USB to troubleshoot

# Check GRUB installation
sudo mount /dev/nvme0n1p3 /mnt  # Replace with root partition
sudo mount /dev/nvme0n1p2 /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot/efi
sudo chroot /mnt

# Check GRUB configuration
update-grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi
```

**Solutions:**
```bash
# 1. Repair GRUB installation
sudo chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu
update-grub
exit

# 2. Check UEFI boot order
# Access BIOS and verify Ubuntu is in boot priority

# 3. Disable Secure Boot temporarily
# May be causing boot issues with custom kernels

# 4. Boot with different kernel parameters
# Add nomodeset to GRUB command line temporarily
```

#### Python Environment Conflicts
**Symptoms:**
- Import errors for AI/ML packages
- Version conflicts between packages
- Virtual environment not activating

**Diagnosis:**
```bash
# Check Python version and location
which python3
python3 --version

# Check installed packages
pip list
pip check  # Check for dependency conflicts

# Verify virtual environment
source ~/venv/deepseek-llm/bin/activate
which python
```

**Solutions:**
```bash
# 1. Recreate virtual environment
rm -rf ~/venv/deepseek-llm
python3 -m venv ~/venv/deepseek-llm
source ~/venv/deepseek-llm/bin/activate

# 2. Install packages in correct order
pip install --upgrade pip setuptools wheel
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install transformers accelerate

# 3. Use pip-tools for dependency management
pip install pip-tools
pip-compile requirements.in
pip-sync requirements.txt

# 4. Check for conflicting system packages
sudo apt list --installed | grep python3-
```

### LLM Framework Issues

#### Ollama Service Problems
**Symptoms:**
- Ollama service fails to start
- Models not loading properly
- API endpoints not responding

**Diagnosis:**
```bash
# Check service status
sudo systemctl status ollama

# Check service logs
sudo journalctl -u ollama -f

# Test API manually
curl http://localhost:11434/api/version

# Check available models
ollama list

# Test model loading
ollama run deepseek-coder:6.7b "test prompt"
```

**Solutions:**
```bash
# 1. Restart Ollama service
sudo systemctl restart ollama

# 2. Check configuration
sudo cat /etc/ollama/config.yaml
# Verify paths and permissions

# 3. Reset Ollama data
sudo systemctl stop ollama
sudo rm -rf /opt/models/ollama/*
sudo systemctl start ollama
ollama pull deepseek-coder:6.7b  # Re-download models

# 4. Check disk space
df -h /opt/models

# 5. Verify permissions
sudo chown -R ollama:ollama /opt/models/ollama
```

#### vLLM Installation and Runtime Issues
**Symptoms:**
- vLLM import errors
- CUDA out of memory errors
- Slow inference performance

**Diagnosis:**
```bash
# Test vLLM installation
python -c "import vllm; print(vllm.__version__)"

# Check CUDA availability
python -c "import torch; print(torch.cuda.is_available())"

# Monitor GPU memory during inference
nvidia-smi -l 1

# Check vLLM logs
python -m vllm.entrypoints.openai.api_server --model /path/to/model --help
```

**Solutions:**
```bash
# 1. Reinstall vLLM with specific CUDA version
pip uninstall vllm
pip install vllm --index-url https://download.pytorch.org/whl/cu118

# 2. Reduce GPU memory utilization
python -m vllm.entrypoints.openai.api_server \
  --model /path/to/model \
  --gpu-memory-utilization 0.8

# 3. Enable quantization
python -m vllm.entrypoints.openai.api_server \
  --model /path/to/model \
  --quantization awq

# 4. Reduce max sequence length
python -m vllm.entrypoints.openai.api_server \
  --model /path/to/model \
  --max-model-len 4096
```

#### Transformers Library Issues
**Symptoms:**
- Model loading failures
- Out of memory errors
- Slow model initialization

**Diagnosis:**
```bash
# Check transformers version
pip show transformers

# Test model loading
python -c "
from transformers import AutoTokenizer, AutoModelForCausalLM
tokenizer = AutoTokenizer.from_pretrained('deepseek-ai/deepseek-coder-6.7b-base')
print('Tokenizer loaded successfully')
"

# Check available GPU memory
nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv

# Monitor memory usage during loading
python -c "
import torch
print(f'GPU memory before: {torch.cuda.memory_allocated() / 1024**3:.2f} GB')
from transformers import AutoModelForCausalLM
model = AutoModelForCausalLM.from_pretrained('model_path', torch_dtype=torch.float16, device_map='auto')
print(f'GPU memory after: {torch.cuda.memory_allocated() / 1024**3:.2f} GB')
"
```

**Solutions:**
```bash
# 1. Use quantization for large models
python -c "
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
import torch

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16
)

model = AutoModelForCausalLM.from_pretrained(
    'model_path',
    quantization_config=quantization_config,
    device_map='auto'
)
"

# 2. Enable low CPU memory usage
python -c "
model = AutoModelForCausalLM.from_pretrained(
    'model_path',
    torch_dtype=torch.float16,
    low_cpu_mem_usage=True,
    device_map='auto'
)
"

# 3. Clear GPU cache
python -c "import torch; torch.cuda.empty_cache()"
```

## 🔗 Network and API Issues

### API Connectivity Problems
**Symptoms:**
- Connection refused errors
- Timeout errors
- API endpoints not accessible

**Diagnosis:**
```bash
# Check if services are listening
sudo netstat -tlnp | grep -E "(8000|11434)"

# Test local connectivity
curl -v http://localhost:11434/api/version
curl -v http://localhost:8000/docs

# Check firewall rules
sudo ufw status
sudo iptables -L

# Test from remote machine
curl -v http://YOUR_SERVER_IP:8000/docs
```

**Solutions:**
```bash
# 1. Verify service binding
# Ensure services bind to 0.0.0.0, not 127.0.0.1

# 2. Configure firewall
sudo ufw allow 8000/tcp
sudo ufw allow 11434/tcp

# 3. Check service configuration
# Ollama: /etc/ollama/config.yaml - host: "0.0.0.0:11434"
# vLLM: --host 0.0.0.0 --port 8000

# 4. Restart networking services
sudo systemctl restart networking
sudo systemctl restart systemd-resolved
```

### Performance Degradation Issues
**Symptoms:**
- Slow response times
- Reduced tokens per second
- High latency between requests

**Diagnosis:**
```bash
# Performance test script
cat << 'EOF' > ~/diagnose_performance.py
import requests
import time
import statistics

def test_performance(endpoint, prompts, iterations=3):
    results = []
    
    for i in range(iterations):
        for prompt in prompts:
            start_time = time.time()
            
            response = requests.post(endpoint, json={
                "prompt": prompt,
                "max_tokens": 50,
                "temperature": 0.2
            })
            
            end_time = time.time()
            
            if response.status_code == 200:
                results.append(end_time - start_time)
            else:
                print(f"Error: {response.status_code}")
    
    if results:
        print(f"Average response time: {statistics.mean(results):.2f}s")
        print(f"Median response time: {statistics.median(results):.2f}s")
        print(f"Min/Max: {min(results):.2f}s / {max(results):.2f}s")
    
    return results

# Test different endpoints
test_prompts = ["def test():", "class MyClass:", "# Calculate fibonacci"]

print("Testing Ollama endpoint:")
test_performance("http://localhost:11434/api/generate", [
    {"model": "deepseek-coder:6.7b", "prompt": p, "stream": False} for p in test_prompts
])

print("\nTesting vLLM endpoint:")
test_performance("http://localhost:8000/v1/completions", test_prompts)
EOF

python ~/diagnose_performance.py
```

**Solutions:**
```bash
# 1. System optimization
~/optimize_for_llm.sh  # Apply system optimizations

# 2. Check resource utilization
htop  # Check CPU usage
nvidia-smi  # Check GPU usage
iotop  # Check disk I/O

# 3. Restart services
sudo systemctl restart ollama
# Or restart vLLM server

# 4. Reduce concurrent requests
# Lower num_parallel in Ollama configuration
# Reduce max_num_seqs in vLLM configuration

# 5. Check thermal throttling
sensors  # Check temperatures
nvidia-smi -q | grep -A 3 "Throttle"
```

## 🗂️ Model and Data Issues

### Model Loading Failures
**Symptoms:**
- Models fail to download
- Corruption errors during loading
- Authentication errors from HuggingFace

**Diagnosis:**
```bash
# Check available disk space
df -h /opt/models

# Test HuggingFace connection
python -c "
from huggingface_hub import login, model_info
try:
    info = model_info('deepseek-ai/deepseek-coder-6.7b-base')
    print(f'Model accessible: {info.modelId}')
except Exception as e:
    print(f'Error: {e}')
"

# Check file integrity
ls -la /opt/models/deepseek/
find /opt/models -name "*.bin" -o -name "*.safetensors" | xargs ls -la
```

**Solutions:**
```bash
# 1. Clear and re-download models
rm -rf /opt/models/deepseek/deepseek-coder-6.7b
huggingface-cli download deepseek-ai/deepseek-coder-6.7b-base \
  --local-dir /opt/models/deepseek/deepseek-coder-6.7b

# 2. Check and increase disk space
sudo ln -s /path/to/larger/drive /opt/models/additional

# 3. Authenticate with HuggingFace
huggingface-cli login
# Enter your HuggingFace token

# 4. Use alternative download method
git lfs install
git clone https://huggingface.co/deepseek-ai/deepseek-coder-6.7b-base \
  /opt/models/deepseek/deepseek-coder-6.7b

# 5. Verify file checksums (if provided)
sha256sum /opt/models/deepseek/deepseek-coder-6.7b/pytorch_model.bin
```

### Quantization Issues
**Symptoms:**
- Quantized models perform poorly
- Quantization process fails
- Memory usage not reduced as expected

**Diagnosis:**
```bash
# Test different quantization methods
python << 'EOF'
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

model_path = "/opt/models/deepseek/deepseek-coder-6.7b"

# Test 8-bit quantization
print("Testing 8-bit quantization...")
try:
    model_8bit = AutoModelForCausalLM.from_pretrained(
        model_path,
        load_in_8bit=True,
        device_map="auto"
    )
    print(f"8-bit model loaded: {torch.cuda.memory_allocated() / 1024**3:.2f} GB")
    del model_8bit
    torch.cuda.empty_cache()
except Exception as e:
    print(f"8-bit failed: {e}")

# Test 4-bit quantization
print("\nTesting 4-bit quantization...")
try:
    config_4bit = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.float16,
    )
    model_4bit = AutoModelForCausalLM.from_pretrained(
        model_path,
        quantization_config=config_4bit,
        device_map="auto"
    )
    print(f"4-bit model loaded: {torch.cuda.memory_allocated() / 1024**3:.2f} GB")
    del model_4bit
    torch.cuda.empty_cache()
except Exception as e:
    print(f"4-bit failed: {e}")
EOF
```

**Solutions:**
```bash
# 1. Install required quantization packages
pip install bitsandbytes accelerate

# 2. Update to compatible versions
pip install --upgrade transformers accelerate bitsandbytes

# 3. Use alternative quantization method
# AWQ quantization (if available)
pip install autoawq
python -c "
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

model_path = 'model_path'
quant_path = 'model_path_awq'

# Quantize model
model = AutoAWQForCausalLM.from_pretrained(model_path)
tokenizer = AutoTokenizer.from_pretrained(model_path)
model.quantize(tokenizer, quant_config={'zero_point': True, 'q_group_size': 128})
model.save_quantized(quant_path)
"

# 4. Check CUDA compatibility
python -c "
import torch
print(f'CUDA version: {torch.version.cuda}')
print(f'PyTorch version: {torch.__version__}')
import bitsandbytes as bnb
print(f'bitsandbytes version: {bnb.__version__}')
"
```

## 🚨 Emergency Recovery Procedures

### System Recovery Mode
**When system becomes unresponsive:**

1. **Safe Boot Recovery**
```bash
# Boot into recovery mode
# Hold Shift during GRUB loading, select Advanced Options > Recovery Mode

# Drop to root shell
# Mount filesystem read-write
mount -o remount,rw /

# Check and fix filesystem errors
fsck /dev/nvme0n1p3

# Check system logs
journalctl -xe | tail -100

# Disable problematic services
systemctl disable ollama
systemctl disable deepseek-stack
```

2. **GPU Reset Procedure**
```bash
# Reset NVIDIA GPU
nvidia-smi -r

# Restart display manager
sudo systemctl restart gdm3

# Reload NVIDIA modules
sudo rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia
sudo modprobe nvidia nvidia_drm nvidia_modeset nvidia_uvm
```

3. **Memory Pressure Relief**
```bash
# Clear system caches
echo 3 | sudo tee /proc/sys/vm/drop_caches

# Kill memory-intensive processes
sudo pkill -f python
sudo pkill -f ollama

# Check for memory leaks
ps aux --sort=-%mem | head -10
```

### Configuration Backup and Restore

**Backup Critical Configurations**
```bash
#!/bin/bash
# Create backup script

BACKUP_DIR="/home/$USER/deepseek_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup configurations
cp -r /etc/ollama/ $BACKUP_DIR/ 2>/dev/null
cp ~/.bashrc $BACKUP_DIR/
cp -r ~/venv/deepseek-llm/pyvenv.cfg $BACKUP_DIR/ 2>/dev/null

# Backup custom scripts
cp ~/start_deepseek_stack.sh $BACKUP_DIR/ 2>/dev/null
cp ~/optimize_for_llm.sh $BACKUP_DIR/ 2>/dev/null

# Backup systemd services
cp /etc/systemd/system/deepseek-stack.service $BACKUP_DIR/ 2>/dev/null

# Create restore script
cat << EOF > $BACKUP_DIR/restore.sh
#!/bin/bash
echo "Restoring DeepSeek configuration..."
sudo cp -r ollama/ /etc/ 2>/dev/null
cp bashrc ~/.bashrc
cp start_deepseek_stack.sh ~/
cp optimize_for_llm.sh ~/
sudo cp deepseek-stack.service /etc/systemd/system/ 2>/dev/null
sudo systemctl daemon-reload
echo "Restore completed. Please reboot system."
EOF

chmod +x $BACKUP_DIR/restore.sh
echo "Backup created in: $BACKUP_DIR"
```

**Factory Reset Procedure**
```bash
#!/bin/bash
# Complete system reset script

echo "WARNING: This will reset all DeepSeek configurations!"
read -p "Continue? (y/N): " confirm
if [[ $confirm != [yY] ]]; then exit 1; fi

# Stop all services
sudo systemctl stop ollama
sudo systemctl stop deepseek-stack

# Remove model data (CAUTION: This deletes downloaded models)
read -p "Delete all models? (y/N): " delete_models
if [[ $delete_models == [yY] ]]; then
    sudo rm -rf /opt/models/
fi

# Remove virtual environment
rm -rf ~/venv/deepseek-llm/

# Remove custom scripts
rm -f ~/start_deepseek_stack.sh
rm -f ~/optimize_for_llm.sh
rm -f ~/deepseek_gateway.py

# Remove systemd services
sudo rm -f /etc/systemd/system/deepseek-stack.service
sudo systemctl daemon-reload

# Reset GPU settings
nvidia-smi -r
nvidia-smi -c 0  # Set compute mode to default

echo "Factory reset completed. System is ready for fresh installation."
```

### Emergency Contact and Support Resources

**Community Support:**
- **DeepSeek AI GitHub**: https://github.com/deepseek-ai
- **Ollama Community**: https://github.com/ollama/ollama/issues
- **vLLM Support**: https://github.com/vllm-project/vllm/issues
- **Ubuntu Forums**: https://ubuntuforums.org/
- **r/LocalLLaMA**: https://reddit.com/r/LocalLLaMA

**Hardware Support:**
- **AMD Ryzen Support**: https://www.amd.com/en/support
- **NVIDIA Developer Forums**: https://developer.nvidia.com/forums
- **Motherboard Manufacturer Support**

**Quick Reference Commands:**
```bash
# System status check
~/health-check.sh

# Service restart
sudo systemctl restart ollama

# GPU reset
nvidia-smi -r

# Memory cleanup
echo 3 | sudo tee /proc/sys/vm/drop_caches

# Temperature monitoring
watch -n 1 'sensors; nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits'

# Performance test
python ~/benchmark_deepseek.py

# Log analysis
sudo journalctl -u ollama -f
```

---

**Previous:** [Performance Optimization](./performance-optimization.md) | **Back to:** [Research Overview](./README.md)