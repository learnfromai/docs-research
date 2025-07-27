# Template Examples - Railway.com Platform Development

## 🚀 Quick Start Templates

### Basic Web Application Deployment

**package.json for Node.js app:**
```json
{
  "name": "railway-starter-app",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "build": "npm ci --production"
  },
  "dependencies": {
    "express": "^4.18.0",
    "dotenv": "^16.0.0"
  },
  "engines": {
    "node": "18.x"
  }
}
```

**Dockerfile template:**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

**railway.toml configuration:**
```toml
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "npm start"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[[deploy.environmentVariables]]
name = "PORT"
value = "3000"

[[deploy.environmentVariables]]
name = "NODE_ENV"
value = "production"
```

### Database Integration Example

**PostgreSQL connection:**
```javascript
// database.js
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

module.exports = pool;
```

## 🔧 CI/CD Pipeline Templates

**GitHub Actions workflow:**
```yaml
name: Deploy to Railway
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Use Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
    
    - name: Deploy to Railway
      uses: railway/actions@v1
      with:
        api-token: ${{ secrets.RAILWAY_TOKEN }}
        project-id: ${{ secrets.RAILWAY_PROJECT_ID }}
```

**Kubernetes deployment template:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{.ServiceName}}
  namespace: {{.ProjectNamespace}}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{.ServiceName}}
  template:
    metadata:
      labels:
        app: {{.ServiceName}}
    spec:
      containers:
      - name: app
        image: {{.ImageURL}}
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

---

## 🔗 Navigation

← [Competitive Analysis](./competitive-analysis.md) | [Back to README →](./README.md)