# Hardware Specifications for DeepSeek LLM Desktop Setup

## 🔧 Component Analysis & Recommendations

### CPU: AMD Ryzen Selection Strategy

#### Why AMD Ryzen for LLM Hosting

**Advantages:**
- **Superior Memory Bandwidth**: DDR5 support with higher speeds
- **3D V-Cache Technology**: Massive L3 cache benefits LLM inference
- **Power Efficiency**: Lower TDP compared to Intel equivalents
- **PCIe 5.0 Support**: Future GPU and storage compatibility
- **Linux Compatibility**: Excellent driver support and optimization

**Specific Model Recommendations:**

#### Budget Tier: Ryzen 5 7600X
- **Cores/Threads**: 6C/12T
- **Base/Boost Clock**: 4.7/5.3 GHz
- **L3 Cache**: 32MB
- **TDP**: 105W
- **Price**: ~$200-250
- **Best For**: DeepSeek-Coder 1.3B-6.7B models
- **Performance**: 15-25 tokens/second with 6.7B models

#### Performance Tier: Ryzen 7 7800X3D ⭐ **RECOMMENDED**
- **Cores/Threads**: 8C/16T
- **Base/Boost Clock**: 4.2/5.0 GHz
- **3D V-Cache**: 96MB L3 cache
- **TDP**: 120W
- **Price**: ~$350-400
- **Best For**: DeepSeek-Coder 6.7B-33B models
- **Performance**: 20-35 tokens/second with optimal memory configuration

**Why 7800X3D is Optimal:**
- 3D V-Cache dramatically improves LLM inference performance
- Lower power consumption than 7950X3D
- Excellent single-thread performance for model loading
- Optimal price-to-performance ratio for AI workloads

#### Enthusiast Tier: Ryzen 9 7950X3D
- **Cores/Threads**: 16C/32T
- **Base/Boost Clock**: 4.2/5.7 GHz
- **3D V-Cache**: 128MB L3 cache
- **TDP**: 120W
- **Price**: ~$550-650
- **Best For**: DeepSeek-Coder 33B+ models, multi-model hosting
- **Performance**: 25-40 tokens/second with parallel processing capability

### Memory: DDR5 Configuration Strategy

#### Capacity Requirements by Model Size

| Model Size | Minimum RAM | Recommended RAM | Optimal RAM |
|------------|-------------|-----------------|-------------|
| **1.3B** | 16GB | 32GB | 32GB |
| **6.7B** | 32GB | 64GB | 64GB |
| **33B** | 64GB | 128GB | 128GB |
| **67B** | 128GB | 256GB | 256GB |

#### Memory Specifications

**Budget Configuration: 32GB DDR5-5600**
- **Kit**: 2x16GB DDR5-5600 CL36
- **Brands**: G.Skill Flare X5, Corsair Vengeance
- **Price**: ~$180-220
- **Expandability**: 2 slots free for future upgrades

**Performance Configuration: 64GB DDR5-5600** ⭐ **RECOMMENDED**
- **Kit**: 2x32GB DDR5-5600 CL36
- **Brands**: G.Skill Trident Z5, Corsair Dominator
- **Price**: ~$350-450
- **Benefits**: Handles 33B models with room for OS and applications

**Enthusiast Configuration: 128GB DDR5-5600**
- **Kit**: 4x32GB DDR5-5600 CL36
- **Brands**: G.Skill Trident Z5, Kingston Fury Beast
- **Price**: ~$700-900
- **Benefits**: Maximum model support, multi-model concurrent hosting

#### Memory Optimization Tips
- **Enable EXPO/XMP profiles** for rated speeds
- **Verify QVL compatibility** with motherboard
- **Consider ECC memory** for professional workloads (Ryzen Pro)

### GPU: NVIDIA RTX Selection for AI Acceleration

#### VRAM Requirements Analysis

**Critical Considerations:**
- **Model quantization** can reduce VRAM requirements by 50-75%
- **FP16 precision** requires ~2GB per billion parameters
- **INT8 quantization** requires ~1GB per billion parameters
- **INT4 quantization** requires ~0.5GB per billion parameters

#### GPU Recommendations by Tier

#### Budget Tier: RTX 4060 Ti 16GB
- **CUDA Cores**: 4352
- **VRAM**: 16GB GDDR6
- **Memory Bus**: 128-bit
- **Power**: 165W
- **Price**: ~$450-500
- **Best For**: DeepSeek-Coder 6.7B models with quantization
- **Performance**: 20-30 tokens/second with 4-bit quantization

#### Performance Tier: RTX 4070 Ti Super 16GB ⭐ **RECOMMENDED**
- **CUDA Cores**: 8448
- **VRAM**: 16GB GDDR6X
- **Memory Bus**: 256-bit
- **Memory Bandwidth**: 672 GB/s
- **Power**: 285W
- **Price**: ~$750-850
- **Best For**: DeepSeek-Coder 6.7B-33B models
- **Performance**: 25-40 tokens/second with mixed precision

#### Enthusiast Tier: RTX 4080 Super 16GB / RTX 4090 24GB
**RTX 4080 Super 16GB:**
- **CUDA Cores**: 10240
- **VRAM**: 16GB GDDR6X
- **Memory Bandwidth**: 736 GB/s
- **Power**: 320W
- **Price**: ~$1000-1100

**RTX 4090 24GB:**
- **CUDA Cores**: 16384
- **VRAM**: 24GB GDDR6X
- **Memory Bandwidth**: 1008 GB/s
- **Power**: 450W
- **Price**: ~$1500-1800
- **Best For**: DeepSeek-Coder 33B+ models, maximum performance

#### Alternative: AMD Radeon Considerations
**Pros:**
- **Lower cost** compared to NVIDIA equivalents
- **Higher VRAM** on some models (7900 XTX 24GB)
- **Open source drivers** (ROCm support)

**Cons:**
- **Limited software support** for LLM inference
- **ROCm compatibility issues** with some frameworks
- **Generally lower performance** for AI workloads

**Recommendation**: Stick with NVIDIA for optimal compatibility and performance.

### Storage: NVMe SSD Requirements

#### Storage Analysis for LLM Hosting

**Space Requirements:**
- **DeepSeek-Coder 6.7B**: ~13GB (FP16), ~7GB (INT8), ~4GB (INT4)
- **DeepSeek-Coder 33B**: ~66GB (FP16), ~33GB (INT8), ~17GB (INT4)
- **Operating System**: 50GB (Ubuntu with development tools)
- **Model Cache**: 50-100GB (multiple model versions)
- **Development Environment**: 100GB (IDEs, dependencies, projects)

#### Storage Recommendations

**Budget: 1TB PCIe Gen3 NVMe**
- **Models**: Samsung 980, WD Blue SN570
- **Performance**: 3500/3000 MB/s read/write
- **Price**: ~$70-90
- **Sufficient For**: 1-2 models with basic development setup

**Performance: 2TB PCIe Gen4 NVMe** ⭐ **RECOMMENDED**
- **Models**: Samsung 980 Pro, WD Black SN850X
- **Performance**: 7000/6900 MB/s read/write
- **Price**: ~$150-200
- **Benefits**: Fast model loading, multiple model storage

**Enthusiast: 4TB PCIe Gen4 NVMe**
- **Models**: Samsung 990 Pro, Crucial T700
- **Performance**: 7400/6900 MB/s read/write
- **Price**: ~$350-450
- **Benefits**: Extensive model library, development workspace

#### Storage Optimization
- **Enable TRIM support** for long-term performance
- **Monitor disk health** using smartctl
- **Consider RAID 0** for maximum model loading speed (advanced users)

### Motherboard: AM5 Platform Selection

#### Feature Requirements
- **CPU Support**: AM5 socket for Ryzen 7000 series
- **Memory Support**: DDR5 with 128GB+ capacity
- **PCIe Slots**: PCIe 5.0 x16 for GPU, PCIe 4.0 for storage
- **Connectivity**: Multiple USB ports, 2.5GbE networking
- **VRM Quality**: Robust power delivery for high-end CPUs

#### Recommended Motherboards

**Budget: B650 Chipset**
- **Models**: ASUS B650M-Plus, MSI B650M Pro
- **Price**: ~$150-200
- **Features**: Basic overclocking, adequate VRM
- **Suitable For**: Ryzen 5/7 CPUs with standard configurations

**Performance: X670 Chipset** ⭐ **RECOMMENDED**
- **Models**: ASUS X670E-Plus, MSI X670E Gaming Plus
- **Price**: ~$250-350
- **Features**: PCIe 5.0, superior VRM, extensive connectivity
- **Suitable For**: All Ryzen 7000 CPUs with maximum features

**Enthusiast: X670E Chipset**
- **Models**: ASUS ROG X670E Hero, MSI X670E Godlike
- **Price**: ~$400-600
- **Features**: Premium VRM, maximum overclocking, advanced features

### Power Supply: Efficiency and Reliability

#### Power Requirements Calculation

**Budget System (7600X + RTX 4060 Ti):**
- **Total System Power**: ~450W under full load
- **Recommended PSU**: 650W 80+ Gold
- **Models**: EVGA 650 GQ, Corsair RM650x

**Performance System (7800X3D + RTX 4070 Ti Super):**
- **Total System Power**: ~550W under full load
- **Recommended PSU**: 750W-850W 80+ Gold ⭐ **RECOMMENDED**
- **Models**: Seasonic Focus GX-850, be quiet! Straight Power 11

**Enthusiast System (7950X3D + RTX 4090):**
- **Total System Power**: ~750W under full load
- **Recommended PSU**: 1000W 80+ Platinum
- **Models**: Corsair HX1000, EVGA SuperNOVA 1000 P5

#### PSU Selection Criteria
- **80+ Gold minimum** for efficiency
- **Modular cables** for clean builds
- **10-year warranty** for long-term reliability
- **Japanese capacitors** for stability under AI workloads

### Cooling: Thermal Management Strategy

#### CPU Cooling Requirements

**Budget: Air Cooling**
- **Models**: Noctua NH-U12S, be quiet! Dark Rock 4
- **TDP Rating**: 150W+
- **Compatibility**: Adequate for Ryzen 5/7 non-X3D CPUs

**Performance: AIO Liquid Cooling** ⭐ **RECOMMENDED**
- **Models**: Arctic Liquid Freezer II 240/280, Corsair H100i
- **Radiator Size**: 240mm minimum for X3D CPUs
- **Benefits**: Lower temperatures, quieter operation under sustained loads

**GPU Cooling Considerations:**
- **Custom fan curves** for optimal noise/performance balance
- **Undervolt/underclock** for efficiency without performance loss
- **Case airflow** crucial for multi-hour inference sessions

### Case: Airflow and Expandability

#### Case Requirements
- **GPU Clearance**: 350mm+ for high-end graphics cards
- **CPU Cooler Height**: 165mm+ for large air coolers
- **Motherboard Support**: ATX/E-ATX compatibility
- **Drive Bays**: Multiple 2.5" SSD mounts
- **Airflow Design**: Front intake, rear/top exhaust

#### Recommended Cases
- **Budget**: Fractal Design Core 1000, Cooler Master MasterBox
- **Performance**: Fractal Design Meshify C, be quiet! Pure Base 500DX
- **Enthusiast**: Fractal Design Torrent, Lian Li O11 Dynamic

---

**Previous:** [Executive Summary](./executive-summary.md) | **Next:** [Operating System Setup](./operating-system-setup.md)