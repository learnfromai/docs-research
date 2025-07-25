# Performance Optimization for DeepSeek LLM Systems

## 🚀 System-Level Performance Tuning

### CPU Performance Optimization

#### CPU Governor and Frequency Scaling
```bash
# Set performance governor for maximum CPU performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable CPU idle states for consistent performance
echo 1 | sudo tee /sys/devices/system/cpu/cpu*/cpuidle/state*/disable

# Set CPU affinity for inference processes
# Reserve cores 0-7 for LLM inference, 8-15 for system
taskset -c 0-7 python deepseek_inference.py

# Create systemd service for CPU optimization
sudo tee /etc/systemd/system/cpu-performance.service << EOF
[Unit]
Description=CPU Performance Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable cpu-performance.service
```

#### Memory Subsystem Optimization
```bash
# Optimize memory allocation and caching
echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf

# Enable huge pages for better memory performance
echo 2048 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# Optimize memory zones
echo 'vm.zone_reclaim_mode=0' | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

### GPU Performance Optimization

#### NVIDIA GPU Tuning
```bash
# Create comprehensive GPU optimization script
cat << 'EOF' > ~/optimize-gpu.sh
#!/bin/bash

# Enable persistence mode
nvidia-smi -pm 1

# Set optimal power limits (adjust for your card)
case $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1) in
    *"RTX 4060 Ti"*)
        nvidia-smi -pl 165
        nvidia-smi -ac 9001,2610
        ;;
    *"RTX 4070 Ti Super"*)
        nvidia-smi -pl 285
        nvidia-smi -ac 10501,2610
        ;;
    *"RTX 4080 Super"*)
        nvidia-smi -pl 320
        nvidia-smi -ac 11501,2610
        ;;
    *"RTX 4090"*)
        nvidia-smi -pl 450
        nvidia-smi -ac 10501,2230
        ;;
esac

# Maximize GPU clocks
nvidia-smi -lgc 210,1920  # Lock GPU clocks to max stable

# Enable ECC if supported (for Quadro/Tesla cards)
nvidia-smi -e 1 2>/dev/null || echo "ECC not supported"

# Set compute mode to exclusive process
nvidia-smi -c 3

echo "GPU optimization applied"
EOF

chmod +x ~/optimize-gpu.sh
~/optimize-gpu.sh
```

#### GPU Memory Management
```python
# PyTorch GPU memory optimization
import torch
import os

def optimize_gpu_memory():
    """Optimize GPU memory allocation for inference"""
    # Enable memory fraction allocation
    torch.cuda.set_per_process_memory_fraction(0.9)  # Use 90% of VRAM
    
    # Enable memory growth
    os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'max_split_size_mb:128'
    
    # Optimize memory pool
    torch.cuda.empty_cache()
    
    # Enable cudnn benchmarking for consistent input sizes
    torch.backends.cudnn.benchmark = True
    torch.backends.cudnn.enabled = True
    
    # Enable TensorFloat-32 on Ampere GPUs
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    
    print(f"GPU memory optimized: {torch.cuda.memory_allocated() / 1024**3:.2f} GB allocated")

# Memory monitoring function
def monitor_gpu_memory(model, tokenizer, test_prompts):
    """Monitor GPU memory usage during inference"""
    for prompt in test_prompts:
        torch.cuda.reset_peak_memory_stats()
        
        inputs = tokenizer(prompt, return_tensors="pt").to("cuda")
        
        # Measure memory before inference
        memory_before = torch.cuda.memory_allocated()
        peak_memory_before = torch.cuda.max_memory_allocated()
        
        with torch.no_grad():
            outputs = model.generate(**inputs, max_new_tokens=100)
        
        # Measure memory after inference
        memory_after = torch.cuda.memory_allocated()
        peak_memory = torch.cuda.max_memory_allocated()
        
        print(f"Prompt: {prompt[:30]}...")
        print(f"  Memory before: {memory_before / 1024**3:.2f} GB")
        print(f"  Memory after: {memory_after / 1024**3:.2f} GB")
        print(f"  Peak memory: {peak_memory / 1024**3:.2f} GB")
        print(f"  Memory increase: {(memory_after - memory_before) / 1024**3:.2f} GB")
        print()
```

### Storage Performance Tuning

#### NVMe SSD Optimization
```bash
# Optimize NVMe drives for maximum performance
for device in /dev/nvme*n1; do
    if [ -e "$device" ]; then
        echo "Optimizing $device"
        
        # Set I/O scheduler to none (bypass kernel scheduling)
        echo none | sudo tee /sys/block/$(basename $device)/queue/scheduler
        
        # Set optimal read-ahead
        echo 8192 | sudo tee /sys/block/$(basename $device)/queue/read_ahead_kb
        
        # Enable write-back caching
        echo write back | sudo tee /sys/block/$(basename $device)/queue/write_cache
        
        # Optimize queue depth
        echo 32 | sudo tee /sys/block/$(basename $device)/queue/nr_requests
        
        # Set RQ affinity for NUMA systems
        echo 2 | sudo tee /sys/block/$(basename $device)/queue/rq_affinity
    fi
done

# Create filesystem with optimal settings for AI workloads
# sudo mkfs.ext4 -F -O ^has_journal -E stride=128,stripe-width=128 /dev/nvme1n1
# Mount with optimal options:
# /dev/nvme1n1 /opt/models ext4 defaults,noatime,nodiratime,nobarrier,data=writeback 0 2
```

#### Model Loading Performance
```python
import torch
import time
from pathlib import Path
import mmap

class OptimizedModelLoader:
    def __init__(self, model_path, cache_dir="/opt/models/cache"):
        self.model_path = Path(model_path)
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
    
    def preload_to_memory(self):
        """Pre-load model files into system memory"""
        model_files = list(self.model_path.glob("*.bin")) + list(self.model_path.glob("*.safetensors"))
        
        for model_file in model_files:
            print(f"Pre-loading {model_file.name} into memory...")
            with open(model_file, 'rb') as f:
                # Read entire file into memory
                data = f.read()
                # Create memory-mapped file for faster access
                cache_file = self.cache_dir / f"{model_file.name}.cache"
                with open(cache_file, 'wb') as cache_f:
                    cache_f.write(data)
                
                print(f"  Cached {len(data) / 1024**3:.2f} GB")
    
    def load_with_mmap(self, model_file):
        """Load model using memory mapping for zero-copy access"""
        with open(model_file, 'rb') as f:
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                # Use memory-mapped data directly
                return mm
    
    def benchmark_loading_methods(self):
        """Compare different model loading approaches"""
        from transformers import AutoModelForCausalLM
        
        results = {}
        
        # Method 1: Standard loading
        start_time = time.time()
        model1 = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="auto"
        )
        results['standard'] = time.time() - start_time
        del model1
        torch.cuda.empty_cache()
        
        # Method 2: Memory-mapped loading
        start_time = time.time()
        model2 = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="auto",
            use_safetensors=True,
            low_cpu_mem_usage=True
        )
        results['memory_mapped'] = time.time() - start_time
        del model2
        torch.cuda.empty_cache()
        
        return results
```

## ⚡ Framework-Specific Optimizations

### Ollama Performance Tuning

#### Ollama Configuration Optimization
```yaml
# /etc/ollama/config.yaml - Optimized configuration
models_path: "/opt/models/ollama"
host: "0.0.0.0:11434"

# GPU optimization
gpu_layers: -1  # Use all available GPU layers
main_gpu: 0     # Primary GPU index
tensor_split: [1.0]  # Single GPU, use all VRAM

# Memory optimization
num_ctx: 8192      # Context window size
num_batch: 512     # Batch size for processing
num_gqa: 8         # Group query attention
num_gpu: 1         # Number of GPUs
f16_kv: true       # Use FP16 for key/value cache

# Performance tuning
num_thread: 16     # Number of threads (match CPU cores)
num_parallel: 4    # Parallel request processing
rope_freq_base: 10000.0
rope_freq_scale: 1.0

# Inference parameters
temperature: 0.2
top_k: 40
top_p: 0.9
repeat_penalty: 1.1
```

#### Ollama Service Optimization
```bash
# Create optimized Ollama service configuration
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << EOF
[Service]
Environment="OLLAMA_MODELS=/opt/models/ollama"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
Environment="OLLAMA_FLASH_ATTENTION=true"
Environment="CUDA_VISIBLE_DEVICES=0"
CPUAffinity=0-7
IOSchedulingClass=1
IOSchedulingPriority=2
Nice=-5
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### vLLM Performance Optimization

#### vLLM Server Configuration
```python
# Optimized vLLM server setup
from vllm import LLM, SamplingParams
from vllm.entrypoints.openai.api_server import run_server
import asyncio

class OptimizedvLLMServer:
    def __init__(self, model_path, max_model_len=8192):
        self.model_path = model_path
        self.max_model_len = max_model_len
        
        # Optimized vLLM configuration
        self.llm = LLM(
            model=model_path,
            tensor_parallel_size=1,  # Single GPU
            dtype="half",  # FP16 for memory efficiency
            max_model_len=max_model_len,
            gpu_memory_utilization=0.9,  # Use 90% of VRAM
            max_num_batched_tokens=8192,
            max_num_seqs=256,  # Maximum concurrent sequences
            enable_prefix_caching=True,  # Cache common prefixes
            quantization=None,  # Can use "awq" or "gptq" if available
            enforce_eager=False,  # Use CUDA graphs for optimization
        )
    
    def generate_optimized(self, prompts, max_tokens=100):
        """Generate with optimized sampling parameters"""
        sampling_params = SamplingParams(
            temperature=0.2,
            top_p=0.9,
            max_tokens=max_tokens,
            frequency_penalty=0.1,
            use_beam_search=False,  # Faster than beam search
        )
        
        return self.llm.generate(prompts, sampling_params)
    
    async def start_server(self, host="0.0.0.0", port=8000):
        """Start optimized API server"""
        await run_server(
            model=self.model_path,
            host=host,
            port=port,
            tensor_parallel_size=1,
            dtype="half",
            gpu_memory_utilization=0.9,
            max_model_len=self.max_model_len,
            disable_log_requests=True,  # Reduce logging overhead
            max_num_seqs=256,
            enable_prefix_caching=True,
        )

# Usage
server = OptimizedvLLMServer("/opt/models/deepseek/deepseek-coder-6.7b")
# asyncio.run(server.start_server())
```

### Transformers Direct Optimization

#### Model Loading and Inference Optimization
```python
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from optimum.bettertransformer import BetterTransformer
import time

class OptimizedTransformersInference:
    def __init__(self, model_path, use_better_transformer=True):
        self.model_path = model_path
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_path, 
            trust_remote_code=True,
            use_fast=True  # Use fast tokenizer implementation
        )
        
        # Optimized model loading
        self.model = AutoModelForCausalLM.from_pretrained(
            model_path,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True,
            low_cpu_mem_usage=True,
            attn_implementation="flash_attention_2",  # If available
        )
        
        # Apply BetterTransformer optimization
        if use_better_transformer:
            try:
                self.model = BetterTransformer.transform(self.model)
                print("BetterTransformer optimization applied")
            except Exception as e:
                print(f"BetterTransformer not available: {e}")
        
        # Compile model for TorchScript (optional)
        self.model.eval()
        
        # Warm up model
        self._warmup_model()
    
    def _warmup_model(self):
        """Warm up the model with dummy input"""
        dummy_input = "def hello():"
        inputs = self.tokenizer(dummy_input, return_tensors="pt").to(self.model.device)
        
        with torch.no_grad():
            _ = self.model.generate(
                **inputs,
                max_new_tokens=10,
                do_sample=False,
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        print("Model warmed up successfully")
    
    @torch.inference_mode()
    def generate_optimized(self, prompt, max_new_tokens=100, temperature=0.2):
        """Optimized generation with inference mode"""
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.model.device)
        
        start_time = time.time()
        
        # Generate with optimized parameters
        outputs = self.model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            temperature=temperature,
            do_sample=temperature > 0,
            top_p=0.9 if temperature > 0 else None,
            pad_token_id=self.tokenizer.eos_token_id,
            use_cache=True,  # Enable KV cache
            early_stopping=True,
        )
        
        generation_time = time.time() - start_time
        
        # Decode response
        response = self.tokenizer.decode(
            outputs[0][len(inputs['input_ids'][0]):], 
            skip_special_tokens=True
        )
        
        tokens_generated = len(outputs[0]) - len(inputs['input_ids'][0])
        tokens_per_second = tokens_generated / generation_time
        
        return {
            'response': response,
            'tokens_generated': tokens_generated,
            'generation_time': generation_time,
            'tokens_per_second': tokens_per_second
        }
```

## 🔧 Advanced Performance Techniques

### Quantization Optimization

#### Dynamic Quantization Setup
```python
import torch
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

class QuantizedModelLoader:
    def __init__(self, model_path):
        self.model_path = model_path
    
    def load_4bit_quantized(self):
        """Load model with 4-bit quantization"""
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16,
        )
        
        model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            quantization_config=quantization_config,
            device_map="auto",
            trust_remote_code=True,
        )
        
        return model
    
    def load_8bit_quantized(self):
        """Load model with 8-bit quantization"""
        model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            load_in_8bit=True,
            device_map="auto",
            trust_remote_code=True,
        )
        
        return model
    
    def compare_quantization_methods(self):
        """Compare performance of different quantization methods"""
        import time
        from transformers import AutoTokenizer
        
        tokenizer = AutoTokenizer.from_pretrained(self.model_path, trust_remote_code=True)
        test_prompt = "def fibonacci(n):"
        inputs = tokenizer(test_prompt, return_tensors="pt")
        
        results = {}
        
        # Test FP16 (baseline)
        model_fp16 = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True,
        )
        
        torch.cuda.synchronize()
        start_time = time.time()
        with torch.no_grad():
            outputs = model_fp16.generate(**inputs.to(model_fp16.device), max_new_tokens=50)
        torch.cuda.synchronize()
        
        results['fp16'] = {
            'time': time.time() - start_time,
            'memory': torch.cuda.max_memory_allocated() / 1024**3
        }
        
        del model_fp16
        torch.cuda.empty_cache()
        
        # Test 8-bit quantization
        model_8bit = self.load_8bit_quantized()
        
        torch.cuda.synchronize()
        start_time = time.time()
        with torch.no_grad():
            outputs = model_8bit.generate(**inputs.to(model_8bit.device), max_new_tokens=50)
        torch.cuda.synchronize()
        
        results['int8'] = {
            'time': time.time() - start_time,
            'memory': torch.cuda.max_memory_allocated() / 1024**3
        }
        
        del model_8bit
        torch.cuda.empty_cache()
        
        # Test 4-bit quantization
        model_4bit = self.load_4bit_quantized()
        
        torch.cuda.synchronize()
        start_time = time.time()
        with torch.no_grad():
            outputs = model_4bit.generate(**inputs.to(model_4bit.device), max_new_tokens=50)
        torch.cuda.synchronize()
        
        results['int4'] = {
            'time': time.time() - start_time,
            'memory': torch.cuda.max_memory_allocated() / 1024**3
        }
        
        return results
```

### Batch Processing Optimization

#### Advanced Batching Strategy
```python
import asyncio
import torch
from typing import List, Dict, Any
from dataclasses import dataclass
from queue import Queue
import time

@dataclass
class InferenceRequest:
    id: str
    prompt: str
    max_tokens: int
    temperature: float
    callback: callable
    timestamp: float

class OptimizedBatchProcessor:
    def __init__(self, model, tokenizer, max_batch_size=8, max_wait_time=0.1):
        self.model = model
        self.tokenizer = tokenizer
        self.max_batch_size = max_batch_size
        self.max_wait_time = max_wait_time
        self.pending_requests = []
        self.processing = False
        
    async def add_request(self, request: InferenceRequest):
        """Add request to batch processing queue"""
        self.pending_requests.append(request)
        
        # Process batch if it's full or we've waited too long
        if (len(self.pending_requests) >= self.max_batch_size or 
            (self.pending_requests and 
             time.time() - self.pending_requests[0].timestamp > self.max_wait_time)):
            await self.process_batch()
    
    async def process_batch(self):
        """Process accumulated requests as a batch"""
        if not self.pending_requests or self.processing:
            return
        
        self.processing = True
        batch_requests = self.pending_requests[:self.max_batch_size]
        self.pending_requests = self.pending_requests[self.max_batch_size:]
        
        try:
            # Prepare batch inputs
            prompts = [req.prompt for req in batch_requests]
            max_tokens = max(req.max_tokens for req in batch_requests)
            
            # Tokenize all prompts with padding
            inputs = self.tokenizer(
                prompts,
                padding=True,
                truncation=True,
                return_tensors="pt",
                max_length=2048
            ).to(self.model.device)
            
            # Batch inference
            start_time = time.time()
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_tokens,
                    do_sample=True,
                    temperature=0.2,
                    top_p=0.9,
                    pad_token_id=self.tokenizer.eos_token_id,
                    use_cache=True
                )
            
            inference_time = time.time() - start_time
            
            # Process individual responses
            for i, request in enumerate(batch_requests):
                # Extract response for this request
                input_length = len(inputs['input_ids'][i])
                response_tokens = outputs[i][input_length:]
                response_text = self.tokenizer.decode(response_tokens, skip_special_tokens=True)
                
                # Call the callback with the result
                await request.callback({
                    'id': request.id,
                    'response': response_text,
                    'inference_time': inference_time,
                    'batch_size': len(batch_requests)
                })
        
        except Exception as e:
            # Handle batch processing errors
            for request in batch_requests:
                await request.callback({
                    'id': request.id,
                    'error': str(e),
                    'response': None
                })
        
        finally:
            self.processing = False
    
    async def start_background_processing(self):
        """Start background task for batch processing"""
        while True:
            if self.pending_requests and not self.processing:
                oldest_request_age = time.time() - self.pending_requests[0].timestamp
                if oldest_request_age > self.max_wait_time:
                    await self.process_batch()
            
            await asyncio.sleep(0.01)  # Small delay to prevent busy waiting

# Usage example
async def handle_inference_request(prompt: str, max_tokens: int = 100):
    result_queue = asyncio.Queue()
    
    async def callback(result):
        await result_queue.put(result)
    
    request = InferenceRequest(
        id=f"req_{time.time()}",
        prompt=prompt,
        max_tokens=max_tokens,
        temperature=0.2,
        callback=callback,
        timestamp=time.time()
    )
    
    await batch_processor.add_request(request)
    result = await result_queue.get()
    return result
```

## 📊 Performance Monitoring and Profiling

### Comprehensive Performance Profiler

```python
import torch
import time
import psutil
import GPUtil
import numpy as np
from contextlib import contextmanager
from typing import Dict, List

class DeepSeekPerformanceProfiler:
    def __init__(self):
        self.metrics = []
        self.current_session = None
    
    @contextmanager
    def profile_session(self, session_name: str):
        """Context manager for profiling sessions"""
        self.current_session = {
            'name': session_name,
            'start_time': time.time(),
            'start_cpu': psutil.cpu_percent(),
            'start_memory': psutil.virtual_memory().percent,
            'start_gpu_memory': self._get_gpu_memory(),
            'metrics': []
        }
        
        try:
            yield self
        finally:
            self.current_session['end_time'] = time.time()
            self.current_session['duration'] = self.current_session['end_time'] - self.current_session['start_time']
            self.current_session['end_cpu'] = psutil.cpu_percent()
            self.current_session['end_memory'] = psutil.virtual_memory().percent
            self.current_session['end_gpu_memory'] = self._get_gpu_memory()
            
            self.metrics.append(self.current_session)
            self.current_session = None
    
    def _get_gpu_memory(self):
        """Get current GPU memory usage"""
        try:
            gpus = GPUtil.getGPUs()
            if gpus:
                return gpus[0].memoryUsed / gpus[0].memoryTotal * 100
        except:
            pass
        return 0
    
    def record_inference_metrics(self, prompt: str, response: str, 
                               inference_time: float, tokens_per_second: float):
        """Record metrics for a single inference"""
        if self.current_session:
            metric = {
                'timestamp': time.time(),
                'prompt_length': len(prompt),
                'response_length': len(response),
                'inference_time': inference_time,
                'tokens_per_second': tokens_per_second,
                'cpu_percent': psutil.cpu_percent(),
                'memory_percent': psutil.virtual_memory().percent,
                'gpu_memory_percent': self._get_gpu_memory(),
            }
            self.current_session['metrics'].append(metric)
    
    def generate_performance_report(self) -> Dict:
        """Generate comprehensive performance report"""
        if not self.metrics:
            return {}
        
        # Aggregate metrics across all sessions
        all_inference_times = []
        all_tokens_per_second = []
        all_cpu_usage = []
        all_memory_usage = []
        all_gpu_memory = []
        
        for session in self.metrics:
            for metric in session.get('metrics', []):
                all_inference_times.append(metric['inference_time'])
                all_tokens_per_second.append(metric['tokens_per_second'])
                all_cpu_usage.append(metric['cpu_percent'])
                all_memory_usage.append(metric['memory_percent'])
                all_gpu_memory.append(metric['gpu_memory_percent'])
        
        report = {
            'total_sessions': len(self.metrics),
            'total_inferences': len(all_inference_times),
            'performance_summary': {
                'avg_inference_time': np.mean(all_inference_times),
                'median_inference_time': np.median(all_inference_times),
                'p95_inference_time': np.percentile(all_inference_times, 95),
                'p99_inference_time': np.percentile(all_inference_times, 99),
                'avg_tokens_per_second': np.mean(all_tokens_per_second),
                'median_tokens_per_second': np.median(all_tokens_per_second),
                'max_tokens_per_second': np.max(all_tokens_per_second),
            },
            'resource_utilization': {
                'avg_cpu_percent': np.mean(all_cpu_usage),
                'max_cpu_percent': np.max(all_cpu_usage),
                'avg_memory_percent': np.mean(all_memory_usage),
                'max_memory_percent': np.max(all_memory_usage),
                'avg_gpu_memory_percent': np.mean(all_gpu_memory),
                'max_gpu_memory_percent': np.max(all_gpu_memory),
            },
            'sessions': self.metrics
        }
        
        return report
    
    def save_report(self, filename: str = None):
        """Save performance report to file"""
        import json
        from datetime import datetime
        
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"performance_report_{timestamp}.json"
        
        report = self.generate_performance_report()
        
        with open(f"/opt/models/benchmarks/{filename}", 'w') as f:
            json.dump(report, f, indent=2)
        
        return filename

# Usage example
profiler = DeepSeekPerformanceProfiler()

# Profile a batch of inferences
with profiler.profile_session("batch_inference_test"):
    test_prompts = [
        "def fibonacci(n):",
        "class BinarySearchTree:",
        "# Create a REST API using FastAPI",
    ]
    
    for prompt in test_prompts:
        start_time = time.time()
        # Simulate inference (replace with actual inference call)
        response = f"Generated response for: {prompt}"
        inference_time = time.time() - start_time
        tokens_per_second = 25.0  # Example value
        
        profiler.record_inference_metrics(prompt, response, inference_time, tokens_per_second)

# Generate and save report
report_file = profiler.save_report()
print(f"Performance report saved to: {report_file}")
```

### Real-time Performance Dashboard

```python
import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
import pandas as pd
import requests
import time
from datetime import datetime, timedelta

class DeepSeekDashboard:
    def __init__(self, api_endpoint="http://localhost:8000"):
        self.api_endpoint = api_endpoint
        
    def test_api_performance(self, prompt: str):
        """Test API performance and return metrics"""
        start_time = time.time()
        
        try:
            response = requests.post(f"{self.api_endpoint}/v1/completions", 
                json={
                    "prompt": prompt,
                    "max_tokens": 100,
                    "temperature": 0.2
                },
                timeout=30
            )
            
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                tokens = len(result.get('choices', [{}])[0].get('text', '').split())
                tokens_per_second = tokens / response_time if response_time > 0 else 0
                
                return {
                    'success': True,
                    'response_time': response_time,
                    'tokens_generated': tokens,
                    'tokens_per_second': tokens_per_second,
                    'timestamp': datetime.now()
                }
            else:
                return {
                    'success': False,
                    'error': f"HTTP {response.status_code}",
                    'response_time': response_time,
                    'timestamp': datetime.now()
                }
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'response_time': time.time() - start_time,
                'timestamp': datetime.now()
            }
    
    def get_system_metrics(self):
        """Get current system performance metrics"""
        import psutil
        try:
            import GPUtil
            gpu = GPUtil.getGPUs()[0] if GPUtil.getGPUs() else None
        except:
            gpu = None
        
        return {
            'cpu_percent': psutil.cpu_percent(),
            'memory_percent': psutil.virtual_memory().percent,
            'gpu_temp': gpu.temperature if gpu else 0,
            'gpu_utilization': gpu.load * 100 if gpu else 0,
            'gpu_memory_percent': gpu.memoryUsed / gpu.memoryTotal * 100 if gpu else 0,
            'timestamp': datetime.now()
        }
    
    def run_dashboard(self):
        """Run Streamlit dashboard"""
        st.set_page_config(
            page_title="DeepSeek Performance Dashboard",
            page_icon="🚀",
            layout="wide"
        )
        
        st.title("🚀 DeepSeek LLM Performance Dashboard")
        
        # Sidebar controls
        st.sidebar.header("Test Configuration")
        test_prompt = st.sidebar.text_area("Test Prompt", value="def fibonacci(n):")
        auto_refresh = st.sidebar.checkbox("Auto Refresh (5s)", value=False)
        
        # Initialize session state for metrics
        if 'performance_history' not in st.session_state:
            st.session_state.performance_history = []
        if 'system_history' not in st.session_state:
            st.session_state.system_history = []
        
        # Manual test button
        if st.sidebar.button("Run Performance Test"):
            with st.spinner("Running performance test..."):
                result = self.test_api_performance(test_prompt)
                st.session_state.performance_history.append(result)
                
                if result['success']:
                    st.sidebar.success(f"✅ {result['tokens_per_second']:.1f} tokens/sec")
                else:
                    st.sidebar.error(f"❌ {result['error']}")
        
        # Auto refresh
        if auto_refresh:
            time.sleep(5)
            st.experimental_rerun()
        
        # Get current system metrics
        current_metrics = self.get_system_metrics()
        st.session_state.system_history.append(current_metrics)
        
        # Keep only last 100 data points
        if len(st.session_state.system_history) > 100:
            st.session_state.system_history = st.session_state.system_history[-100:]
        if len(st.session_state.performance_history) > 50:
            st.session_state.performance_history = st.session_state.performance_history[-50:]
        
        # Current status metrics
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("CPU Usage", f"{current_metrics['cpu_percent']:.1f}%")
        with col2:
            st.metric("Memory Usage", f"{current_metrics['memory_percent']:.1f}%")
        with col3:
            st.metric("GPU Temp", f"{current_metrics['gpu_temp']:.1f}°C")
        with col4:
            st.metric("GPU Memory", f"{current_metrics['gpu_memory_percent']:.1f}%")
        
        # Performance charts
        if st.session_state.performance_history:
            perf_df = pd.DataFrame([p for p in st.session_state.performance_history if p['success']])
            
            if not perf_df.empty:
                col1, col2 = st.columns(2)
                
                with col1:
                    st.subheader("Inference Performance")
                    fig = go.Figure()
                    fig.add_trace(go.Scatter(
                        x=perf_df['timestamp'],
                        y=perf_df['tokens_per_second'],
                        mode='lines+markers',
                        name='Tokens/Second'
                    ))
                    fig.update_layout(title="Tokens per Second Over Time")
                    st.plotly_chart(fig, use_container_width=True)
                
                with col2:
                    st.subheader("Response Time")
                    fig = go.Figure()
                    fig.add_trace(go.Scatter(
                        x=perf_df['timestamp'],
                        y=perf_df['response_time'],
                        mode='lines+markers',
                        name='Response Time (s)'
                    ))
                    fig.update_layout(title="Response Time Over Time")
                    st.plotly_chart(fig, use_container_width=True)
        
        # System monitoring charts
        if st.session_state.system_history:
            sys_df = pd.DataFrame(st.session_state.system_history)
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.subheader("System Resource Usage")
                fig = go.Figure()
                fig.add_trace(go.Scatter(x=sys_df['timestamp'], y=sys_df['cpu_percent'], name='CPU %'))
                fig.add_trace(go.Scatter(x=sys_df['timestamp'], y=sys_df['memory_percent'], name='Memory %'))
                fig.update_layout(title="CPU and Memory Usage")
                st.plotly_chart(fig, use_container_width=True)
            
            with col2:
                st.subheader("GPU Monitoring")
                fig = go.Figure()
                fig.add_trace(go.Scatter(x=sys_df['timestamp'], y=sys_df['gpu_utilization'], name='GPU Util %'))
                fig.add_trace(go.Scatter(x=sys_df['timestamp'], y=sys_df['gpu_memory_percent'], name='GPU Memory %'))
                fig.update_layout(title="GPU Utilization and Memory")
                st.plotly_chart(fig, use_container_width=True)

# Usage: streamlit run dashboard.py
if __name__ == "__main__":
    dashboard = DeepSeekDashboard()
    dashboard.run_dashboard()
```

---

**Previous:** [Best Practices](./best-practices.md) | **Next:** [Troubleshooting](./troubleshooting.md)