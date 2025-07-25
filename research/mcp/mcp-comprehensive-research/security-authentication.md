# Security and Authentication

## Overview

Security is a critical consideration when implementing MCP servers and integrating them with GitHub Copilot. This document covers security best practices, authentication mechanisms, and threat mitigation strategies for MCP implementations.

## MCP Security Model

### Core Security Principles

**Process Isolation**
- Each MCP server runs in its own process
- Limited access to system resources
- Controlled communication through STDIO/SSE
- No direct network exposure required

**Principle of Least Privilege**
- Servers only access required resources
- Scoped permissions for each tool/resource
- User-controlled authorization
- Environment-based access control

**Data Locality**
- Sensitive data can remain local
- No mandatory cloud transmission
- User controls data sharing
- Private data processing

### Transport Security

**STDIO Transport**
```python
# Secure STDIO server implementation
from mcp.server.fastmcp import FastMCP
import os
import logging

# Configure secure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/mcp-server.log'),
        logging.StreamHandler()
    ]
)

mcp = FastMCP("Secure Server")

@mcp.tool()
def secure_operation(data: str) -> str:
    """Example of secure tool implementation"""
    
    # Input validation
    if not data or len(data) > 10000:
        raise ValueError("Invalid input data")
    
    # Sanitize input
    sanitized_data = sanitize_input(data)
    
    # Log operation (without sensitive data)
    logging.info(f"Secure operation called with data length: {len(data)}")
    
    # Process data securely
    result = process_securely(sanitized_data)
    
    return result

def sanitize_input(data: str) -> str:
    """Sanitize input data"""
    import re
    # Remove potential injection patterns
    sanitized = re.sub(r'[<>&"\']', '', data)
    return sanitized.strip()

def process_securely(data: str) -> str:
    """Process data with security considerations"""
    # Implementation with security checks
    return f"Processed: {data[:100]}..."  # Truncate for safety
```

**SSE Transport Security**
```typescript
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import * as https from 'https';
import * as fs from 'fs';

class SecureSSEServer {
    private server: Server;
    
    constructor() {
        this.server = new Server({
            name: 'Secure SSE Server',
            version: '1.0.0'
        }, {
            capabilities: {
                tools: {},
                logging: {}
            }
        });
        
        this.setupSecureTransport();
    }
    
    private setupSecureTransport() {
        const transport = new SSEServerTransport('/mcp', {
            // HTTPS configuration
            httpsOptions: {
                key: fs.readFileSync('path/to/private-key.pem'),
                cert: fs.readFileSync('path/to/certificate.pem')
            },
            
            // CORS configuration
            corsOptions: {
                origin: ['https://trusted-client.com'],
                credentials: true
            },
            
            // Rate limiting
            rateLimit: {
                windowMs: 15 * 60 * 1000, // 15 minutes
                max: 100 // limit each IP to 100 requests per windowMs
            }
        });
        
        this.server.connect(transport);
    }
}
```

## Authentication Mechanisms

### OAuth 2.1 Implementation

MCP supports OAuth 2.1 resource server functionality:

**Server-Side Authentication**
```python
from mcp.server.auth.provider import TokenVerifier, TokenInfo
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP
import jwt
import requests

class CustomTokenVerifier(TokenVerifier):
    """Custom token verification implementation"""
    
    def __init__(self, auth_server_url: str):
        self.auth_server_url = auth_server_url
        self.public_key = self._fetch_public_key()
    
    async def verify_token(self, token: str) -> TokenInfo:
        """Verify JWT token with authorization server"""
        try:
            # Decode and verify JWT
            payload = jwt.decode(
                token,
                self.public_key,
                algorithms=['RS256'],
                audience='mcp-server'
            )
            
            # Extract token information
            return TokenInfo(
                subject=payload['sub'],
                scopes=payload.get('scope', '').split(),
                expires_at=payload['exp'],
                client_id=payload.get('client_id'),
                additional_claims=payload
            )
            
        except jwt.InvalidTokenError as e:
            raise ValueError(f"Invalid token: {e}")
    
    def _fetch_public_key(self) -> str:
        """Fetch public key from authorization server"""
        response = requests.get(f"{self.auth_server_url}/.well-known/jwks.json")
        jwks = response.json()
        # Extract and return public key
        return extract_public_key(jwks)

# Configure authenticated MCP server
mcp = FastMCP(
    "Authenticated Server",
    token_verifier=CustomTokenVerifier("https://auth.example.com"),
    auth=AuthSettings(
        issuer_url="https://auth.example.com",
        resource_server_url="http://localhost:3001",
        required_scopes=["mcp:read", "mcp:write"]
    )
)

@mcp.tool()
def protected_operation(data: str) -> str:
    """Tool that requires authentication"""
    # Token is automatically verified by the framework
    # Access user info through context if needed
    return f"Authenticated operation: {data}"
```

**Client-Side Authentication**
```python
from mcp.client.auth import OAuthClientProvider, TokenStorage
from mcp.shared.auth import OAuthClientMetadata, OAuthToken

class SecureTokenStorage(TokenStorage):
    """Secure token storage implementation"""
    
    def __init__(self, storage_path: str):
        self.storage_path = storage_path
        self.encryption_key = self._get_encryption_key()
    
    async def get_tokens(self) -> OAuthToken | None:
        """Retrieve encrypted tokens"""
        try:
            with open(self.storage_path, 'rb') as f:
                encrypted_data = f.read()
            
            decrypted_data = self._decrypt(encrypted_data)
            return OAuthToken.parse_raw(decrypted_data)
        except FileNotFoundError:
            return None
    
    async def set_tokens(self, tokens: OAuthToken) -> None:
        """Store encrypted tokens"""
        token_data = tokens.json()
        encrypted_data = self._encrypt(token_data)
        
        with open(self.storage_path, 'wb') as f:
            f.write(encrypted_data)
    
    def _get_encryption_key(self) -> bytes:
        """Get or generate encryption key"""
        # Implementation for secure key management
        pass
    
    def _encrypt(self, data: str) -> bytes:
        """Encrypt token data"""
        # Implementation using cryptography library
        pass
    
    def _decrypt(self, data: bytes) -> str:
        """Decrypt token data"""
        # Implementation using cryptography library
        pass

# Use secure authentication
auth_provider = OAuthClientProvider(
    server_url="https://api.example.com",
    client_metadata=OAuthClientMetadata(
        client_name="Secure MCP Client",
        redirect_uris=["http://localhost:3000/callback"],
        grant_types=["authorization_code", "refresh_token"]
    ),
    storage=SecureTokenStorage("~/.mcp/tokens.encrypted")
)
```

### API Key Management

**Environment Variable Security**
```python
import os
from typing import Optional

class SecureEnvironment:
    """Secure environment variable management"""
    
    @staticmethod
    def get_required_env(key: str) -> str:
        """Get required environment variable with validation"""
        value = os.getenv(key)
        if not value:
            raise ValueError(f"Required environment variable {key} not set")
        return value
    
    @staticmethod
    def get_optional_env(key: str, default: str = "") -> str:
        """Get optional environment variable"""
        return os.getenv(key, default)
    
    @staticmethod
    def validate_api_key(api_key: str, service: str) -> bool:
        """Validate API key format"""
        patterns = {
            'github': r'^ghp_[a-zA-Z0-9]{36}$',
            'openai': r'^sk-[a-zA-Z0-9]{48}$',
            'anthropic': r'^sk-ant-[a-zA-Z0-9]{64}$'
        }
        
        import re
        pattern = patterns.get(service)
        if pattern:
            return bool(re.match(pattern, api_key))
        return len(api_key) > 10  # Basic length check

# Example usage
@mcp.tool()
def github_operation() -> str:
    """Tool with secure API key handling"""
    try:
        api_key = SecureEnvironment.get_required_env('GITHUB_PERSONAL_ACCESS_TOKEN')
        
        if not SecureEnvironment.validate_api_key(api_key, 'github'):
            raise ValueError("Invalid GitHub API key format")
        
        # Use API key securely
        return perform_github_operation(api_key)
    
    except ValueError as e:
        logging.error(f"API key error: {e}")
        raise
```

**Secret Management Integration**
```python
import boto3
import json
from typing import Dict, Any

class AWSSecretsManager:
    """AWS Secrets Manager integration"""
    
    def __init__(self, region: str = 'us-east-1'):
        self.client = boto3.client('secretsmanager', region_name=region)
        self._cache = {}
    
    def get_secret(self, secret_name: str) -> Dict[str, Any]:
        """Get secret from AWS Secrets Manager"""
        if secret_name in self._cache:
            return self._cache[secret_name]
        
        try:
            response = self.client.get_secret_value(SecretId=secret_name)
            secret_data = json.loads(response['SecretString'])
            self._cache[secret_name] = secret_data
            return secret_data
        except Exception as e:
            logging.error(f"Failed to retrieve secret {secret_name}: {e}")
            raise

# Example usage with secrets manager
secrets = AWSSecretsManager()

@mcp.tool()
def secure_database_query(query: str) -> List[Dict]:
    """Tool using secrets from AWS Secrets Manager"""
    db_config = secrets.get_secret('mcp-server/database')
    
    connection_string = (
        f"postgresql://{db_config['username']}:"
        f"{db_config['password']}@"
        f"{db_config['host']}:{db_config['port']}/"
        f"{db_config['database']}"
    )
    
    return execute_query(connection_string, query)
```

## Input Validation and Sanitization

### Comprehensive Input Validation

```python
from pydantic import BaseModel, validator, Field
from typing import List, Optional, Union
import re
import html

class SecureInput(BaseModel):
    """Secure input validation model"""
    
    query: str = Field(..., min_length=1, max_length=10000)
    parameters: Optional[Dict[str, Union[str, int, float]]] = Field(default_factory=dict)
    options: Optional[List[str]] = Field(default_factory=list)
    
    @validator('query')
    def validate_query(cls, v):
        """Validate and sanitize query input"""
        # Check for SQL injection patterns
        dangerous_patterns = [
            r'\b(DROP|DELETE|TRUNCATE|ALTER|CREATE)\b',
            r'--',
            r'/\*.*\*/',
            r'@@\w+',
            r'\bUNION\b.*\bSELECT\b'
        ]
        
        query_upper = v.upper()
        for pattern in dangerous_patterns:
            if re.search(pattern, query_upper):
                raise ValueError(f"Potentially dangerous SQL detected: {pattern}")
        
        # Sanitize HTML entities
        sanitized = html.escape(v)
        
        # Remove excessive whitespace
        sanitized = re.sub(r'\s+', ' ', sanitized).strip()
        
        return sanitized
    
    @validator('parameters')
    def validate_parameters(cls, v):
        """Validate parameter values"""
        if not v:
            return v
        
        for key, value in v.items():
            # Validate parameter names
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', key):
                raise ValueError(f"Invalid parameter name: {key}")
            
            # Sanitize string values
            if isinstance(value, str):
                v[key] = html.escape(value)
        
        return v

@mcp.tool()
def secure_query_tool(input_data: SecureInput) -> Dict[str, Any]:
    """Tool with comprehensive input validation"""
    # Input is automatically validated by Pydantic
    
    # Additional business logic validation
    if len(input_data.parameters) > 50:
        raise ValueError("Too many parameters provided")
    
    # Process validated input
    return process_secure_query(
        input_data.query,
        input_data.parameters,
        input_data.options
    )
```

### File Path Validation

```python
import os
from pathlib import Path
from typing import List

class SecureFileAccess:
    """Secure file access with path validation"""
    
    def __init__(self, allowed_directories: List[str]):
        self.allowed_paths = [Path(d).resolve() for d in allowed_directories]
    
    def validate_path(self, file_path: str) -> Path:
        """Validate file path against allowed directories"""
        try:
            requested_path = Path(file_path).resolve()
        except (OSError, ValueError) as e:
            raise ValueError(f"Invalid file path: {e}")
        
        # Check if path is within allowed directories
        for allowed_path in self.allowed_paths:
            try:
                requested_path.relative_to(allowed_path)
                return requested_path
            except ValueError:
                continue
        
        raise ValueError(f"Access denied: {file_path} not in allowed directories")
    
    def read_file_secure(self, file_path: str, max_size: int = 10_000_000) -> str:
        """Securely read file with size limits"""
        validated_path = self.validate_path(file_path)
        
        # Check file size
        file_size = validated_path.stat().st_size
        if file_size > max_size:
            raise ValueError(f"File too large: {file_size} > {max_size} bytes")
        
        # Read file securely
        try:
            with open(validated_path, 'r', encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            # Try binary read for non-text files
            with open(validated_path, 'rb') as f:
                return f.read().decode('utf-8', errors='replace')

# Example usage
file_access = SecureFileAccess([
    '/home/user/projects',
    '/tmp/mcp-workspace'
])

@mcp.resource("file://{path}")
def secure_file_resource(path: str) -> str:
    """Secure file access resource"""
    try:
        content = file_access.read_file_secure(path)
        return content
    except ValueError as e:
        logging.warning(f"File access denied: {e}")
        raise
```

## Error Handling and Information Disclosure

### Secure Error Handling

```python
import logging
import traceback
from typing import Any, Dict

class SecurityAwareLogger:
    """Logger that prevents sensitive information disclosure"""
    
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
        self.sensitive_patterns = [
            r'password["\']?\s*[:=]\s*["\']?[\w-]+',
            r'token["\']?\s*[:=]\s*["\']?[\w-]+',
            r'key["\']?\s*[:=]\s*["\']?[\w-]+',
            r'secret["\']?\s*[:=]\s*["\']?[\w-]+'
        ]
    
    def sanitize_message(self, message: str) -> str:
        """Remove sensitive information from log messages"""
        import re
        
        sanitized = message
        for pattern in self.sensitive_patterns:
            sanitized = re.sub(pattern, '[REDACTED]', sanitized, flags=re.IGNORECASE)
        
        return sanitized
    
    def error(self, message: str, exc_info: bool = False):
        """Log error with sanitization"""
        sanitized_message = self.sanitize_message(message)
        self.logger.error(sanitized_message, exc_info=exc_info)
    
    def info(self, message: str):
        """Log info with sanitization"""
        sanitized_message = self.sanitize_message(message)
        self.logger.info(sanitized_message)

# Global secure logger
secure_logger = SecurityAwareLogger('mcp.security')

@mcp.tool()
def error_prone_operation(data: str) -> str:
    """Tool with secure error handling"""
    try:
        # Operation that might fail
        result = risky_operation(data)
        secure_logger.info(f"Operation completed successfully")
        return result
    
    except ValueError as e:
        # Log error without exposing sensitive details
        secure_logger.error(f"Validation error in operation: {type(e).__name__}")
        raise ValueError("Invalid input provided")
    
    except ConnectionError as e:
        # Log connection issues
        secure_logger.error(f"Connection error: {type(e).__name__}")
        raise RuntimeError("Service temporarily unavailable")
    
    except Exception as e:
        # Catch-all for unexpected errors
        secure_logger.error(f"Unexpected error: {type(e).__name__}", exc_info=True)
        raise RuntimeError("An internal error occurred")
```

### User-Friendly Error Messages

```python
class SecurityError(Exception):
    """Custom exception for security-related errors"""
    
    def __init__(self, message: str, error_code: str = None):
        self.message = message
        self.error_code = error_code
        super().__init__(message)

class SecureErrorHandler:
    """Handle errors securely without information disclosure"""
    
    ERROR_MESSAGES = {
        'AUTH_FAILED': 'Authentication failed. Please check your credentials.',
        'ACCESS_DENIED': 'Access denied. Insufficient permissions.',
        'INVALID_INPUT': 'Invalid input provided. Please check your request.',
        'RATE_LIMITED': 'Too many requests. Please try again later.',
        'SERVICE_ERROR': 'Service temporarily unavailable. Please try again later.'
    }
    
    @classmethod
    def handle_error(cls, error: Exception) -> str:
        """Convert internal errors to user-friendly messages"""
        
        if isinstance(error, SecurityError):
            return cls.ERROR_MESSAGES.get(error.error_code, error.message)
        
        elif isinstance(error, ValueError):
            return cls.ERROR_MESSAGES['INVALID_INPUT']
        
        elif isinstance(error, PermissionError):
            return cls.ERROR_MESSAGES['ACCESS_DENIED']
        
        elif isinstance(error, ConnectionError):
            return cls.ERROR_MESSAGES['SERVICE_ERROR']
        
        else:
            # Log internal error details securely
            secure_logger.error(f"Unhandled error: {type(error).__name__}: {str(error)}")
            return cls.ERROR_MESSAGES['SERVICE_ERROR']

@mcp.tool()
def secure_tool_with_error_handling(input_data: str) -> str:
    """Tool with comprehensive secure error handling"""
    try:
        # Validate input
        if not input_data or len(input_data) > 1000:
            raise SecurityError("Invalid input length", "INVALID_INPUT")
        
        # Perform operation
        result = perform_operation(input_data)
        return result
    
    except Exception as e:
        # Convert to user-friendly error message
        user_message = SecureErrorHandler.handle_error(e)
        raise RuntimeError(user_message)
```

## Security Monitoring and Auditing

### Audit Logging

```python
import json
from datetime import datetime
from typing import Optional

class SecurityAuditor:
    """Security audit logging for MCP operations"""
    
    def __init__(self, audit_file: str):
        self.audit_file = audit_file
    
    def log_operation(
        self,
        operation: str,
        user_id: Optional[str] = None,
        resource: Optional[str] = None,
        success: bool = True,
        details: Optional[Dict[str, Any]] = None
    ):
        """Log security-relevant operations"""
        
        audit_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'operation': operation,
            'user_id': user_id,
            'resource': resource,
            'success': success,
            'details': details or {},
            'session_id': self.get_session_id()
        }
        
        with open(self.audit_file, 'a') as f:
            f.write(json.dumps(audit_entry) + '\n')
    
    def get_session_id(self) -> str:
        """Get current session identifier"""
        # Implementation to get session ID
        return "session_123"

# Global auditor
auditor = SecurityAuditor('/var/log/mcp-audit.log')

@mcp.tool()
def audited_operation(data: str) -> str:
    """Tool with audit logging"""
    try:
        # Log operation start
        auditor.log_operation(
            'tool_call',
            resource='audited_operation',
            details={'data_length': len(data)}
        )
        
        result = process_data(data)
        
        # Log successful completion
        auditor.log_operation(
            'tool_call_success',
            resource='audited_operation',
            success=True
        )
        
        return result
    
    except Exception as e:
        # Log failure
        auditor.log_operation(
            'tool_call_failure',
            resource='audited_operation',
            success=False,
            details={'error_type': type(e).__name__}
        )
        raise
```

### Rate Limiting and Abuse Prevention

```python
from collections import defaultdict
from datetime import datetime, timedelta
import threading

class RateLimiter:
    """Rate limiting for MCP operations"""
    
    def __init__(self, max_requests: int = 100, window_minutes: int = 15):
        self.max_requests = max_requests
        self.window = timedelta(minutes=window_minutes)
        self.requests = defaultdict(list)
        self.lock = threading.Lock()
    
    def is_allowed(self, identifier: str) -> bool:
        """Check if request is allowed under rate limits"""
        with self.lock:
            now = datetime.utcnow()
            user_requests = self.requests[identifier]
            
            # Remove old requests outside the window
            cutoff = now - self.window
            self.requests[identifier] = [
                req_time for req_time in user_requests 
                if req_time > cutoff
            ]
            
            # Check if under limit
            if len(self.requests[identifier]) >= self.max_requests:
                return False
            
            # Add current request
            self.requests[identifier].append(now)
            return True

# Global rate limiter
rate_limiter = RateLimiter(max_requests=100, window_minutes=15)

@mcp.tool()
def rate_limited_operation(data: str) -> str:
    """Tool with rate limiting"""
    user_id = get_current_user_id()  # Implementation needed
    
    if not rate_limiter.is_allowed(user_id):
        auditor.log_operation(
            'rate_limit_exceeded',
            user_id=user_id,
            success=False
        )
        raise SecurityError("Rate limit exceeded", "RATE_LIMITED")
    
    return process_data(data)
```

## Deployment Security

### Container Security

```dockerfile
# Secure Dockerfile for MCP server
FROM python:3.11-slim

# Create non-root user
RUN useradd --create-home --shell /bin/bash mcpuser

# Install security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set proper ownership
RUN chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER mcpuser

# Expose port (if using HTTP transport)
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Run server
CMD ["python", "-m", "mcp_server"]
```

### Production Security Configuration

```python
import os
from pathlib import Path

class ProductionSecurityConfig:
    """Production security configuration"""
    
    def __init__(self):
        self.validate_environment()
        self.setup_logging()
        self.configure_security()
    
    def validate_environment(self):
        """Validate required security configuration"""
        required_vars = [
            'MCP_AUTH_SECRET',
            'MCP_LOG_LEVEL',
            'MCP_ALLOWED_ORIGINS'
        ]
        
        for var in required_vars:
            if not os.getenv(var):
                raise ValueError(f"Required environment variable {var} not set")
    
    def setup_logging(self):
        """Configure secure logging"""
        log_level = os.getenv('MCP_LOG_LEVEL', 'INFO')
        log_file = os.getenv('MCP_LOG_FILE', '/var/log/mcp-server.log')
        
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
    
    def configure_security(self):
        """Configure security settings"""
        # Set secure defaults
        os.umask(0o077)  # Restrict file permissions
        
        # Validate TLS configuration
        cert_file = os.getenv('MCP_TLS_CERT')
        key_file = os.getenv('MCP_TLS_KEY')
        
        if cert_file and key_file:
            if not (Path(cert_file).exists() and Path(key_file).exists()):
                raise ValueError("TLS certificate files not found")

# Initialize security configuration
security_config = ProductionSecurityConfig()
```

---

## Navigation

⬅️ [MCP vs GitHub Copilot Extensions](./mcp-vs-github-copilot-extensions.md) | ➡️ [Future Roadmap and Community](./future-roadmap-community.md)

---

Research conducted: July 2025 | Last updated: July 14, 2025
