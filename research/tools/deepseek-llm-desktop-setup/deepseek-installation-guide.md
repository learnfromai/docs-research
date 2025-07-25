# DeepSeek Installation Guide

## 🚀 DeepSeek LLM Deployment Strategy

### Installation Framework Comparison

#### Option 1: Ollama ⭐ **RECOMMENDED FOR BEGINNERS**

**Advantages:**
- **Simple Installation**: Single command setup
- **Automatic Model Management**: Built-in download and caching
- **API Compatibility**: OpenAI-compatible REST API
- **Resource Optimization**: Automatic memory management
- **Multi-Model Support**: Easy model switching

**Best For**: Users wanting quick setup with minimal configuration

#### Option 2: vLLM **PERFORMANCE OPTIMIZED**

**Advantages:**
- **Maximum Performance**: Optimized inference engine
- **Advanced Features**: Continuous batching, quantization
- **Scalability**: Production-grade deployment
- **Framework Integration**: PyTorch native
- **Memory Efficiency**: Advanced memory management

**Best For**: Users prioritizing maximum inference performance

#### Option 3: Transformers + Accelerate **FLEXIBLE DEVELOPMENT**

**Advantages:**
- **Complete Control**: Full customization capability
- **Framework Integration**: Native HuggingFace ecosystem
- **Research Features**: Latest model architectures
- **Development Friendly**: Easy debugging and modification

**Best For**: Developers and researchers wanting maximum flexibility

## 🔧 Method 1: Ollama Installation (Recommended)

### System Prerequisites

```bash
# Ensure system is updated
sudo apt update && sudo apt upgrade -y

# Verify GPU is detected
nvidia-smi

# Check available disk space (models require significant space)
df -h /opt
```

### Ollama Installation

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Verify installation
ollama --version

# Start Ollama service
sudo systemctl enable ollama
sudo systemctl start ollama

# Check service status
sudo systemctl status ollama
```

### DeepSeek Model Installation with Ollama

```bash
# List available DeepSeek models
ollama list | grep deepseek

# Install DeepSeek-Coder 6.7B (Recommended starting point)
ollama pull deepseek-coder:6.7b

# Install DeepSeek-Coder 33B (Performance systems)
ollama pull deepseek-coder:33b

# Install DeepSeek-Chat for general use
ollama pull deepseek-chat:7b

# Verify model installation
ollama list
```

### Model Testing and Validation

```bash
# Test DeepSeek-Coder with a simple coding prompt
ollama run deepseek-coder:6.7b "Write a Python function to calculate fibonacci numbers"

# Test with context understanding
ollama run deepseek-coder:6.7b "Explain this code: def quicksort(arr): return arr if len(arr) <= 1 else quicksort([x for x in arr[1:] if x < arr[0]]) + [arr[0]] + quicksort([x for x in arr[1:] if x >= arr[0]])"

# Performance test
time ollama run deepseek-coder:6.7b "Create a REST API endpoint using FastAPI for user authentication"
```

### Ollama Configuration Optimization

```bash
# Create custom Ollama configuration
sudo mkdir -p /etc/ollama

# Configure model storage location
sudo tee /etc/ollama/config.yaml << EOF
models_path: "/opt/models/ollama"
host: "0.0.0.0:11434"
gpu_layers: -1  # Use all GPU layers
num_ctx: 8192   # Context window size
num_batch: 512  # Batch size
num_gqa: 8      # Group query attention
num_gpu: 1      # Number of GPUs
temperature: 0.2
top_k: 40
top_p: 0.9
EOF

# Create models directory
sudo mkdir -p /opt/models/ollama
sudo chown ollama:ollama /opt/models/ollama

# Restart Ollama service
sudo systemctl restart ollama
```

## 🔧 Method 2: vLLM Installation (Performance)

### Python Environment Setup

```bash
# Activate virtual environment
source ~/venv/deepseek-llm/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install PyTorch with CUDA support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Verify PyTorch CUDA support
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device count: {torch.cuda.device_count()}')"
```

### vLLM Installation

```bash
# Install vLLM with CUDA support
pip install vllm

# Install additional dependencies
pip install transformers accelerate bitsandbytes

# Verify vLLM installation
python -c "import vllm; print('vLLM installed successfully')"
```

### Model Download and Conversion

```bash
# Create model storage directory
sudo mkdir -p /opt/models/deepseek
sudo chown $USER:$USER /opt/models/deepseek

# Install Hugging Face CLI
pip install huggingface_hub

# Login to Hugging Face (optional, for gated models)
huggingface-cli login

# Download DeepSeek-Coder models
cd /opt/models/deepseek

# Download 6.7B model
huggingface-cli download deepseek-ai/deepseek-coder-6.7b-base --local-dir ./deepseek-coder-6.7b

# Download 33B model (if sufficient hardware)
huggingface-cli download deepseek-ai/deepseek-coder-33b-base --local-dir ./deepseek-coder-33b
```

### vLLM Server Setup

```bash
# Create vLLM server script
cat << 'EOF' > ~/start-deepseek-vllm.sh
#!/bin/bash

MODEL_PATH="/opt/models/deepseek/deepseek-coder-6.7b"
GPU_MEMORY_UTILIZATION="0.85"
MAX_NUM_SEQS="256"
TENSOR_PARALLEL_SIZE="1"

source ~/venv/deepseek-llm/bin/activate

python -m vllm.entrypoints.openai.api_server \
    --model $MODEL_PATH \
    --host 0.0.0.0 \
    --port 8000 \
    --gpu-memory-utilization $GPU_MEMORY_UTILIZATION \
    --max-num-seqs $MAX_NUM_SEQS \
    --tensor-parallel-size $TENSOR_PARALLEL_SIZE \
    --dtype half \
    --enforce-eager
EOF

chmod +x ~/start-deepseek-vllm.sh

# Test vLLM server
./start-deepseek-vllm.sh
```

### vLLM API Testing

```bash
# Test API endpoint (in new terminal)
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/opt/models/deepseek/deepseek-coder-6.7b",
    "prompt": "def fibonacci(n):",
    "max_tokens": 100,
    "temperature": 0.2
  }'
```

## 🔧 Method 3: Transformers Installation (Development)

### Dependencies Installation

```bash
# Activate virtual environment
source ~/venv/deepseek-llm/bin/activate

# Install core dependencies
pip install transformers accelerate torch torchvision torchaudio
pip install bitsandbytes einops sentencepiece protobuf

# Install additional utilities
pip install jupyter ipywidgets gradio streamlit
```

### Custom Inference Script

```python
# Create inference script
cat << 'EOF' > ~/deepseek_inference.py
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
import time

class DeepSeekInference:
    def __init__(self, model_name="deepseek-ai/deepseek-coder-6.7b-base", quantize=True):
        self.model_name = model_name
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        
        print(f"Loading model: {model_name}")
        print(f"Device: {self.device}")
        
        # Configure quantization for memory efficiency
        if quantize and self.device == "cuda":
            quantization_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_compute_dtype=torch.float16,
                bnb_4bit_use_double_quant=True,
                bnb_4bit_quant_type="nf4"
            )
        else:
            quantization_config = None
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
        
        # Load model
        self.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            quantization_config=quantization_config,
            device_map="auto",
            trust_remote_code=True,
            torch_dtype=torch.float16 if quantization_config is None else None
        )
        
        print("Model loaded successfully!")
    
    def generate_code(self, prompt, max_length=512, temperature=0.2, do_sample=True):
        # Tokenize input
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        
        # Generate response
        start_time = time.time()
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_length=max_length,
                temperature=temperature,
                do_sample=do_sample,
                pad_token_id=self.tokenizer.eos_token_id,
                repetition_penalty=1.1
            )
        
        generation_time = time.time() - start_time
        
        # Decode response
        response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Calculate tokens per second
        output_tokens = len(outputs[0]) - len(inputs['input_ids'][0])
        tokens_per_second = output_tokens / generation_time if generation_time > 0 else 0
        
        return {
            'response': response,
            'generation_time': generation_time,
            'tokens_per_second': tokens_per_second,
            'output_tokens': output_tokens
        }

if __name__ == "__main__":
    # Initialize inference engine
    deepseek = DeepSeekInference()
    
    # Test prompts
    test_prompts = [
        "def fibonacci(n):",
        "# Create a REST API using FastAPI\n",
        "class BinarySearchTree:",
        "// Implement quicksort in JavaScript\nfunction quicksort(arr) {"
    ]
    
    for prompt in test_prompts:
        print(f"\n{'='*50}")
        print(f"Prompt: {prompt}")
        print(f"{'='*50}")
        
        result = deepseek.generate_code(prompt)
        
        print(f"Response:\n{result['response']}")
        print(f"\nGeneration time: {result['generation_time']:.2f}s")
        print(f"Tokens per second: {result['tokens_per_second']:.1f}")
        print(f"Output tokens: {result['output_tokens']}")
EOF

# Run inference test
python ~/deepseek_inference.py
```

## 🎯 API Integration Setup

### OpenAI-Compatible API Server

```python
# Create FastAPI server for OpenAI compatibility
cat << 'EOF' > ~/deepseek_api_server.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import uvicorn
import time
from typing import Optional, List

app = FastAPI(title="DeepSeek API Server", version="1.0.0")

class CompletionRequest(BaseModel):
    prompt: str
    max_tokens: int = 100
    temperature: float = 0.2
    top_p: float = 0.9
    n: int = 1
    stream: bool = False
    stop: Optional[List[str]] = None

class CompletionResponse(BaseModel):
    id: str
    object: str = "text_completion"
    created: int
    model: str
    choices: List[dict]
    usage: dict

class DeepSeekAPI:
    def __init__(self):
        self.model_name = "deepseek-ai/deepseek-coder-6.7b-base"
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_name, trust_remote_code=True)
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_name,
            device_map="auto",
            torch_dtype=torch.float16,
            trust_remote_code=True
        )
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

    def generate_completion(self, request: CompletionRequest):
        inputs = self.tokenizer(request.prompt, return_tensors="pt").to(self.device)
        
        start_time = time.time()
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                pad_token_id=self.tokenizer.eos_token_id,
                do_sample=request.temperature > 0
            )
        
        generation_time = time.time() - start_time
        response_text = self.tokenizer.decode(outputs[0][len(inputs['input_ids'][0]):], skip_special_tokens=True)
        
        return {
            "text": response_text,
            "generation_time": generation_time,
            "prompt_tokens": len(inputs['input_ids'][0]),
            "completion_tokens": len(outputs[0]) - len(inputs['input_ids'][0]),
            "total_tokens": len(outputs[0])
        }

deepseek_api = DeepSeekAPI()

@app.post("/v1/completions", response_model=CompletionResponse)
async def create_completion(request: CompletionRequest):
    try:
        result = deepseek_api.generate_completion(request)
        
        return CompletionResponse(
            id=f"cmpl-{int(time.time())}",
            created=int(time.time()),
            model=deepseek_api.model_name,
            choices=[{
                "text": result["text"],
                "index": 0,
                "finish_reason": "stop"
            }],
            usage={
                "prompt_tokens": result["prompt_tokens"],
                "completion_tokens": result["completion_tokens"],
                "total_tokens": result["total_tokens"]
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/v1/models")
async def list_models():
    return {
        "data": [{
            "id": deepseek_api.model_name,
            "object": "model",
            "owned_by": "deepseek-ai",
            "permission": []
        }]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Install FastAPI dependencies
pip install fastapi uvicorn

# Start API server
python ~/deepseek_api_server.py
```

## 🔧 Performance Testing and Benchmarking

### Inference Performance Test

```bash
# Create benchmark script
cat << 'EOF' > ~/benchmark_deepseek.py
import time
import requests
import json
import statistics
from concurrent.futures import ThreadPoolExecutor
import argparse

def test_single_request(prompt, endpoint="http://localhost:8000/v1/completions"):
    """Test single API request"""
    start_time = time.time()
    
    payload = {
        "prompt": prompt,
        "max_tokens": 100,
        "temperature": 0.2
    }
    
    try:
        response = requests.post(endpoint, json=payload)
        response.raise_for_status()
        result = response.json()
        
        end_time = time.time()
        total_time = end_time - start_time
        
        return {
            "success": True,
            "response_time": total_time,
            "tokens": result.get("usage", {}).get("completion_tokens", 0)
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "response_time": time.time() - start_time
        }

def benchmark_performance(prompts, concurrent_requests=1, iterations=5):
    """Run performance benchmark"""
    print(f"Running benchmark with {concurrent_requests} concurrent requests, {iterations} iterations each")
    
    all_results = []
    
    for iteration in range(iterations):
        print(f"Iteration {iteration + 1}/{iterations}")
        
        with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
            futures = [executor.submit(test_single_request, prompt) for prompt in prompts]
            results = [future.result() for future in futures]
        
        successful_results = [r for r in results if r["success"]]
        all_results.extend(successful_results)
        
        if successful_results:
            avg_time = statistics.mean([r["response_time"] for r in successful_results])
            avg_tokens = statistics.mean([r["tokens"] for r in successful_results])
            tokens_per_sec = avg_tokens / avg_time if avg_time > 0 else 0
            
            print(f"  Avg response time: {avg_time:.2f}s")
            print(f"  Avg tokens generated: {avg_tokens:.1f}")
            print(f"  Tokens per second: {tokens_per_sec:.1f}")
    
    if all_results:
        response_times = [r["response_time"] for r in all_results]
        token_counts = [r["tokens"] for r in all_results]
        tokens_per_second = [t/rt if rt > 0 else 0 for t, rt in zip(token_counts, response_times)]
        
        print(f"\n=== Benchmark Results ===")
        print(f"Total successful requests: {len(all_results)}")
        print(f"Average response time: {statistics.mean(response_times):.2f}s ± {statistics.stdev(response_times):.2f}s")
        print(f"Median response time: {statistics.median(response_times):.2f}s")
        print(f"Average tokens per second: {statistics.mean(tokens_per_second):.1f} ± {statistics.stdev(tokens_per_second):.1f}")
        print(f"Peak tokens per second: {max(tokens_per_second):.1f}")

if __name__ == "__main__":
    test_prompts = [
        "def fibonacci(n):",
        "class BinarySearchTree:",
        "# Create a web server using Flask\n",
        "// Implement bubble sort\nfunction bubbleSort(arr) {",
        "SELECT * FROM users WHERE"
    ]
    
    benchmark_performance(test_prompts, concurrent_requests=1, iterations=3)
    benchmark_performance(test_prompts, concurrent_requests=2, iterations=3)
EOF

# Run benchmark
python ~/benchmark_deepseek.py
```

### Memory Usage Monitoring

```bash
# Create memory monitoring script
cat << 'EOF' > ~/monitor_deepseek_memory.sh
#!/bin/bash

echo "DeepSeek Memory Usage Monitor"
echo "============================="

while true; do
    clear
    echo "$(date)"
    echo
    
    # GPU Memory
    echo "GPU Memory Usage:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | while read line; do
        echo "  $line"
    done
    echo
    
    # System Memory
    echo "System Memory Usage:"
    free -h | grep -E "Mem:|Swap:"
    echo
    
    # Process Memory
    echo "Top Memory Consuming Processes:"
    ps aux --sort=-%mem | head -10 | awk '{printf "  %-10s %5s %5s %s\n", $1, $3, $4, $11}'
    echo
    
    # DeepSeek specific processes
    echo "DeepSeek Processes:"
    ps aux | grep -E "(python|ollama|vllm)" | grep -v grep | awk '{printf "  PID: %-6s CPU: %4s MEM: %4s CMD: %s\n", $2, $3, $4, $11}'
    
    sleep 5
done
EOF

chmod +x ~/monitor_deepseek_memory.sh
```

---

**Previous:** [Operating System Setup](./operating-system-setup.md) | **Next:** [Implementation Guide](./implementation-guide.md)