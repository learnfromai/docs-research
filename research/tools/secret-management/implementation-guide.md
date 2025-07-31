# Implementation Guide: Secret Management Setup

## 🎯 Implementation Strategy

This guide provides step-by-step instructions for implementing secret management solutions, starting with HashiCorp Vault as the primary recommendation, followed by AWS Secrets Manager for AWS-centric deployments.

## 🏗️ Architecture Overview

### Recommended Architecture for EdTech Platform

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developers    │    │   CI/CD System  │    │  Applications   │
│                 │    │                 │    │                 │
│ • CLI Access    │    │ • Pipeline Auth │    │ • Runtime Auth  │
│ • Web UI        │    │ • Secret Inject │    │ • Auto Rotation │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │    HashiCorp Vault       │
                    │                          │
                    │ • Secrets Engine         │
                    │ • Authentication         │
                    │ • Authorization          │
                    │ • Audit Logging          │
                    └──────────────┬───────────┘
                                   │
                    ┌─────────────┴─────────────┐
                    │   Storage Backend        │
                    │                          │
                    │ • Encrypted at Rest      │
                    │ • High Availability      │
                    │ • Backup/Recovery        │
                    └──────────────────────────┘
```

## 🔧 HashiCorp Vault Implementation

### Prerequisites

- Docker and Docker Compose installed
- SSL certificates for production deployment
- Domain name with DNS configuration
- Basic understanding of PKI and encryption concepts

### Step 1: Development Environment Setup

#### 1.1 Create Docker Compose Configuration

```yaml
# docker-compose.vault.yml
version: '3.8'

services:
  vault:
    image: hashicorp/vault:1.15.6
    container_name: vault-server
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: myroot
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    volumes:
      - vault-data:/vault/data
      - vault-logs:/vault/logs
      - ./vault-config:/vault/config
    command: vault server -dev -dev-listen-address=0.0.0.0:8200

  vault-ui:
    image: djenriquez/vault-ui:latest
    container_name: vault-ui
    ports:
      - "8000:8000"
    environment:
      VAULT_URL_DEFAULT: http://vault:8200
      VAULT_AUTH_DEFAULT: TOKEN
    depends_on:
      - vault

volumes:
  vault-data:
  vault-logs:
```

#### 1.2 Start Development Environment

```bash
# Start Vault in development mode
docker-compose -f docker-compose.vault.yml up -d

# Export Vault environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='myroot'

# Verify Vault is running
vault status
```

### Step 2: Production Configuration

#### 2.1 Create Production Configuration File

```hcl
# vault-config/vault.hcl
ui = true
disable_mlock = false

storage "consul" {
  address = "127.0.0.1:8500"
  path = "vault/"
}

# Alternative: File storage for single instance
# storage "file" {
#   path = "/vault/data"
# }

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/vault/config/vault-cert.pem"
  tls_key_file = "/vault/config/vault-key.pem"
}

# Enable Prometheus metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Seal configuration for auto-unseal
seal "awskms" {
  region = "us-east-1"
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  endpoint = "https://kms.us-east-1.amazonaws.com"
}

api_addr = "https://vault.yourdomain.com:8200"
cluster_addr = "https://vault.yourdomain.com:8201"
```

#### 2.2 Initialize and Unseal Vault

```bash
# Initialize Vault (run once)
vault operator init -key-shares=5 -key-threshold=3

# Save the unseal keys and root token securely
# Example output:
# Unseal Key 1: base64-key-1
# Unseal Key 2: base64-key-2
# ...
# Root Token: hvs.root-token

# Unseal Vault (required after restart)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### Step 3: Authentication Setup

#### 3.1 Enable and Configure OIDC Authentication

```bash
# Enable OIDC auth method
vault auth enable oidc

# Configure OIDC provider (example with GitHub)
vault write auth/oidc/config \
    oidc_discovery_url="https://token.actions.githubusercontent.com" \
    oidc_client_id="your-github-app-id" \
    oidc_client_secret="your-github-app-secret" \
    default_role="developer"

# Create developer role
vault write auth/oidc/role/developer \
    bound_audiences="your-github-app-id" \
    bound_claims='{"repository_owner":"your-org"}' \
    user_claim="actor" \
    policies="developer-policy"
```

#### 3.2 Create Policies

```bash
# Create developer policy
vault policy write developer-policy - <<EOF
# Allow developers to read/write secrets in their projects
path "secret/data/projects/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow reading shared configuration
path "secret/data/shared/*" {
  capabilities = ["read", "list"]
}

# Allow token self-management
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

# Create application policy
vault policy write app-policy - <<EOF
# Applications can only read their specific secrets
path "secret/data/apps/{{identity.entity.metadata.app_name}}/*" {
  capabilities = ["read"]
}
EOF
```

### Step 4: Secrets Engine Configuration

#### 4.1 Enable and Configure KV Secrets Engine

```bash
# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Create directory structure
vault kv put secret/shared/database \
    host="db.example.com" \
    port="5432" \
    name="edtech_prod"

vault kv put secret/projects/edtech-api/prod \
    database_url="postgresql://user:pass@db.example.com:5432/edtech_prod" \
    jwt_secret="super-secret-jwt-key" \
    stripe_secret_key="sk_live_..." \
    sendgrid_api_key="SG...."

vault kv put secret/projects/edtech-web/prod \
    api_url="https://api.edtech.com" \
    stripe_publishable_key="pk_live_..." \
    google_analytics_id="UA-..."
```

#### 4.2 Enable Database Secrets Engine

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/edtech?sslmode=disable" \
    allowed_roles="readonly,readwrite" \
    username="vault_admin" \
    password="vault_admin_password"

# Create dynamic database roles
vault write database/roles/readonly \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

vault write database/roles/readwrite \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
```

## ☁️ AWS Secrets Manager Implementation

### Step 1: Setup AWS Secrets Manager

#### 1.1 Install AWS CLI and Configure

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json
```

#### 1.2 Create Secrets via AWS CLI

```bash
# Create database connection secret
aws secretsmanager create-secret \
    --name "edtech/prod/database" \
    --description "Production database credentials" \
    --secret-string '{
        "host": "db.example.com",
        "port": "5432",
        "username": "edtech_user",
        "password": "secure_password",
        "database": "edtech_prod"
    }'

# Create API keys secret
aws secretsmanager create-secret \
    --name "edtech/prod/api-keys" \
    --description "Production API keys" \
    --secret-string '{
        "stripe_secret_key": "sk_live_...",
        "sendgrid_api_key": "SG....",
        "jwt_secret": "super-secret-jwt-key"
    }'
```

#### 1.3 Enable Automatic Rotation

```bash
# Create Lambda function for rotation (example for RDS)
aws secretsmanager rotate-secret \
    --secret-id "edtech/prod/database" \
    --rotation-lambda-arn "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRDSRotation" \
    --rotation-rules AutomaticallyAfterDays=30
```

## 🔗 Application Integration

### Step 1: Environment Variable Injection

#### 1.1 Vault Agent Configuration

```hcl
# vault-agent.hcl
pid_file = "./pidfile"

vault {
  address = "https://vault.yourdomain.com:8200"
}

auto_auth {
  method "aws" {
    mount_path = "auth/aws"
    config = {
      type = "iam"
      role = "app-role"
    }
  }

  sink "file" {
    config = {
      path = "/home/vault/.vault-token"
    }
  }
}

template {
  source = "/etc/vault-agent/app.env.tpl"
  destination = "/app/.env"
  perms = 0600
  command = "supervisorctl restart app"
}
```

#### 1.2 Environment Template

```bash
# app.env.tpl
{{- with secret "secret/data/projects/edtech-api/prod" }}
DATABASE_URL="{{ .Data.data.database_url }}"
JWT_SECRET="{{ .Data.data.jwt_secret }}"
STRIPE_SECRET_KEY="{{ .Data.data.stripe_secret_key }}"
SENDGRID_API_KEY="{{ .Data.data.sendgrid_api_key }}"
{{- end }}
```

### Step 2: Direct API Integration

#### 2.1 Node.js/TypeScript Integration

```typescript
// vault-client.ts
import { VaultApi } from 'node-vault-client';

interface DatabaseConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  database: string;
}

class SecretManager {
  private vault: VaultApi;

  constructor() {
    this.vault = new VaultApi({
      endpoint: process.env.VAULT_ADDR || 'https://vault.yourdomain.com:8200',
      token: process.env.VAULT_TOKEN,
    });
  }

  async getDatabaseConfig(): Promise<DatabaseConfig> {
    try {
      const secret = await this.vault.read('secret/data/projects/edtech-api/prod');
      return {
        host: secret.data.data.database_host,
        port: parseInt(secret.data.data.database_port),
        username: secret.data.data.database_username,
        password: secret.data.data.database_password,
        database: secret.data.data.database_name,
      };
    } catch (error) {
      console.error('Failed to retrieve database config:', error);
      throw new Error('Database configuration unavailable');
    }
  }

  async getApiKeys(): Promise<{ stripe: string; sendgrid: string; jwt: string }> {
    const secret = await this.vault.read('secret/data/projects/edtech-api/prod');
    return {
      stripe: secret.data.data.stripe_secret_key,
      sendgrid: secret.data.data.sendgrid_api_key,
      jwt: secret.data.data.jwt_secret,
    };
  }

  async getDynamicDatabaseCredentials(): Promise<{ username: string; password: string }> {
    const credentials = await this.vault.read('database/creds/readwrite');
    return {
      username: credentials.data.username,
      password: credentials.data.password,
    };
  }
}

export default SecretManager;
```

#### 2.2 AWS Secrets Manager Integration

```typescript
// aws-secrets-client.ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

class AWSSecretManager {
  private client: SecretsManagerClient;

  constructor() {
    this.client = new SecretsManagerClient({
      region: process.env.AWS_REGION || 'us-east-1',
    });
  }

  async getSecret(secretName: string): Promise<any> {
    try {
      const command = new GetSecretValueCommand({
        SecretId: secretName,
      });
      
      const response = await this.client.send(command);
      return JSON.parse(response.SecretString || '{}');
    } catch (error) {
      console.error(`Failed to retrieve secret ${secretName}:`, error);
      throw error;
    }
  }

  async getDatabaseConfig(): Promise<DatabaseConfig> {
    return await this.getSecret('edtech/prod/database');
  }

  async getApiKeys(): Promise<{ stripe_secret_key: string; sendgrid_api_key: string; jwt_secret: string }> {
    return await this.getSecret('edtech/prod/api-keys');
  }
}
```

## 🚀 CI/CD Integration

### Step 1: GitHub Actions with Vault

```yaml
# .github/workflows/deploy.yml
name: Deploy Application

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Authenticate with Vault
        uses: hashicorp/vault-action@v2
        with:
          url: https://vault.yourdomain.com:8200
          method: github
          githubToken: ${{ secrets.GITHUB_TOKEN }}
          secrets: |
            secret/data/projects/edtech-api/prod database_url | DATABASE_URL ;
            secret/data/projects/edtech-api/prod stripe_secret_key | STRIPE_SECRET_KEY ;
            secret/data/projects/edtech-api/prod sendgrid_api_key | SENDGRID_API_KEY
      
      - name: Deploy Application
        run: |
          echo "DATABASE_URL=${{ env.DATABASE_URL }}" >> .env
          echo "STRIPE_SECRET_KEY=${{ env.STRIPE_SECRET_KEY }}" >> .env
          echo "SENDGRID_API_KEY=${{ env.SENDGRID_API_KEY }}" >> .env
          # Deploy commands here
```

### Step 2: AWS Secrets Manager with GitHub Actions

```yaml
# .github/workflows/deploy-aws.yml
name: Deploy with AWS Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Retrieve secrets
        run: |
          DATABASE_CONFIG=$(aws secretsmanager get-secret-value --secret-id edtech/prod/database --query SecretString --output text)
          API_KEYS=$(aws secretsmanager get-secret-value --secret-id edtech/prod/api-keys --query SecretString --output text)
          
          echo "DATABASE_URL=$(echo $DATABASE_CONFIG | jq -r '.database_url')" >> $GITHUB_ENV
          echo "STRIPE_SECRET_KEY=$(echo $API_KEYS | jq -r '.stripe_secret_key')" >> $GITHUB_ENV
```

## 🔒 Security Hardening

### Step 1: Network Security

```bash
# Configure firewall rules
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 8200/tcp   # Vault API
sudo ufw allow 8201/tcp   # Vault cluster
sudo ufw enable

# Configure Vault TLS
vault write pki/config/urls \
    issuing_certificates="https://vault.yourdomain.com:8200/v1/pki/ca" \
    crl_distribution_points="https://vault.yourdomain.com:8200/v1/pki/crl"
```

### Step 2: Audit Logging

```bash
# Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# Create centralized logging
vault audit enable syslog tag="vault" facility="AUTH"
```

### Step 3: Monitoring Setup

```yaml
# docker-compose.monitoring.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
```

## ✅ Verification Steps

### Step 1: Functionality Testing

```bash
# Test secret creation and retrieval
vault kv put secret/test-secret username=testuser password=testpass
vault kv get secret/test-secret

# Test authentication
vault auth -method=oidc

# Test policy enforcement
vault token create -policy=developer-policy
```

### Step 2: Security Testing

```bash
# Test TLS configuration
openssl s_client -connect vault.yourdomain.com:8200

# Verify audit logs
tail -f /vault/logs/audit.log

# Test backup and recovery
vault operator backup vault-backup.db
```

## 🔗 Navigation

← [Back to Executive Summary](./executive-summary.md) | [Next: Best Practices](./best-practices.md) →

---

*Complete implementation typically takes 2-4 weeks depending on infrastructure complexity and team size*