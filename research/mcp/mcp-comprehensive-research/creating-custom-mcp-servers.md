# Creating Custom MCP Servers

## Overview

This guide provides comprehensive instructions for developing custom MCP servers using the official SDKs, with a focus on the Python FastMCP framework and TypeScript implementation.

## Prerequisites

### System Requirements

- **Python 3.8+** or **Node.js 18+**
- **Package Manager**: pip/uv (Python) or npm/yarn (TypeScript)
- **Development Tools**: IDE with language support

### Installation

**Python SDK:**
```bash
# Install with CLI tools
pip install "mcp[cli]"

# Or with uv (recommended)
uv add "mcp[cli]"
```

**TypeScript SDK:**
```bash
# Install TypeScript SDK
npm install @modelcontextprotocol/sdk

# Install CLI tools globally
npm install -g @modelcontextprotocol/cli
```

## Python FastMCP Development

### Basic Server Structure

```python
"""
Example: Custom MCP Server for Code Analysis
"""
from mcp.server.fastmcp import FastMCP, Context
from pydantic import BaseModel, Field
from typing import List, Dict, Any
import asyncio

# Create server instance
mcp = FastMCP("Code Analysis Server")

# Define structured output models
class CodeAnalysis(BaseModel):
    """Code analysis result structure"""
    language: str = Field(description="Programming language detected")
    complexity_score: float = Field(description="Complexity score 0-10")
    issues: List[str] = Field(description="List of issues found")
    suggestions: List[str] = Field(description="Improvement suggestions")

class FileInfo(BaseModel):
    """File information structure"""
    path: str
    size: int
    last_modified: str

# Tool implementation
@mcp.tool()
def analyze_code(code: str, language: str = "auto") -> CodeAnalysis:
    """Analyze code quality and complexity"""
    
    # Simple analysis logic (replace with real implementation)
    complexity = len(code.split('\n')) * 0.1
    issues = []
    suggestions = []
    
    # Detect issues
    if 'TODO' in code:
        issues.append("Contains TODO comments")
    if len(code.split('\n')) > 100:
        issues.append("File is too long (>100 lines)")
    
    # Generate suggestions
    if not code.strip().startswith('"""'):
        suggestions.append("Add module docstring")
    if 'print(' in code:
        suggestions.append("Consider using logging instead of print")
    
    return CodeAnalysis(
        language=language,
        complexity_score=min(complexity, 10.0),
        issues=issues,
        suggestions=suggestions
    )

# Resource implementation
@mcp.resource("project://files/{path}")
def get_file_info(path: str) -> str:
    """Get information about a project file"""
    import os
    import json
    from datetime import datetime
    
    try:
        stat = os.stat(path)
        info = FileInfo(
            path=path,
            size=stat.st_size,
            last_modified=datetime.fromtimestamp(stat.st_mtime).isoformat()
        )
        return json.dumps(info.dict(), indent=2)
    except FileNotFoundError:
        return f"File not found: {path}"

# Prompt template
@mcp.prompt()
def code_review_prompt(code: str, focus: str = "general") -> str:
    """Generate a code review prompt"""
    focus_areas = {
        "security": "Focus on security vulnerabilities and best practices",
        "performance": "Focus on performance optimization opportunities", 
        "maintainability": "Focus on code maintainability and readability",
        "general": "Provide a comprehensive code review"
    }
    
    instructions = focus_areas.get(focus, focus_areas["general"])
    
    return f"""Please review the following code with emphasis on {focus}:

{instructions}

Code to review:
```
{code}
```

Please provide:
1. Overall assessment
2. Specific issues found
3. Suggestions for improvement
4. Best practice recommendations
"""

# Context-aware tool with progress reporting
@mcp.tool()
async def process_large_dataset(
    data_path: str, 
    operation: str,
    ctx: Context
) -> Dict[str, Any]:
    """Process large dataset with progress reporting"""
    
    await ctx.info(f"Starting {operation} on {data_path}")
    
    # Simulate processing steps
    steps = ["Loading data", "Preprocessing", "Analysis", "Generating report"]
    results = {"processed_items": 0, "errors": 0}
    
    for i, step in enumerate(steps):
        await ctx.report_progress(
            progress=(i + 1) / len(steps),
            total=1.0,
            message=f"Step {i + 1}/{len(steps)}: {step}"
        )
        
        # Simulate work
        await asyncio.sleep(1)
        
        # Simulate some processing
        if step == "Analysis":
            results["processed_items"] = 1000
        
        await ctx.debug(f"Completed: {step}")
    
    await ctx.info(f"Processing complete: {operation}")
    return results

if __name__ == "__main__":
    mcp.run()
```

### Advanced Features

#### Lifecycle Management

```python
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator
from dataclasses import dataclass

@dataclass
class AppContext:
    """Application context with dependencies"""
    database: Any
    cache: Any
    config: Dict[str, str]

@asynccontextmanager
async def app_lifespan(server: FastMCP) -> AsyncIterator[AppContext]:
    """Manage application lifecycle"""
    # Startup
    print("Initializing resources...")
    database = await connect_to_database()
    cache = await initialize_cache()
    config = load_configuration()
    
    try:
        yield AppContext(
            database=database,
            cache=cache,
            config=config
        )
    finally:
        # Cleanup
        print("Cleaning up resources...")
        await database.close()
        await cache.close()

# Create server with lifecycle management
mcp = FastMCP("Advanced Server", lifespan=app_lifespan)

@mcp.tool()
async def query_data(query: str, ctx: Context) -> List[Dict[str, Any]]:
    """Query data using managed database connection"""
    app_ctx = ctx.request_context.lifespan_context
    
    # Use managed database connection
    results = await app_ctx.database.execute(query)
    
    # Use cache for optimization
    cache_key = f"query:{hash(query)}"
    await app_ctx.cache.set(cache_key, results, ttl=300)
    
    return results
```

#### Error Handling and Validation

```python
from typing import Union, Optional
from enum import Enum

class AnalysisType(str, Enum):
    SYNTAX = "syntax"
    STYLE = "style"
    SECURITY = "security"
    PERFORMANCE = "performance"

@mcp.tool()
def validate_and_analyze(
    code: str, 
    analysis_type: AnalysisType,
    max_length: Optional[int] = 10000
) -> Union[CodeAnalysis, str]:
    """Validate input and analyze code with proper error handling"""
    
    # Input validation
    if not code.strip():
        raise ValueError("Code cannot be empty")
    
    if max_length and len(code) > max_length:
        raise ValueError(f"Code too long: {len(code)} > {max_length} characters")
    
    try:
        # Perform analysis based on type
        if analysis_type == AnalysisType.SYNTAX:
            return analyze_syntax(code)
        elif analysis_type == AnalysisType.STYLE:
            return analyze_style(code)
        elif analysis_type == AnalysisType.SECURITY:
            return analyze_security(code)
        elif analysis_type == AnalysisType.PERFORMANCE:
            return analyze_performance(code)
    except Exception as e:
        # Log error and return user-friendly message
        import logging
        logging.error(f"Analysis failed: {e}")
        return f"Analysis failed: {str(e)}"
```

## TypeScript MCP Development

### Basic Server Structure

```typescript
import {
    CallToolRequest,
    CallToolResult,
    ListToolsRequest,
    ListToolsResult,
    Server,
} from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
    TextContent,
    Tool,
    CreateMessageRequest,
    CreateMessageResult,
} from '@modelcontextprotocol/sdk/types.js';

// Define tool schemas
const TOOLS: Tool[] = [
    {
        name: 'analyze_repository',
        description: 'Analyze a Git repository structure and contents',
        inputSchema: {
            type: 'object',
            properties: {
                repository_path: {
                    type: 'string',
                    description: 'Path to the Git repository'
                },
                analysis_type: {
                    type: 'string',
                    enum: ['structure', 'dependencies', 'metrics'],
                    description: 'Type of analysis to perform'
                }
            },
            required: ['repository_path']
        }
    },
    {
        name: 'generate_documentation',
        description: 'Generate documentation for code files',
        inputSchema: {
            type: 'object',
            properties: {
                file_path: {
                    type: 'string',
                    description: 'Path to the code file'
                },
                doc_type: {
                    type: 'string',
                    enum: ['api', 'readme', 'inline'],
                    description: 'Type of documentation to generate'
                }
            },
            required: ['file_path', 'doc_type']
        }
    }
];

class DevelopmentMCPServer {
    private server: Server;

    constructor() {
        this.server = new Server(
            {
                name: 'development-mcp-server',
                version: '1.0.0',
            },
            {
                capabilities: {
                    tools: {},
                    resources: {},
                    prompts: {},
                    logging: {},
                }
            }
        );

        this.setupHandlers();
    }

    private setupHandlers() {
        // List available tools
        this.server.setRequestHandler(
            'tools/list',
            async (): Promise<ListToolsResult> => {
                return { tools: TOOLS };
            }
        );

        // Handle tool execution
        this.server.setRequestHandler(
            'tools/call',
            async (request: CallToolRequest): Promise<CallToolResult> => {
                const { name, arguments: args } = request.params;

                try {
                    switch (name) {
                        case 'analyze_repository':
                            return await this.analyzeRepository(args);
                        case 'generate_documentation':
                            return await this.generateDocumentation(args);
                        default:
                            throw new Error(`Unknown tool: ${name}`);
                    }
                } catch (error) {
                    return {
                        content: [
                            {
                                type: 'text',
                                text: `Error: ${error instanceof Error ? error.message : String(error)}`
                            }
                        ],
                        isError: true
                    };
                }
            }
        );
    }

    private async analyzeRepository(args: any): Promise<CallToolResult> {
        const { repository_path, analysis_type = 'structure' } = args;

        // Repository analysis logic
        const analysis = await this.performRepositoryAnalysis(
            repository_path, 
            analysis_type
        );

        return {
            content: [
                {
                    type: 'text',
                    text: JSON.stringify(analysis, null, 2)
                }
            ]
        };
    }

    private async generateDocumentation(args: any): Promise<CallToolResult> {
        const { file_path, doc_type } = args;

        // Documentation generation logic
        const documentation = await this.performDocumentationGeneration(
            file_path,
            doc_type
        );

        return {
            content: [
                {
                    type: 'text',
                    text: documentation
                }
            ]
        };
    }

    private async performRepositoryAnalysis(
        repositoryPath: string,
        analysisType: string
    ): Promise<any> {
        // Implementation for repository analysis
        const fs = await import('fs').then(m => m.promises);
        const path = await import('path');

        switch (analysisType) {
            case 'structure':
                return await this.analyzeStructure(repositoryPath);
            case 'dependencies':
                return await this.analyzeDependencies(repositoryPath);
            case 'metrics':
                return await this.analyzeMetrics(repositoryPath);
            default:
                throw new Error(`Unknown analysis type: ${analysisType}`);
        }
    }

    private async analyzeStructure(repositoryPath: string): Promise<any> {
        const fs = await import('fs').then(m => m.promises);
        const path = await import('path');

        const structure = await this.buildDirectoryTree(repositoryPath);
        
        return {
            type: 'structure',
            repository: repositoryPath,
            tree: structure,
            summary: {
                total_files: this.countFiles(structure),
                total_directories: this.countDirectories(structure),
                languages: this.detectLanguages(structure)
            }
        };
    }

    private async buildDirectoryTree(dirPath: string): Promise<any> {
        // Directory tree building logic
        const fs = await import('fs').then(m => m.promises);
        const path = await import('path');

        try {
            const items = await fs.readdir(dirPath);
            const tree: any = {};

            for (const item of items) {
                const itemPath = path.join(dirPath, item);
                const stats = await fs.stat(itemPath);

                if (stats.isDirectory()) {
                    tree[item] = await this.buildDirectoryTree(itemPath);
                } else {
                    tree[item] = {
                        type: 'file',
                        size: stats.size,
                        extension: path.extname(item)
                    };
                }
            }

            return tree;
        } catch (error) {
            return { error: `Cannot read directory: ${dirPath}` };
        }
    }

    private countFiles(tree: any): number {
        let count = 0;
        for (const key in tree) {
            if (tree[key].type === 'file') {
                count++;
            } else if (typeof tree[key] === 'object') {
                count += this.countFiles(tree[key]);
            }
        }
        return count;
    }

    private countDirectories(tree: any): number {
        let count = 0;
        for (const key in tree) {
            if (typeof tree[key] === 'object' && tree[key].type !== 'file') {
                count++;
                count += this.countDirectories(tree[key]);
            }
        }
        return count;
    }

    private detectLanguages(tree: any): string[] {
        const extensions = new Set<string>();
        
        const collectExtensions = (node: any) => {
            for (const key in node) {
                if (node[key].type === 'file' && node[key].extension) {
                    extensions.add(node[key].extension);
                } else if (typeof node[key] === 'object') {
                    collectExtensions(node[key]);
                }
            }
        };

        collectExtensions(tree);
        return Array.from(extensions);
    }

    private async performDocumentationGeneration(
        filePath: string,
        docType: string
    ): Promise<string> {
        const fs = await import('fs').then(m => m.promises);

        try {
            const content = await fs.readFile(filePath, 'utf-8');
            
            switch (docType) {
                case 'api':
                    return this.generateAPIDocumentation(content, filePath);
                case 'readme':
                    return this.generateReadmeDocumentation(content, filePath);
                case 'inline':
                    return this.generateInlineDocumentation(content, filePath);
                default:
                    throw new Error(`Unknown documentation type: ${docType}`);
            }
        } catch (error) {
            throw new Error(`Cannot read file ${filePath}: ${error}`);
        }
    }

    private generateAPIDocumentation(content: string, filePath: string): string {
        // API documentation generation logic
        return `# API Documentation for ${filePath}\n\n` +
               `Generated from source code analysis.\n\n` +
               `## Functions\n\n` +
               this.extractFunctions(content).map(func => 
                   `### ${func.name}\n\n${func.description}\n`
               ).join('\n');
    }

    private generateReadmeDocumentation(content: string, filePath: string): string {
        // README generation logic
        const path = require('path');
        const fileName = path.basename(filePath);
        
        return `# ${fileName}\n\n` +
               `## Description\n\n` +
               `Auto-generated documentation for ${fileName}.\n\n` +
               `## Usage\n\n` +
               this.generateUsageExamples(content);
    }

    private generateInlineDocumentation(content: string, filePath: string): string {
        // Inline documentation generation logic
        return this.addInlineComments(content);
    }

    private extractFunctions(content: string): Array<{name: string, description: string}> {
        // Function extraction logic
        const functionRegex = /function\s+(\w+)\s*\([^)]*\)/g;
        const functions = [];
        let match;

        while ((match = functionRegex.exec(content)) !== null) {
            functions.push({
                name: match[1],
                description: `Function ${match[1]} - implementation details to be analyzed`
            });
        }

        return functions;
    }

    private generateUsageExamples(content: string): string {
        // Usage example generation logic
        return "```javascript\n// Usage examples to be generated\n```";
    }

    private addInlineComments(content: string): string {
        // Inline comment addition logic
        return content.split('\n').map(line => {
            if (line.trim() && !line.trim().startsWith('//')) {
                return line + ' // TODO: Add inline documentation';
            }
            return line;
        }).join('\n');
    }

    async run() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.error('Development MCP Server running on stdio');
    }
}

// Start the server
const server = new DevelopmentMCPServer();
server.run().catch(console.error);
```

## Testing and Debugging

### Local Testing

**Python:**
```bash
# Test server directly
uv run mcp dev server.py

# Test with specific arguments
uv run mcp dev server.py --with pandas --with numpy

# Install for Claude Desktop
uv run mcp install server.py --name "Custom Analysis Server"
```

**TypeScript:**
```bash
# Test server
node dist/server.js

# Test with MCP CLI
mcp dev dist/server.js

# Package for distribution
npm pack
```

### Integration Testing

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test_mcp_server():
    """Test MCP server functionality"""
    server_params = StdioServerParameters(
        command="python",
        args=["-m", "my_mcp_server"],
        env={}
    )
    
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            
            # Test tool listing
            tools = await session.list_tools()
            print(f"Available tools: {[t.name for t in tools.tools]}")
            
            # Test tool execution
            result = await session.call_tool("analyze_code", {
                "code": "def hello(): print('Hello, World!')",
                "language": "python"
            })
            print(f"Tool result: {result.content}")
            
            # Test resource access
            resources = await session.list_resources()
            print(f"Available resources: {[r.uri for r in resources.resources]}")

if __name__ == "__main__":
    asyncio.run(test_mcp_server())
```

### Performance Monitoring

```python
import time
import asyncio
from functools import wraps

def monitor_performance(func):
    """Decorator to monitor MCP tool performance"""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            if asyncio.iscoroutinefunction(func):
                result = await func(*args, **kwargs)
            else:
                result = func(*args, **kwargs)
            
            duration = time.time() - start_time
            print(f"Tool {func.__name__} executed in {duration:.2f}s")
            return result
        except Exception as e:
            duration = time.time() - start_time
            print(f"Tool {func.__name__} failed after {duration:.2f}s: {e}")
            raise
    return wrapper

# Apply to tools
@mcp.tool()
@monitor_performance
def expensive_analysis(data: str) -> str:
    """Long-running analysis tool"""
    # Simulate expensive operation
    time.sleep(2)
    return f"Analysis complete for {len(data)} characters"
```

## Deployment Strategies

### Local Development

```bash
# Development mode with auto-reload
uv run mcp dev server.py --reload

# Production mode
uv run mcp run server.py
```

### Docker Deployment

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "-m", "my_mcp_server", "--transport", "streamable-http"]
```

### Production Configuration

```python
import os
from mcp.server.fastmcp import FastMCP

# Production server with environment configuration
mcp = FastMCP(
    name=os.getenv("SERVER_NAME", "Production MCP Server"),
    description=os.getenv("SERVER_DESCRIPTION", "Production MCP Server")
)

# Configure logging
import logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Production-ready tool with error handling
@mcp.tool()
def production_tool(input_data: str) -> str:
    """Production-ready tool with comprehensive error handling"""
    try:
        # Validate input
        if not input_data or len(input_data) > 100000:
            raise ValueError("Invalid input data")
        
        # Process data
        result = process_data(input_data)
        
        # Log success
        logging.info(f"Successfully processed data of length {len(input_data)}")
        
        return result
    except Exception as e:
        # Log error
        logging.error(f"Tool execution failed: {e}")
        raise

if __name__ == "__main__":
    # Run with production settings
    mcp.run(
        transport=os.getenv("TRANSPORT", "stdio"),
        host=os.getenv("HOST", "localhost"),
        port=int(os.getenv("PORT", "8000"))
    )
```

---

## Navigation

⬅️ [GitHub Copilot Integration Guide](./github-copilot-integration-guide.md) | ➡️ [Existing MCP Server Ecosystem](./existing-mcp-server-ecosystem.md)

---

Research conducted: July 2025 | Last updated: July 14, 2025
