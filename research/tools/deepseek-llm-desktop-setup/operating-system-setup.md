# Operating System Setup for DeepSeek LLM Hosting

## 🐧 Linux Distribution Analysis

### Distribution Comparison for LLM Hosting

#### Ubuntu 22.04 LTS ⭐ **PRIMARY RECOMMENDATION**

**Advantages:**
- **NVIDIA Driver Support**: Excellent proprietary driver integration
- **Package Ecosystem**: Comprehensive AI/ML package availability
- **Long-Term Support**: 5-year support lifecycle
- **Community Support**: Extensive documentation and tutorials
- **Docker Integration**: Seamless container deployment
- **Hardware Compatibility**: Broad device driver support

**Specifications:**
- **Kernel**: 5.15+ (HWE stack available for newer kernels)
- **Python**: 3.10+ with pip package manager
- **CUDA Support**: Official NVIDIA repository integration
- **Package Manager**: APT with snap support

**AI/ML Ecosystem:**
- **PyTorch**: Official Ubuntu packages and conda support
- **TensorFlow**: Comprehensive GPU support
- **Transformers**: HuggingFace library compatibility
- **vLLM**: Optimized inference engine support
- **Ollama**: Native package availability

#### Pop!_OS 22.04 LTS ⭐ **NVIDIA-OPTIMIZED ALTERNATIVE**

**Advantages:**
- **NVIDIA Optimized**: Pre-installed proprietary drivers
- **Gaming Performance**: Optimizations benefit LLM inference
- **System76 Hardware Focus**: Excellent hardware compatibility
- **Ubuntu Base**: All Ubuntu ecosystem benefits
- **Auto-Tiling**: Productivity features for development

**Ideal For:**
- Users prioritizing NVIDIA compatibility
- Systems with NVIDIA graphics cards
- Developers wanting gaming-grade performance optimizations

#### Arch Linux

**Advantages:**
- **Bleeding Edge**: Latest kernel and driver versions
- **Performance**: Minimal overhead, maximum performance
- **Customization**: Complete control over system configuration
- **AUR Access**: Extensive package repository
- **Rolling Release**: Continuous updates without version upgrades

**Disadvantages:**
- **Complexity**: Requires advanced Linux knowledge
- **Stability Risk**: Frequent updates can introduce issues
- **Time Investment**: Significant setup and maintenance overhead

**Recommended For**: Advanced users prioritizing maximum performance

#### Fedora Workstation

**Advantages:**
- **Modern Stack**: Latest kernel and software versions
- **Red Hat Backing**: Enterprise-grade development
- **GNOME Integration**: Polished desktop experience
- **Security Focus**: SELinux and secure boot support

**Disadvantages:**
- **Short Lifecycle**: 13-month support per version
- **Package Availability**: Smaller AI/ML ecosystem than Ubuntu
- **NVIDIA Drivers**: Requires manual setup and maintenance

## 🔧 Ubuntu 22.04 LTS Installation Guide

### Pre-Installation Preparation

#### BIOS/UEFI Configuration

1. **Enable UEFI Mode** (not Legacy/CSM)
2. **Secure Boot**: Can be enabled (Ubuntu supports it)
3. **Enable Virtualization**: AMD-V/VT-x for Docker support
4. **Memory Settings**: Enable XMP/DOCP profiles for DDR5
5. **PCIe Configuration**: Ensure GPU slot runs at x16

#### Installation Media Creation

```bash
# Download Ubuntu 22.04 LTS Desktop
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso

# Create bootable USB (Linux)
sudo dd if=ubuntu-22.04.3-desktop-amd64.iso of=/dev/sdX bs=4M status=progress

# Verify checksum
sha256sum ubuntu-22.04.3-desktop-amd64.iso
```

### Installation Process

#### Partitioning Strategy for LLM Workloads

**Single Drive Setup (2TB+ NVMe):**
```
/boot/efi     512MB   (EFI System Partition)
/boot        1GB      (Boot partition)  
/            50GB     (Root filesystem - ext4)
/home        100GB    (User data - ext4)
/opt         1.8TB    (Models and applications - ext4)
swap         32GB     (Swap file recommended over partition)
```

**Dual Drive Setup (OS + Model Storage):**
```
# Drive 1 (1TB NVMe) - System
/boot/efi     512MB   
/boot        1GB      
/            50GB     
/home        950GB    

# Drive 2 (2TB+ NVMe) - Models
/models      2TB      (Mount as /opt/models - ext4)
```

#### Installation Configuration

1. **Language**: English (or preferred language)
2. **Keyboard**: US (or appropriate layout)
3. **Installation Type**: Normal installation with third-party software
4. **Disk Setup**: Manual partitioning (as above)
5. **User Setup**: Create primary user account
6. **Encryption**: Consider full disk encryption for security

### Post-Installation System Configuration

#### Essential Updates and Packages

```bash
# System update
sudo apt update && sudo apt upgrade -y

# Install essential development tools
sudo apt install -y \
    build-essential \
    cmake \
    curl \
    wget \
    git \
    vim \
    htop \
    neofetch \
    tree \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Python development environment
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# System monitoring tools
sudo apt install -y \
    nvidia-smi \
    nvtop \
    iotop \
    nethogs \
    sensors-detect \
    lm-sensors
```

#### NVIDIA Driver Installation

```bash
# Check GPU detection
lspci | grep -i nvidia

# Add NVIDIA driver repository
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

# Install NVIDIA driver (latest stable)
sudo apt install -y nvidia-driver-535
# Or for latest: sudo apt install -y nvidia-driver-545

# Reboot system
sudo reboot

# Verify installation
nvidia-smi
```

#### CUDA Toolkit Installation

```bash
# Install CUDA toolkit
sudo apt install -y nvidia-cuda-toolkit

# Add CUDA to PATH (add to ~/.bashrc)
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Verify CUDA installation
nvcc --version
```

### System Optimization for LLM Workloads

#### Kernel Parameter Optimization

```bash
# Edit GRUB configuration
sudo nano /etc/default/grub

# Add/modify GRUB_CMDLINE_LINUX_DEFAULT
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"

# Update GRUB
sudo update-grub
```

#### Memory and Swap Configuration

```bash
# Create swap file if not created during installation
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Add to fstab for persistence
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimize swap usage for LLM workloads
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
```

#### GPU Memory Management

```bash
# Create systemd service for GPU persistence
sudo nano /etc/systemd/system/nvidia-persistenced.service

[Unit]
Description=NVIDIA Persistence Daemon
Wants=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --verbose
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced
Restart=always

[Install]
WantedBy=multi-user.target

# Enable service
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced
```

### Development Environment Setup

#### Python Virtual Environment

```bash
# Install pyenv for Python version management
curl https://pyenv.run | bash

# Add to shell configuration
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Python 3.11 (optimal for LLM frameworks)
pyenv install 3.11.6
pyenv global 3.11.6

# Create virtual environment for LLM work
python -m venv ~/venv/deepseek-llm
source ~/venv/deepseek-llm/bin/activate
```

#### Docker Installation

```bash
# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt update
sudo apt install -y nvidia-docker2
sudo systemctl restart docker

# Test GPU access in Docker
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### Performance Monitoring Setup

#### System Monitoring Tools

```bash
# Install monitoring utilities
sudo apt install -y \
    htop \
    btop \
    nvtop \
    iotop \
    nethogs \
    bandwhich

# Install GPU monitoring
pip install gpustat

# Create monitoring script
cat << 'EOF' > ~/monitor-system.sh
#!/bin/bash
echo "=== System Overview ==="
neofetch --config none --colors 4 1 8 6 7 7

echo -e "\n=== GPU Status ==="
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits

echo -e "\n=== Memory Usage ==="
free -h

echo -e "\n=== CPU Usage ==="
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1

echo -e "\n=== Disk Usage ==="
df -h / /home /opt 2>/dev/null | grep -E "/$|/home$|/opt$"
EOF

chmod +x ~/monitor-system.sh
```

### Security Hardening

#### UFW Firewall Configuration

```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH (if using remote access)
sudo ufw allow ssh

# Allow specific ports for LLM APIs
sudo ufw allow 8000/tcp  # Common LLM API port
sudo ufw allow 11434/tcp # Ollama default port

# Check status
sudo ufw status verbose
```

#### Automatic Security Updates

```bash
# Install unattended upgrades
sudo apt install -y unattended-upgrades

# Configure automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Verify configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

### Backup and Recovery Setup

#### System Backup Strategy

```bash
# Install Timeshift for system snapshots
sudo apt install -y timeshift

# Configure automated snapshots (GUI or CLI)
sudo timeshift --create --comments "Initial LLM system setup"

# Create backup script for model data
cat << 'EOF' > ~/backup-models.sh
#!/bin/bash
BACKUP_DIR="/backup/models"
MODEL_DIR="/opt/models"
DATE=$(date +%Y%m%d_%H%M%S)

sudo mkdir -p $BACKUP_DIR
sudo rsync -avh --progress $MODEL_DIR/ $BACKUP_DIR/models_backup_$DATE/

echo "Model backup completed: $BACKUP_DIR/models_backup_$DATE"
EOF

chmod +x ~/backup-models.sh
```

## 🎯 Optimization Verification

### Performance Testing Scripts

```bash
# CPU performance test
cat << 'EOF' > ~/test-cpu.py
import time
import multiprocessing as mp

def cpu_stress(duration=10):
    end_time = time.time() + duration
    while time.time() < end_time:
        pass

if __name__ == "__main__":
    cores = mp.cpu_count()
    print(f"Testing CPU performance with {cores} cores...")
    
    start_time = time.time()
    processes = []
    
    for i in range(cores):
        p = mp.Process(target=cpu_stress, args=(10,))
        p.start()
        processes.append(p)
    
    for p in processes:
        p.join()
    
    end_time = time.time()
    print(f"CPU stress test completed in {end_time - start_time:.2f} seconds")
EOF

python ~/test-cpu.py
```

### System Health Check

```bash
# Create comprehensive health check script
cat << 'EOF' > ~/health-check.sh
#!/bin/bash
echo "=== DeepSeek LLM System Health Check ==="
echo "Date: $(date)"
echo

# CPU Information
echo "CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "Cores: $(nproc)"
echo "Temperature: $(sensors | grep 'Tctl' | awk '{print $2}' | head -1 || echo 'N/A')"

# Memory Information
echo "RAM: $(free -h | grep 'Mem:' | awk '{print $3"/"$2}')"
echo "Swap: $(free -h | grep 'Swap:' | awk '{print $3"/"$2}')"

# GPU Information
if command -v nvidia-smi &> /dev/null; then
    echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
    echo "GPU Temp: $(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)°C"
    echo "GPU Memory: $(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader)"
fi

# Storage Information
echo "Disk Usage:"
df -h / /home /opt 2>/dev/null | grep -E "/$|/home$|/opt$"

# Network Status
echo "Network: $(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || echo 'N/A')"

echo -e "\n=== System Status: Healthy ==="
EOF

chmod +x ~/health-check.sh
./health-check.sh
```

---

**Previous:** [Hardware Specifications](./hardware-specifications.md) | **Next:** [DeepSeek Installation Guide](./deepseek-installation-guide.md)