# Resend API Interview Questions & Answers

## 📋 Table of Contents

1. **[Resend Fundamentals](#resend-fundamentals)** - Email API platform overview
2. **[Email Sending & Templates](#email-sending--templates)** - Core functionality and templating
3. **[Authentication & Security](#authentication--security)** - API keys and secure practices
4. **[Deliverability & Analytics](#deliverability--analytics)** - Email delivery optimization
5. **[Integration Patterns](#integration-patterns)** - Common implementation patterns
6. **[Error Handling & Monitoring](#error-handling--monitoring)** - Robust email systems
7. **[Best Practices](#best-practices)** - Production-ready implementations

---

## Resend Fundamentals

### 1. What is Resend and how does it compare to other email services?

**Answer:**
Resend is a **developer-first email API** that simplifies transactional email sending with modern APIs and excellent deliverability.

**Key Differentiators:**

| Feature | Resend | SendGrid | AWS SES | Postmark |
|---------|--------|----------|---------|----------|
| **API Design** | Modern, simple | Comprehensive but complex | AWS-native | Developer-friendly |
| **Setup Time** | Minutes | Hours | Complex AWS setup | Quick |
| **Pricing** | Usage-based, simple | Tiered plans | Pay-per-use | Feature-based plans |
| **Deliverability** | Built-in optimization | Advanced tools | Basic | Premium focus |
| **Template Engine** | React components | Drag-and-drop | Basic | Limited |

**Core Advantages:**

```javascript
// Simple, intuitive API design
import { Resend } from 'resend';

const resend = new Resend('re_...');

// Send email with minimal configuration
await resend.emails.send({
  from: 'noreply@company.com',
  to: 'user@example.com',
  subject: 'Welcome to our platform!',
  html: '<p>Thank you for signing up!</p>'
});

// Compare with SendGrid complexity
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const msg = {
  to: 'user@example.com',
  from: 'noreply@company.com',
  subject: 'Welcome to our platform!',
  html: '<p>Thank you for signing up!</p>',
  // Additional configuration required...
};

await sgMail.send(msg);
```

**Developer Experience:**

```javascript
// React component templates (unique to Resend)
import { Html, Head, Body, Container, Text, Button } from '@react-email/components';

export default function WelcomeEmail({ name, loginUrl }) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: 'Arial, sans-serif' }}>
        <Container>
          <Text>Welcome {name}!</Text>
          <Text>Thank you for joining our platform.</Text>
          <Button
            href={loginUrl}
            style={{
              background: '#007ee6',
              color: '#fff',
              padding: '12px 20px',
              textDecoration: 'none',
              borderRadius: '4px'
            }}
          >
            Get Started
          </Button>
        </Container>
      </Body>
    </Html>
  );
}
```

---

### 2. How do you set up and configure Resend for a project?

**Answer:**
Setting up Resend involves **API key generation**, **domain verification**, and **SDK integration**.

**Initial Setup Process:**

```bash
# Install Resend SDK
npm install resend

# For React email templates
npm install @react-email/components
npm install @react-email/render
```

**Environment Configuration:**

```javascript
// .env file
RESEND_API_KEY=re_1234567890abcdef
RESEND_FROM_EMAIL=noreply@yourdomain.com
RESEND_REPLY_TO=support@yourdomain.com

// config/email.js
const emailConfig = {
  apiKey: process.env.RESEND_API_KEY,
  fromEmail: process.env.RESEND_FROM_EMAIL,
  replyTo: process.env.RESEND_REPLY_TO,
  
  // Development vs Production
  isProduction: process.env.NODE_ENV === 'production',
  testEmail: process.env.RESEND_TEST_EMAIL, // For development
};

module.exports = emailConfig;
```

**Domain Verification:**

```javascript
// Domain setup helper
class ResendDomainSetup {
  constructor(apiKey) {
    this.resend = new Resend(apiKey);
  }

  async addDomain(domain) {
    try {
      const result = await this.resend.domains.create({
        name: domain,
        region: 'us-east-1', // or 'eu-west-1'
      });

      console.log('Domain created:', result);
      console.log('DNS Records to add:');
      
      // Display required DNS records
      result.records.forEach(record => {
        console.log(`${record.type}: ${record.name} -> ${record.value}`);
      });

      return result;
    } catch (error) {
      console.error('Domain setup failed:', error);
      throw error;
    }
  }

  async verifyDomain(domainId) {
    try {
      const result = await this.resend.domains.verify(domainId);
      console.log('Domain verification:', result.status);
      return result;
    } catch (error) {
      console.error('Domain verification failed:', error);
      throw error;
    }
  }

  async listDomains() {
    const domains = await this.resend.domains.list();
    domains.data.forEach(domain => {
      console.log(`${domain.name}: ${domain.status}`);
    });
    return domains;
  }
}
```

**Basic SDK Integration:**

```javascript
// services/emailService.js
import { Resend } from 'resend';
import { emailConfig } from '../config/email.js';

class EmailService {
  constructor() {
    this.resend = new Resend(emailConfig.apiKey);
    this.fromEmail = emailConfig.fromEmail;
    this.replyTo = emailConfig.replyTo;
  }

  async sendEmail({ to, subject, html, text, tags = [] }) {
    try {
      // Development mode - send to test email
      const recipient = emailConfig.isProduction ? to : emailConfig.testEmail;
      
      const result = await this.resend.emails.send({
        from: this.fromEmail,
        to: recipient,
        subject: emailConfig.isProduction ? subject : `[DEV] ${subject}`,
        html,
        text,
        reply_to: this.replyTo,
        tags: [
          ...tags,
          { name: 'environment', value: process.env.NODE_ENV }
        ]
      });

      console.log('Email sent successfully:', result.id);
      return { success: true, id: result.id };
      
    } catch (error) {
      console.error('Email sending failed:', error);
      return { success: false, error: error.message };
    }
  }

  async sendBulkEmail(emails) {
    try {
      const results = await this.resend.batch.send(emails.map(email => ({
        from: this.fromEmail,
        ...email,
        reply_to: this.replyTo,
      })));

      return {
        success: true,
        results,
        sent: results.data.length,
        failed: results.data.filter(r => r.error).length
      };
    } catch (error) {
      console.error('Bulk email sending failed:', error);
      return { success: false, error: error.message };
    }
  }
}

export default new EmailService();
```

---

## Email Sending & Templates

### 3. How do you create and manage email templates with Resend?

**Answer:**
Resend supports **React-based email templates** that provide type safety and component reusability.

**React Email Template Structure:**

```javascript
// emails/templates/WelcomeEmail.jsx
import {
  Html,
  Head,
  Preview,
  Body,
  Container,
  Section,
  Row,
  Column,
  Img,
  Text,
  Link,
  Button,
  Hr
} from '@react-email/components';

const baseUrl = process.env.VERCEL_URL
  ? `https://${process.env.VERCEL_URL}`
  : 'http://localhost:3000';

export default function WelcomeEmail({
  name = 'User',
  email = 'user@example.com',
  loginUrl = `${baseUrl}/login`,
  companyName = 'YourCompany'
}) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to {companyName}! Get started with your account.</Preview>
      
      <Body style={main}>
        <Container style={container}>
          {/* Header */}
          <Section style={header}>
            <Img
              src={`${baseUrl}/static/logo.png`}
              width="120"
              height="40"
              alt={companyName}
              style={logo}
            />
          </Section>

          {/* Main Content */}
          <Section style={content}>
            <Text style={heading}>Welcome, {name}!</Text>
            
            <Text style={paragraph}>
              Thank you for signing up for {companyName}. We're excited to have you on board!
            </Text>

            <Text style={paragraph}>
              Your account has been created with the email address: <strong>{email}</strong>
            </Text>

            {/* CTA Button */}
            <Section style={buttonContainer}>
              <Button
                href={loginUrl}
                style={button}
              >
                Get Started
              </Button>
            </Section>

            <Text style={paragraph}>
              If you have any questions, feel free to{' '}
              <Link href={`${baseUrl}/contact`} style={link}>
                contact our support team
              </Link>
              .
            </Text>
          </Section>

          {/* Footer */}
          <Hr style={hr} />
          <Section style={footer}>
            <Text style={footerText}>
              {companyName} | 123 Business St, City, State 12345
            </Text>
            <Text style={footerText}>
              <Link href={`${baseUrl}/unsubscribe`} style={link}>
                Unsubscribe
              </Link>
              {' | '}
              <Link href={`${baseUrl}/privacy`} style={link}>
                Privacy Policy
              </Link>
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}

// Styles
const main = {
  backgroundColor: '#f6f9fc',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '20px 0 48px',
  marginBottom: '64px',
};

const header = {
  padding: '24px 24px 0',
};

const logo = {
  margin: '0 auto',
};

const content = {
  padding: '24px',
};

const heading = {
  fontSize: '28px',
  fontWeight: '600',
  color: '#1f2937',
  margin: '0 0 24px',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '1.5',
  color: '#374151',
  margin: '0 0 16px',
};

const buttonContainer = {
  textAlign: 'center',
  margin: '32px 0',
};

const button = {
  backgroundColor: '#3b82f6',
  borderRadius: '8px',
  color: '#ffffff',
  fontSize: '16px',
  fontWeight: '600',
  textDecoration: 'none',
  textAlign: 'center',
  display: 'inline-block',
  padding: '12px 24px',
};

const link = {
  color: '#3b82f6',
  textDecoration: 'underline',
};

const hr = {
  borderColor: '#e5e7eb',
  margin: '20px 0',
};

const footer = {
  padding: '0 24px',
};

const footerText = {
  fontSize: '12px',
  color: '#6b7280',
  textAlign: 'center',
  margin: '0 0 8px',
};
```

**Template Management System:**

```javascript
// services/templateService.js
import { render } from '@react-email/render';
import WelcomeEmail from '../emails/templates/WelcomeEmail.jsx';
import PasswordResetEmail from '../emails/templates/PasswordResetEmail.jsx';
import OrderConfirmationEmail from '../emails/templates/OrderConfirmationEmail.jsx';

class TemplateService {
  constructor() {
    this.templates = {
      welcome: WelcomeEmail,
      passwordReset: PasswordResetEmail,
      orderConfirmation: OrderConfirmationEmail,
    };
  }

  async renderTemplate(templateName, props = {}) {
    const Template = this.templates[templateName];
    
    if (!Template) {
      throw new Error(`Template '${templateName}' not found`);
    }

    try {
      // Render to HTML
      const html = render(<Template {...props} />);
      
      // Optional: render to plain text
      const text = render(<Template {...props} />, { plainText: true });

      return { html, text };
    } catch (error) {
      console.error(`Template rendering failed for '${templateName}':`, error);
      throw error;
    }
  }

  async sendTemplatedEmail(templateName, { to, subject, ...templateProps }) {
    try {
      const { html, text } = await this.renderTemplate(templateName, templateProps);

      const result = await emailService.sendEmail({
        to,
        subject,
        html,
        text,
        tags: [
          { name: 'template', value: templateName },
          { name: 'type', value: 'transactional' }
        ]
      });

      return result;
    } catch (error) {
      console.error('Templated email sending failed:', error);
      throw error;
    }
  }

  // Preview template for development
  async previewTemplate(templateName, props = {}) {
    const { html } = await this.renderTemplate(templateName, props);
    
    // Save to temp file for preview
    const fs = require('fs');
    const path = require('path');
    
    const previewPath = path.join(process.cwd(), 'temp', `${templateName}-preview.html`);
    fs.writeFileSync(previewPath, html);
    
    return { previewPath, html };
  }
}

export default new TemplateService();
```

**Dynamic Template Content:**

```javascript
// Advanced template with dynamic content
export default function OrderConfirmationEmail({
  customerName,
  orderNumber,
  orderDate,
  items = [],
  subtotal,
  tax,
  shipping,
  total,
  shippingAddress,
  trackingUrl
}) {
  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount / 100);
  };

  const formatDate = (date) => {
    return new Intl.DateTimeFormat('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    }).format(new Date(date));
  };

  return (
    <Html>
      <Head />
      <Preview>Order #{orderNumber} confirmed - Thank you for your purchase!</Preview>
      
      <Body style={main}>
        <Container style={container}>
          <Section style={content}>
            <Text style={heading}>Order Confirmed!</Text>
            
            <Text style={paragraph}>
              Hi {customerName}, thank you for your order. We've received your payment and are preparing your items for shipment.
            </Text>

            {/* Order Details */}
            <Section style={orderDetails}>
              <Row>
                <Column style={{ width: '50%' }}>
                  <Text style={label}>Order Number:</Text>
                  <Text style={value}>#{orderNumber}</Text>
                </Column>
                <Column style={{ width: '50%' }}>
                  <Text style={label}>Order Date:</Text>
                  <Text style={value}>{formatDate(orderDate)}</Text>
                </Column>
              </Row>
            </Section>

            {/* Items Table */}
            <Section style={itemsSection}>
              <Text style={sectionHeading}>Items Ordered</Text>
              
              {items.map((item, index) => (
                <Row key={index} style={itemRow}>
                  <Column style={{ width: '60%' }}>
                    <Text style={itemName}>{item.name}</Text>
                    <Text style={itemDescription}>{item.description}</Text>
                  </Column>
                  <Column style={{ width: '20%', textAlign: 'center' }}>
                    <Text style={itemQuantity}>Qty: {item.quantity}</Text>
                  </Column>
                  <Column style={{ width: '20%', textAlign: 'right' }}>
                    <Text style={itemPrice}>{formatCurrency(item.price)}</Text>
                  </Column>
                </Row>
              ))}
            </Section>

            {/* Order Summary */}
            <Section style={summarySection}>
              <Row style={summaryRow}>
                <Column style={{ width: '70%' }}>
                  <Text style={summaryLabel}>Subtotal:</Text>
                </Column>
                <Column style={{ width: '30%', textAlign: 'right' }}>
                  <Text style={summaryValue}>{formatCurrency(subtotal)}</Text>
                </Column>
              </Row>
              
              <Row style={summaryRow}>
                <Column style={{ width: '70%' }}>
                  <Text style={summaryLabel}>Tax:</Text>
                </Column>
                <Column style={{ width: '30%', textAlign: 'right' }}>
                  <Text style={summaryValue}>{formatCurrency(tax)}</Text>
                </Column>
              </Row>
              
              <Row style={summaryRow}>
                <Column style={{ width: '70%' }}>
                  <Text style={summaryLabel}>Shipping:</Text>
                </Column>
                <Column style={{ width: '30%', textAlign: 'right' }}>
                  <Text style={summaryValue}>{formatCurrency(shipping)}</Text>
                </Column>
              </Row>
              
              <Hr style={summaryDivider} />
              
              <Row style={totalRow}>
                <Column style={{ width: '70%' }}>
                  <Text style={totalLabel}>Total:</Text>
                </Column>
                <Column style={{ width: '30%', textAlign: 'right' }}>
                  <Text style={totalValue}>{formatCurrency(total)}</Text>
                </Column>
              </Row>
            </Section>

            {/* Shipping Information */}
            <Section style={shippingSection}>
              <Text style={sectionHeading}>Shipping Address</Text>
              <Text style={address}>
                {shippingAddress.name}<br/>
                {shippingAddress.line1}<br/>
                {shippingAddress.line2 && <>{shippingAddress.line2}<br/></>}
                {shippingAddress.city}, {shippingAddress.state} {shippingAddress.postal_code}<br/>
                {shippingAddress.country}
              </Text>
            </Section>

            {/* Tracking */}
            {trackingUrl && (
              <Section style={buttonContainer}>
                <Button href={trackingUrl} style={button}>
                  Track Your Order
                </Button>
              </Section>
            )}
          </Section>
        </Container>
      </Body>
    </Html>
  );
}
```

---

## Authentication & Security

### 4. How do you secure Resend API usage and manage API keys?

**Answer:**
Securing Resend requires **proper API key management**, **environment isolation**, and **security best practices**.

**API Key Management:**

```javascript
// config/resend.js
class ResendConfig {
  constructor() {
    this.validateEnvironment();
    this.setupApiKey();
  }

  validateEnvironment() {
    const requiredVars = ['RESEND_API_KEY'];
    const missing = requiredVars.filter(varName => !process.env[varName]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
  }

  setupApiKey() {
    const apiKey = process.env.RESEND_API_KEY;
    
    // Validate API key format
    if (!apiKey.startsWith('re_')) {
      throw new Error('Invalid Resend API key format');
    }

    // Environment-specific validation
    const environment = process.env.NODE_ENV;
    
    if (environment === 'production' && apiKey.includes('test')) {
      throw new Error('Test API key cannot be used in production');
    }

    if (environment !== 'production' && !apiKey.includes('test')) {
      console.warn('Using production API key in non-production environment');
    }

    this.apiKey = apiKey;
  }

  getApiKey() {
    return this.apiKey;
  }

  // Mask API key for logging
  getMaskedApiKey() {
    return this.apiKey.replace(/^(re_)(.{4}).*(.{4})$/, '$1$2****$3');
  }
}

export default new ResendConfig();
```

**Environment Separation:**

```javascript
// Different configurations per environment
const resendConfigs = {
  development: {
    apiKey: process.env.RESEND_DEV_API_KEY,
    fromEmail: 'dev@example.com',
    allowedDomains: ['localhost', '*.dev.example.com'],
    rateLimit: { requests: 100, period: '1h' },
    testMode: true,
  },
  
  staging: {
    apiKey: process.env.RESEND_STAGING_API_KEY,
    fromEmail: 'staging@example.com',
    allowedDomains: ['*.staging.example.com'],
    rateLimit: { requests: 500, period: '1h' },
    testMode: true,
  },
  
  production: {
    apiKey: process.env.RESEND_PROD_API_KEY,
    fromEmail: 'noreply@example.com',
    allowedDomains: ['example.com', '*.example.com'],
    rateLimit: { requests: 10000, period: '1h' },
    testMode: false,
  },
};

class SecureEmailService {
  constructor(environment = process.env.NODE_ENV) {
    this.config = resendConfigs[environment];
    this.resend = new Resend(this.config.apiKey);
    this.setupSecurity();
  }

  setupSecurity() {
    // Rate limiting
    this.rateLimiter = new Map();
    
    // Request logging
    this.requestLog = [];
    
    // Domain validation
    this.validateDomains();
  }

  validateDomains() {
    const allowedDomains = this.config.allowedDomains;
    
    // Validate from email domain
    const fromDomain = this.config.fromEmail.split('@')[1];
    const isAllowed = allowedDomains.some(domain => {
      if (domain.startsWith('*.')) {
        const baseDomain = domain.slice(2);
        return fromDomain.endsWith(baseDomain);
      }
      return domain === fromDomain;
    });

    if (!isAllowed) {
      throw new Error(`From email domain not allowed: ${fromDomain}`);
    }
  }

  async sendSecureEmail({ to, subject, html, userId, requestId }) {
    try {
      // Rate limiting check
      await this.checkRateLimit(userId || 'anonymous');
      
      // Input validation
      this.validateEmailInput({ to, subject, html });
      
      // Log request
      this.logRequest({ to, subject, userId, requestId });
      
      // Send email
      const result = await this.resend.emails.send({
        from: this.config.fromEmail,
        to,
        subject,
        html,
        tags: [
          { name: 'environment', value: process.env.NODE_ENV },
          { name: 'user_id', value: userId || 'anonymous' },
          { name: 'request_id', value: requestId }
        ]
      });

      // Log success
      this.logSuccess(result, requestId);
      
      return { success: true, id: result.id };
      
    } catch (error) {
      this.logError(error, requestId);
      throw error;
    }
  }

  async checkRateLimit(identifier) {
    const now = Date.now();
    const windowMs = 60 * 60 * 1000; // 1 hour
    const maxRequests = this.config.rateLimit.requests;

    if (!this.rateLimiter.has(identifier)) {
      this.rateLimiter.set(identifier, []);
    }

    const requests = this.rateLimiter.get(identifier);
    
    // Remove old requests
    const validRequests = requests.filter(time => now - time < windowMs);
    
    if (validRequests.length >= maxRequests) {
      throw new Error(`Rate limit exceeded for ${identifier}`);
    }

    validRequests.push(now);
    this.rateLimiter.set(identifier, validRequests);
  }

  validateEmailInput({ to, subject, html }) {
    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(to)) {
      throw new Error('Invalid email address');
    }

    // Subject validation
    if (!subject || subject.length > 200) {
      throw new Error('Invalid subject line');
    }

    // HTML validation (basic)
    if (!html || html.length > 1024 * 1024) { // 1MB limit
      throw new Error('Invalid HTML content');
    }

    // Check for suspicious content
    const suspiciousPatterns = [
      /<script/i,
      /javascript:/i,
      /vbscript:/i,
      /on\w+=/i,
    ];

    if (suspiciousPatterns.some(pattern => pattern.test(html))) {
      throw new Error('Suspicious content detected');
    }
  }

  logRequest({ to, subject, userId, requestId }) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      requestId,
      userId,
      to: this.maskEmail(to),
      subject,
      environment: process.env.NODE_ENV,
    };

    this.requestLog.push(logEntry);
    console.log('Email request:', logEntry);
  }

  maskEmail(email) {
    const [username, domain] = email.split('@');
    const maskedUsername = username.length > 2 
      ? `${username[0]}***${username[username.length - 1]}`
      : '***';
    return `${maskedUsername}@${domain}`;
  }
}
```

---

## Navigation Links

⬅️ **[Previous: Stripe Questions](./stripe-questions.md)**  
➡️ **[Next: AI-Assisted Development Questions](./ai-assisted-development-questions.md)**  
🏠 **[Home: Interview Questions Index](./README.md)**

---

*This research covers Resend email API integration, templates, security, and best practices for the Dev Partners Senior Full Stack Developer position.*
