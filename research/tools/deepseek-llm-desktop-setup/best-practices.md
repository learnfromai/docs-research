# Best Practices for DeepSeek LLM Desktop Setup

## 🎯 System Optimization Guidelines

### Hardware Configuration Best Practices

#### CPU Optimization
```bash
# Enable performance governor
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable CPU mitigations for maximum performance (security trade-off)
# Add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub
mitigations=off

# Optimize CPU affinity for inference processes
# Reserve specific cores for LLM inference
taskset -c 0-7 python inference_script.py  # Use first 8 cores
```

#### Memory Management Best Practices
```bash
# Optimize memory allocation
echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf

# Enable huge pages for better memory performance
echo 'vm.nr_hugepages=2048' | sudo tee -a /etc/sysctl.conf
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# Memory preallocation for consistent performance
echo 1 | sudo tee /proc/sys/vm/drop_caches  # Clear cache before starting
```

#### GPU Optimization Settings
```bash
# Set persistence mode
nvidia-smi -pm 1

# Optimize power limit (adjust based on your card)
nvidia-smi -pl 350  # For RTX 4070 Ti Super

# Set application clocks for consistent performance
nvidia-smi -ac 7001,2610  # Memory,Graphics clocks for RTX 4070 Ti Super

# Enable ECC if supported (Quadro/Tesla cards)
nvidia-smi -e 1
```

### Storage Performance Optimization

#### NVMe SSD Configuration
```bash
# Optimize I/O scheduler for NVMe drives
echo 'none' | sudo tee /sys/block/nvme*/queue/scheduler

# Enable write-back cache
echo 'write back' | sudo tee /sys/block/nvme*/queue/write_cache

# Optimize read-ahead settings
echo 8192 | sudo tee /sys/block/nvme*/queue/read_ahead_kb

# Mount options for optimal performance
# Add to /etc/fstab
/dev/nvme0n1p1 /opt/models ext4 defaults,noatime,nodiratime,discard 0 2
```

#### Model Storage Organization
```
/opt/models/
├── deepseek/
│   ├── 6.7b/           # Small models
│   ├── 33b/            # Large models  
│   └── quantized/      # Quantized versions
├── cache/              # Temporary model cache
├── backups/            # Model backups
└── benchmarks/         # Performance test results
```

## 🔧 Software Configuration Best Practices

### Python Environment Management

#### Virtual Environment Setup
```bash
# Use pyenv for Python version management
pyenv install 3.11.6
pyenv global 3.11.6

# Create dedicated environment
python -m venv ~/venv/deepseek-llm
source ~/venv/deepseek-llm/bin/activate

# Pin dependency versions for stability
pip freeze > requirements.txt
```

#### Package Installation Best Practices
```bash
# Install packages in specific order
pip install --upgrade pip setuptools wheel
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install transformers accelerate bitsandbytes
pip install vllm  # Install after PyTorch

# Use pip-tools for dependency management
pip install pip-tools
pip-compile requirements.in
pip-sync requirements.txt
```

### Containerization Strategy

#### Docker Best Practices
```dockerfile
# Multi-stage build for optimized images
FROM nvidia/cuda:11.8-devel-ubuntu22.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages
COPY requirements.txt .
RUN pip install -r requirements.txt

# Production stage
FROM nvidia/cuda:11.8-runtime-ubuntu22.04

COPY --from=builder /usr/local/lib/python3.10 /usr/local/lib/python3.10
COPY --from=builder /usr/local/bin /usr/local/bin

# Configure for optimal GPU usage
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV CUDA_CACHE_DISABLE=0
ENV CUDA_MODULE_LOADING=LAZY
```

#### Container Resource Management
```bash
# Run container with optimal resource limits
docker run --gpus all \
  --memory="32g" \
  --memory-swap="32g" \
  --memory-swappiness=1 \
  --shm-size=16g \
  -v /opt/models:/models \
  deepseek-llm:latest
```

## 🚀 Performance Optimization Techniques

### Model Loading Optimization

#### Pre-loading Strategy
```python
# Model warmup script
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

class ModelPreloader:
    def __init__(self, model_path):
        self.model_path = model_path
        self.model = None
        self.tokenizer = None
    
    def warmup_model(self):
        """Pre-load and warm up the model"""
        # Load model with optimal settings
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_path, 
            trust_remote_code=True
        )
        
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True,
            attn_implementation="flash_attention_2"  # If available
        )
        
        # Warmup with dummy input
        dummy_input = "def hello_world():"
        inputs = self.tokenizer(dummy_input, return_tensors="pt")
        
        with torch.no_grad():
            _ = self.model.generate(
                **inputs,
                max_new_tokens=50,
                do_sample=False,
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        print("Model warmed up successfully")
        return True

# Usage
preloader = ModelPreloader("/opt/models/deepseek/deepseek-coder-6.7b")
preloader.warmup_model()
```

#### Memory-Mapped Model Loading
```python
import mmap
import torch

def load_model_mmap(model_path):
    """Load model using memory mapping for faster access"""
    with open(f"{model_path}/pytorch_model.bin", "rb") as f:
        with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            # Load model from memory-mapped file
            model_state = torch.load(io.BytesIO(mm.read()), map_location="cuda")
    return model_state
```

### Inference Performance Optimization

#### Batch Processing Best Practices
```python
import asyncio
from typing import List

class BatchInferenceManager:
    def __init__(self, model, tokenizer, batch_size=4):
        self.model = model
        self.tokenizer = tokenizer
        self.batch_size = batch_size
        self.pending_requests = []
    
    async def add_request(self, prompt: str, callback):
        """Add request to batch processing queue"""
        self.pending_requests.append((prompt, callback))
        
        if len(self.pending_requests) >= self.batch_size:
            await self.process_batch()
    
    async def process_batch(self):
        """Process accumulated requests as batch"""
        if not self.pending_requests:
            return
        
        prompts = [req[0] for req in self.pending_requests]
        callbacks = [req[1] for req in self.pending_requests]
        
        # Tokenize all prompts together
        inputs = self.tokenizer(
            prompts,
            padding=True,
            truncation=True,
            return_tensors="pt"
        )
        
        # Batch inference
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=100,
                do_sample=True,
                temperature=0.2,
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        # Process results
        for i, callback in enumerate(callbacks):
            response = self.tokenizer.decode(
                outputs[i][len(inputs['input_ids'][i]):], 
                skip_special_tokens=True
            )
            await callback(response)
        
        self.pending_requests.clear()
```

### Cache Management Strategies

#### Model Cache Optimization
```python
import os
import hashlib
from transformers import AutoModel

class ModelCacheManager:
    def __init__(self, cache_dir="/opt/models/cache"):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
    
    def get_cache_key(self, model_name, config):
        """Generate cache key for model configuration"""
        cache_input = f"{model_name}_{str(config)}"
        return hashlib.sha256(cache_input.encode()).hexdigest()
    
    def cache_compiled_model(self, model, cache_key):
        """Cache compiled/optimized model"""
        cache_path = os.path.join(self.cache_dir, f"{cache_key}.pt")
        torch.save(model.state_dict(), cache_path)
        return cache_path
    
    def load_cached_model(self, model_class, cache_key):
        """Load model from cache if available"""
        cache_path = os.path.join(self.cache_dir, f"{cache_key}.pt")
        if os.path.exists(cache_path):
            model = model_class()
            model.load_state_dict(torch.load(cache_path))
            return model
        return None
```

## 🔒 Security Best Practices

### API Security Configuration

#### Authentication and Access Control
```python
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
import secrets

app = FastAPI()
security = HTTPBearer()

# Generate secure API key
API_KEY = secrets.token_urlsafe(32)
JWT_SECRET = secrets.token_urlsafe(32)

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify API key for request authentication"""
    try:
        # Verify JWT token
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=["HS256"])
        return payload.get("user_id")
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Rate limiting
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(429, _rate_limit_exceeded_handler)

@app.post("/v1/completions")
@limiter.limit("10/minute")  # Rate limit to 10 requests per minute
async def create_completion(request: CompletionRequest, user_id: str = Depends(verify_api_key)):
    # Implementation here
    pass
```

#### Network Security Configuration
```bash
# UFW firewall configuration
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow specific services
sudo ufw allow ssh
sudo ufw allow 8000/tcp  # API server
sudo ufw allow from 192.168.1.0/24 to any port 11434  # Ollama (LAN only)

# Enable firewall
sudo ufw enable

# Configure fail2ban for additional protection
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Create custom jail for API protection
sudo tee /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[api-auth]
enabled = true
port = 8000
protocol = tcp
filter = api-auth
logpath = /var/log/deepseek-api.log
maxretry = 3
EOF
```

### Data Privacy and Model Security

#### Local Model Encryption
```python
from cryptography.fernet import Fernet
import os

class ModelEncryption:
    def __init__(self):
        # Generate or load encryption key
        key_path = "/opt/models/.encryption_key"
        if os.path.exists(key_path):
            with open(key_path, 'rb') as key_file:
                self.key = key_file.read()
        else:
            self.key = Fernet.generate_key()
            with open(key_path, 'wb') as key_file:
                key_file.write(self.key)
            os.chmod(key_path, 0o600)  # Restrict access
        
        self.cipher_suite = Fernet(self.key)
    
    def encrypt_model_file(self, file_path):
        """Encrypt sensitive model files"""
        with open(file_path, 'rb') as file:
            file_data = file.read()
        
        encrypted_data = self.cipher_suite.encrypt(file_data)
        
        with open(f"{file_path}.encrypted", 'wb') as encrypted_file:
            encrypted_file.write(encrypted_data)
        
        # Securely delete original
        os.remove(file_path)
    
    def decrypt_model_file(self, encrypted_file_path):
        """Decrypt model file for use"""
        with open(encrypted_file_path, 'rb') as encrypted_file:
            encrypted_data = encrypted_file.read()
        
        decrypted_data = self.cipher_suite.decrypt(encrypted_data)
        
        original_path = encrypted_file_path.replace('.encrypted', '')
        with open(original_path, 'wb') as file:
            file.write(decrypted_data)
        
        return original_path
```

## 🔍 Monitoring and Alerting Best Practices

### System Health Monitoring

#### Comprehensive Monitoring Script
```python
import psutil
import GPUtil
import smtplib
from email.mime.text import MIMEText
import time
import logging

class SystemMonitor:
    def __init__(self, alert_email=None):
        self.alert_email = alert_email
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
    
    def check_system_health(self):
        """Check system health metrics"""
        health_report = {
            'timestamp': time.time(),
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_percent': psutil.disk_usage('/opt').percent,
            'gpu_stats': [],
            'temperatures': {},
            'alerts': []
        }
        
        # GPU monitoring
        try:
            gpus = GPUtil.getGPUs()
            for gpu in gpus:
                health_report['gpu_stats'].append({
                    'id': gpu.id,
                    'name': gpu.name,
                    'temperature': gpu.temperature,
                    'utilization': gpu.load * 100,
                    'memory_used': gpu.memoryUsed,
                    'memory_total': gpu.memoryTotal,
                    'memory_percent': (gpu.memoryUsed / gpu.memoryTotal) * 100
                })
                
                # Alert conditions
                if gpu.temperature > 80:
                    health_report['alerts'].append(f"GPU {gpu.id} high temperature: {gpu.temperature}°C")
                if gpu.memoryUsed / gpu.memoryTotal > 0.95:
                    health_report['alerts'].append(f"GPU {gpu.id} high memory usage: {gpu.memoryUsed/gpu.memoryTotal*100:.1f}%")
        except:
            health_report['alerts'].append("GPU monitoring failed")
        
        # Temperature monitoring
        try:
            temps = psutil.sensors_temperatures()
            for name, entries in temps.items():
                health_report['temperatures'][name] = [entry.current for entry in entries]
        except:
            self.logger.warning("Temperature monitoring not available")
        
        # Alert conditions
        if health_report['cpu_percent'] > 95:
            health_report['alerts'].append(f"High CPU usage: {health_report['cpu_percent']}%")
        if health_report['memory_percent'] > 90:
            health_report['alerts'].append(f"High memory usage: {health_report['memory_percent']}%")
        if health_report['disk_percent'] > 85:
            health_report['alerts'].append(f"High disk usage: {health_report['disk_percent']}%")
        
        return health_report
    
    def send_alert(self, message):
        """Send email alert for critical conditions"""
        if not self.alert_email:
            return
        
        try:
            msg = MIMEText(message)
            msg['Subject'] = 'DeepSeek System Alert'
            msg['From'] = 'system@localhost'
            msg['To'] = self.alert_email
            
            # Configure SMTP server
            server = smtplib.SMTP('localhost')
            server.send_message(msg)
            server.quit()
        except Exception as e:
            self.logger.error(f"Failed to send alert: {e}")

# Usage
monitor = SystemMonitor(alert_email="admin@yourcompany.com")
health = monitor.check_system_health()
if health['alerts']:
    monitor.send_alert('\n'.join(health['alerts']))
```

### Performance Benchmarking

#### Automated Performance Testing
```python
import time
import requests
import statistics
from datetime import datetime

class PerformanceBenchmark:
    def __init__(self, api_endpoint="http://localhost:8000"):
        self.api_endpoint = api_endpoint
        self.results = []
    
    def run_inference_test(self, prompts, iterations=5):
        """Run comprehensive inference performance test"""
        test_results = {
            'timestamp': datetime.now().isoformat(),
            'prompts_tested': len(prompts),
            'iterations': iterations,
            'results': []
        }
        
        for i in range(iterations):
            iteration_results = []
            
            for prompt in prompts:
                start_time = time.time()
                
                response = requests.post(f"{self.api_endpoint}/v1/completions", 
                    json={
                        "prompt": prompt,
                        "max_tokens": 100,
                        "temperature": 0.2
                    }
                )
                
                end_time = time.time()
                response_time = end_time - start_time
                
                if response.status_code == 200:
                    result = response.json()
                    tokens_generated = len(result.get('choices', [{}])[0].get('text', '').split())
                    tokens_per_second = tokens_generated / response_time if response_time > 0 else 0
                    
                    iteration_results.append({
                        'prompt': prompt[:50] + '...',
                        'response_time': response_time,
                        'tokens_generated': tokens_generated,
                        'tokens_per_second': tokens_per_second,
                        'success': True
                    })
                else:
                    iteration_results.append({
                        'prompt': prompt[:50] + '...',
                        'response_time': response_time,
                        'error': response.status_code,
                        'success': False
                    })
            
            test_results['results'].append(iteration_results)
        
        # Calculate statistics
        successful_tests = [r for iteration in test_results['results'] 
                           for r in iteration if r['success']]
        
        if successful_tests:
            response_times = [r['response_time'] for r in successful_tests]
            tokens_per_second = [r['tokens_per_second'] for r in successful_tests]
            
            test_results['statistics'] = {
                'mean_response_time': statistics.mean(response_times),
                'median_response_time': statistics.median(response_times),
                'std_response_time': statistics.stdev(response_times) if len(response_times) > 1 else 0,
                'mean_tokens_per_second': statistics.mean(tokens_per_second),
                'median_tokens_per_second': statistics.median(tokens_per_second),
                'success_rate': len(successful_tests) / (len(prompts) * iterations)
            }
        
        return test_results
    
    def save_benchmark_results(self, results, filename=None):
        """Save benchmark results to file"""
        if not filename:
            filename = f"benchmark_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        import json
        with open(f"/opt/models/benchmarks/{filename}", 'w') as f:
            json.dump(results, f, indent=2)
        
        return filename

# Usage
benchmark = PerformanceBenchmark()
test_prompts = [
    "def fibonacci(n):",
    "class BinarySearchTree:",
    "# Create a web server using FastAPI",
    "SELECT users.name FROM users WHERE",
    "import React from 'react'"
]

results = benchmark.run_inference_test(test_prompts)
filename = benchmark.save_benchmark_results(results)
print(f"Benchmark results saved to: {filename}")
```

## 📚 Documentation and Maintenance

### Configuration Management

#### Version Control for Configurations
```bash
# Initialize configuration repository
cd /opt/deepseek-config
git init
git add .
git commit -m "Initial DeepSeek configuration"

# Track important configuration files
git add /etc/ollama/config.yaml
git add ~/start-deepseek-vllm.sh
git add ~/deepseek_gateway.py
git add /etc/systemd/system/deepseek-stack.service

# Create configuration backup script
cat << 'EOF' > ~/backup-config.sh
#!/bin/bash
cd /opt/deepseek-config
git add -A
git commit -m "Configuration backup $(date)"
git push origin main  # If using remote repository
EOF

chmod +x ~/backup-config.sh
```

#### Change Documentation Template
```markdown
# Configuration Change Log

## Change #001
**Date**: 2024-01-15
**Component**: Ollama Configuration
**Change**: Updated context window from 4096 to 8192 tokens
**Reason**: Improved performance for longer code generation tasks
**Files Modified**: 
- /etc/ollama/config.yaml

**Performance Impact**: 
- 15% increase in memory usage
- 20% improvement in long-form code generation

**Rollback Procedure**:
```yaml
num_ctx: 4096  # Previous value
```

## Change #002
[Next change documentation]
```

### Maintenance Schedules

#### Daily Maintenance Checklist
```bash
#!/bin/bash
# Daily maintenance script

echo "=== Daily DeepSeek Maintenance ==="
date

# 1. Check system health
~/health-check.sh

# 2. Clean temporary files
find /opt/models/cache -type f -mtime +7 -delete
docker system prune -f --volumes

# 3. Update system packages (security only)
sudo apt update && sudo apt upgrade -y --only-upgrade

# 4. Backup configuration
~/backup-config.sh

# 5. Check disk space
df -h /opt | awk '$5+0 > 80 {print "Warning: Disk usage " $5}'

# 6. Restart services if needed
if ! systemctl is-active --quiet ollama; then
    sudo systemctl restart ollama
    echo "Restarted Ollama service"
fi

echo "Daily maintenance completed"
```

#### Weekly Maintenance Tasks
```bash
#!/bin/bash
# Weekly maintenance script

echo "=== Weekly DeepSeek Maintenance ==="

# 1. Performance benchmark
python ~/benchmark_deepseek.py

# 2. Model integrity check
ollama list | while read model size created; do
    if [[ $model != "NAME" ]]; then
        echo "Testing model: $model"
        ollama run $model "def test(): pass" --verbose
    fi
done

# 3. Clean old logs
find ~/logs -name "*.log" -mtime +30 -delete

# 4. Update Python packages
source ~/venv/deepseek-llm/bin/activate
pip list --outdated
# pip install --upgrade package_name  # Manual review recommended

# 5. System optimization
~/optimize_for_llm.sh

echo "Weekly maintenance completed"
```

---

**Previous:** [Cost Analysis](./cost-analysis.md) | **Next:** [Performance Optimization](./performance-optimization.md)