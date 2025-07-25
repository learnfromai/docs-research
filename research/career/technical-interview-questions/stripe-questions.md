# Stripe API Interview Questions & Answers

## 📋 Table of Contents

1. **[Stripe Fundamentals](#stripe-fundamentals)** - Core concepts and platform overview
2. **[Payment Processing](#payment-processing)** - Charges, payment methods, and transactions
3. **[Webhooks & Events](#webhooks--events)** - Real-time event handling
4. **[Subscription Management](#subscription-management)** - Recurring billing and subscriptions
5. **[Security & Compliance](#security--compliance)** - PCI compliance and best practices
6. **[Advanced Features](#advanced-features)** - Connect, marketplace, and complex flows
7. **[Error Handling & Testing](#error-handling--testing)** - Testing strategies and error management

---

## Stripe Fundamentals

### 1. What is Stripe and how does it differ from other payment processors?

**Answer:**
Stripe is a **technology-first payment processor** that provides APIs and tools for internet businesses to accept and manage online payments.

**Core Differences:**

| Feature | Stripe | Traditional Processors | PayPal |
|---------|--------|----------------------|--------|
| **Integration** | API-first, developer-friendly | Complex merchant accounts | Widget-based |
| **Setup Time** | Minutes | Weeks/months | Hours |
| **Customization** | Full control over UX | Limited customization | Branded experience |
| **Global Reach** | 40+ countries | Varies by processor | 200+ countries |
| **Pricing Model** | Transparent per-transaction | Setup fees + monthly | Per-transaction |

**Stripe's Architecture:**

```javascript
// Stripe's API-first approach
const stripe = require('stripe')('sk_test_...');

// Simple payment intent creation
const paymentIntent = await stripe.paymentIntents.create({
  amount: 2000, // $20.00
  currency: 'usd',
  payment_method_types: ['card'],
  metadata: {
    order_id: 'order_12345',
    customer_email: 'customer@example.com'
  }
});

// Compared to traditional processor complexity
// - No merchant account setup
// - No payment gateway configuration
// - No PCI compliance burden (with hosted solutions)
// - Immediate testing capability
```

**Key Advantages:**

**1. Developer Experience:**

```javascript
// Clean, RESTful API design
// GET /v1/customers
// POST /v1/payment_intents
// PUT /v1/subscriptions/{id}

// Comprehensive libraries
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Real-time testing
const testPayment = await stripe.paymentIntents.create({
  amount: 1000,
  currency: 'usd',
  payment_method: 'pm_card_visa', // Test card
});
```

**2. Global Capabilities:**

```javascript
// Multi-currency support
const payment = await stripe.paymentIntents.create({
  amount: 1000,
  currency: 'eur', // Automatic conversion
  payment_method_types: ['card', 'sepa_debit', 'ideal'],
});

// Localized payment methods
const localMethods = {
  'US': ['card', 'us_bank_account'],
  'EU': ['card', 'sepa_debit', 'ideal', 'sofort'],
  'MX': ['card', 'oxxo'],
  'JP': ['card', 'konbini'],
};
```

---

### 2. Explain Stripe's pricing model and fee structure

**Answer:**
Stripe uses a **transparent, pay-as-you-go** pricing model with no setup fees or monthly minimums for standard accounts.

**Standard Pricing Structure:**

```javascript
// US Pricing (as of 2024)
const stripeFees = {
  // Online payments
  standardCard: '2.9% + 30¢',
  internationalCard: '3.4% + 30¢',
  
  // In-person payments (Terminal)
  inPersonCard: '2.7% + 5¢',
  
  // Additional fees
  disputes: '$15 per dispute',
  refunds: 'No fee (original fee not returned)',
  payouts: 'No fee for standard (next business day)',
  instantPayouts: '1.5% (minimum 50¢)',
};

// Calculate total cost
function calculateStripeFee(amount, isInternational = false) {
  const percentage = isInternational ? 0.034 : 0.029;
  const fixedFee = 30; // cents
  
  return Math.round(amount * percentage) + fixedFee;
}

// Example: $100 payment
const paymentAmount = 10000; // $100.00 in cents
const fee = calculateStripeFee(paymentAmount); // $320 (2.9% + 30¢)
const netAmount = paymentAmount - fee; // $96.80
```

**Volume Pricing:**

```javascript
// Custom pricing for high-volume businesses
const volumePricing = {
  // Qualification criteria
  monthlyVolume: '>$80,000',
  or: 'High-growth startups',
  
  // Benefits
  reducedRates: 'Negotiated percentage rates',
  customTerms: 'Tailored payment terms',
  dedicatedSupport: 'Priority technical support',
  
  // Example savings
  standardRate: '2.9% + 30¢',
  customRate: '2.4% + 30¢', // Example reduction
  monthlySavings: '$4,000', // On $100k volume
};
```

**International Pricing:**

```javascript
// Regional pricing variations
const regionalPricing = {
  'United States': {
    domestic: '2.9% + 30¢',
    international: '3.4% + 30¢',
  },
  'European Union': {
    domestic: '1.4% + 25¢',
    international: '2.9% + 25¢',
  },
  'United Kingdom': {
    domestic: '1.4% + 20p',
    international: '2.9% + 20p',
  },
  'Australia': {
    domestic: '1.75% + 30¢',
    international: '3.4% + 30¢',
  },
};
```

---

## Payment Processing

### 3. How do you implement a secure payment flow with Stripe?

**Answer:**
Secure payment implementation follows Stripe's **recommended patterns** with proper token handling and server-side processing.

**Frontend Payment Collection:**

```javascript
// Client-side (React example)
import { loadStripe } from '@stripe/stripe-js';
import {
  Elements,
  CardElement,
  useStripe,
  useElements
} from '@stripe/react-stripe-js';

const stripePromise = loadStripe('pk_test_...');

function PaymentForm({ onSuccess }) {
  const stripe = useStripe();
  const elements = useElements();
  const [isProcessing, setIsProcessing] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    
    if (!stripe || !elements) return;
    
    setIsProcessing(true);
    
    try {
      // Get card element
      const card = elements.getElement(CardElement);
      
      // Create payment method
      const { error, paymentMethod } = await stripe.createPaymentMethod({
        type: 'card',
        card: card,
        billing_details: {
          name: 'Customer Name',
          email: 'customer@example.com',
        },
      });
      
      if (error) {
        console.error('Payment method creation failed:', error);
        return;
      }
      
      // Send to backend for processing
      const response = await fetch('/api/process-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          payment_method_id: paymentMethod.id,
          amount: 2000, // $20.00
          currency: 'usd',
        }),
      });
      
      const result = await response.json();
      
      if (result.requires_action) {
        // Handle 3D Secure authentication
        const { error } = await stripe.confirmCardPayment(
          result.payment_intent.client_secret
        );
        
        if (!error) {
          onSuccess(result.payment_intent);
        }
      } else if (result.succeeded) {
        onSuccess(result.payment_intent);
      }
      
    } catch (error) {
      console.error('Payment processing error:', error);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <CardElement
        options={{
          style: {
            base: {
              fontSize: '16px',
              color: '#424770',
              '::placeholder': { color: '#aab7c4' },
            },
          },
        }}
      />
      <button disabled={!stripe || isProcessing}>
        {isProcessing ? 'Processing...' : 'Pay Now'}
      </button>
    </form>
  );
}

// App component
function App() {
  return (
    <Elements stripe={stripePromise}>
      <PaymentForm onSuccess={(paymentIntent) => {
        console.log('Payment succeeded:', paymentIntent.id);
      }} />
    </Elements>
  );
}
```

**Backend Payment Processing:**

```javascript
// Server-side (Node.js/Express)
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

app.post('/api/process-payment', async (req, res) => {
  try {
    const { payment_method_id, amount, currency = 'usd' } = req.body;
    
    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method: payment_method_id,
      confirmation_method: 'manual',
      confirm: true,
      return_url: 'https://your-website.com/return',
    });
    
    // Handle payment status
    if (paymentIntent.status === 'requires_action') {
      // 3D Secure or other authentication required
      res.json({
        requires_action: true,
        payment_intent: {
          id: paymentIntent.id,
          client_secret: paymentIntent.client_secret,
        },
      });
    } else if (paymentIntent.status === 'succeeded') {
      // Payment completed successfully
      res.json({
        succeeded: true,
        payment_intent: paymentIntent,
      });
    } else {
      // Payment failed
      res.status(400).json({
        error: 'Payment failed',
        payment_intent: paymentIntent,
      });
    }
    
  } catch (error) {
    console.error('Payment processing error:', error);
    
    if (error.type === 'StripeCardError') {
      // Card was declined
      res.status(400).json({
        error: error.message,
        decline_code: error.decline_code,
      });
    } else {
      // Other error
      res.status(500).json({
        error: 'An error occurred while processing payment',
      });
    }
  }
});
```

**Advanced Security Implementations:**

```javascript
// Input validation and sanitization
const Joi = require('joi');

const paymentSchema = Joi.object({
  payment_method_id: Joi.string().pattern(/^pm_[a-zA-Z0-9]+$/).required(),
  amount: Joi.number().integer().min(50).max(999999).required(), // $0.50 - $9,999.99
  currency: Joi.string().length(3).lowercase().required(),
  customer_id: Joi.string().pattern(/^cus_[a-zA-Z0-9]+$/).optional(),
  metadata: Joi.object().max(20).optional(), // Max 20 metadata keys
});

// Rate limiting
const rateLimit = require('express-rate-limit');

const paymentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Max 5 payment attempts per IP
  message: 'Too many payment attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// Idempotency handling
app.post('/api/process-payment', paymentLimiter, async (req, res) => {
  try {
    // Validate input
    const { error, value } = paymentSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }
    
    // Generate idempotency key
    const idempotencyKey = req.headers['idempotency-key'] || 
      `payment_${Date.now()}_${Math.random()}`;
    
    const paymentIntent = await stripe.paymentIntents.create({
      ...value,
      metadata: {
        ...value.metadata,
        ip_address: req.ip,
        user_agent: req.get('User-Agent'),
      },
    }, {
      idempotencyKey,
    });
    
    // Log for monitoring
    console.log('Payment processed:', {
      payment_intent_id: paymentIntent.id,
      amount: value.amount,
      currency: value.currency,
      status: paymentIntent.status,
    });
    
    res.json({ payment_intent: paymentIntent });
    
  } catch (error) {
    console.error('Payment error:', error);
    res.status(500).json({ error: 'Payment processing failed' });
  }
});
```

---

### 4. How do you handle different payment methods in Stripe?

**Answer:**
Stripe supports **multiple payment methods** with unified APIs while handling regional preferences and requirements.

**Payment Method Types:**

```javascript
// Common payment methods by region
const paymentMethods = {
  global: ['card'],
  northAmerica: ['card', 'us_bank_account', 'apple_pay', 'google_pay'],
  europe: ['card', 'sepa_debit', 'ideal', 'sofort', 'bancontact', 'giropay'],
  asia: ['card', 'alipay', 'wechat_pay', 'grabpay'],
  latinAmerica: ['card', 'oxxo', 'boleto'],
  australia: ['card', 'au_becs_debit'],
};

// Dynamic payment method configuration
function getPaymentMethods(country, currency) {
  const methodMap = {
    'US': ['card', 'us_bank_account'],
    'GB': ['card', 'bacs_debit'],
    'DE': ['card', 'sepa_debit', 'sofort', 'giropay'],
    'NL': ['card', 'sepa_debit', 'ideal'],
    'MX': ['card', 'oxxo'],
    'BR': ['card', 'boleto'],
    'SG': ['card', 'grabpay'],
    'MY': ['card', 'fpx', 'grabpay'],
  };
  
  return methodMap[country] || ['card'];
}
```

**Frontend Multi-Payment Method Setup:**

```javascript
// React component with multiple payment methods
import {
  PaymentElement,
  Elements,
  useStripe,
  useElements
} from '@stripe/react-stripe-js';

function MultiPaymentForm({ amount, currency, country }) {
  const stripe = useStripe();
  const elements = useElements();
  const [clientSecret, setClientSecret] = useState('');

  useEffect(() => {
    // Create payment intent with appropriate payment methods
    fetch('/api/create-payment-intent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount,
        currency,
        payment_method_types: getPaymentMethods(country, currency),
      }),
    })
    .then(res => res.json())
    .then(data => setClientSecret(data.client_secret));
  }, [amount, currency, country]);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!stripe || !elements) return;

    const result = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/payment-success`,
      },
    });

    if (result.error) {
      console.error('Payment failed:', result.error.message);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {clientSecret && (
        <PaymentElement
          options={{
            layout: 'tabs',
            paymentMethodOrder: ['card', 'apple_pay', 'google_pay']
          }}
        />
      )}
      <button disabled={!stripe}>Pay Now</button>
    </form>
  );
}

// Elements wrapper with appearance customization
const appearance = {
  theme: 'stripe',
  variables: {
    colorPrimary: '#0570de',
    colorBackground: '#ffffff',
    colorText: '#30313d',
    colorDanger: '#df1b41',
    fontFamily: 'Inter, sans-serif',
    spacingUnit: '4px',
    borderRadius: '8px',
  },
};

function PaymentApp() {
  return (
    <Elements
      stripe={stripePromise}
      options={{
        clientSecret,
        appearance,
        loader: 'auto',
      }}
    >
      <MultiPaymentForm />
    </Elements>
  );
}
```

**Backend Payment Method Handling:**

```javascript
// Create payment intent with regional payment methods
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency, country, customer_id } = req.body;
    
    // Get appropriate payment methods for region
    const paymentMethodTypes = getPaymentMethods(country, currency);
    
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method_types: paymentMethodTypes,
      customer: customer_id,
      
      // Regional configurations
      ...(country === 'US' && {
        statement_descriptor: 'YOUR BUSINESS',
        receipt_email: 'customer@example.com',
      }),
      
      ...(currency === 'eur' && {
        statement_descriptor: 'YOUR BUSINESS EU',
      }),
      
      // Payment method specific options
      payment_method_options: {
        card: {
          request_three_d_secure: 'automatic',
          statement_descriptor_suffix_kana: null,
          statement_descriptor_suffix_kanji: null,
        },
        
        us_bank_account: {
          verification_method: 'automatic',
        },
        
        sepa_debit: {
          mandate_options: {
            reference: `MANDATE_${Date.now()}`,
          },
        },
        
        sofort: {
          preferred_language: country === 'DE' ? 'de' : 'en',
        },
      },
      
      metadata: {
        country,
        payment_method_types: paymentMethodTypes.join(','),
      },
    });
    
    res.json({
      client_secret: paymentIntent.client_secret,
      payment_methods: paymentMethodTypes,
    });
    
  } catch (error) {
    console.error('Payment intent creation error:', error);
    res.status(500).json({ error: error.message });
  }
});
```

**Payment Method Specific Handling:**

```javascript
// Handle different payment method confirmations
async function handlePaymentConfirmation(paymentMethod, paymentIntent) {
  switch (paymentMethod.type) {
    case 'card':
      // Handled by Stripe.js automatically
      break;
      
    case 'sepa_debit':
      // SEPA Direct Debit - mandate required
      console.log('SEPA mandate:', paymentMethod.sepa_debit.mandate);
      break;
      
    case 'us_bank_account':
      // ACH - verification may be required
      if (paymentIntent.status === 'requires_action') {
        // Handle micro-deposit verification
        await handleBankVerification(paymentIntent);
      }
      break;
      
    case 'oxxo':
      // OXXO - customer needs voucher
      const voucher = paymentIntent.next_action.oxxo_display_details;
      console.log('OXXO voucher number:', voucher.number);
      break;
      
    case 'ideal':
      // iDEAL - redirect to bank
      window.location.href = paymentIntent.next_action.redirect_to_url.url;
      break;
      
    case 'alipay':
      // Alipay - QR code or redirect
      if (paymentIntent.next_action.alipay_handle_redirect) {
        window.location.href = paymentIntent.next_action.alipay_handle_redirect.url;
      }
      break;
  }
}

// Save payment method for future use
async function savePaymentMethod(customerId, paymentMethodId, isDefault = false) {
  try {
    // Attach to customer
    await stripe.paymentMethods.attach(paymentMethodId, {
      customer: customerId,
    });
    
    // Set as default if requested
    if (isDefault) {
      await stripe.customers.update(customerId, {
        invoice_settings: {
          default_payment_method: paymentMethodId,
        },
      });
    }
    
    return { success: true };
  } catch (error) {
    console.error('Failed to save payment method:', error);
    return { success: false, error: error.message };
  }
}
```

---

## Webhooks & Events

### 5. How do you implement and secure Stripe webhooks?

**Answer:**
Webhooks provide **real-time notifications** about Stripe events. Proper implementation requires signature verification and idempotent processing.

**Webhook Endpoint Implementation:**

```javascript
// Express.js webhook endpoint
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

// Raw body parser for webhook verification
app.use('/api/webhooks/stripe', express.raw({ type: 'application/json' }));

app.post('/api/webhooks/stripe', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  try {
    await handleStripeEvent(event);
    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Event handler with idempotency
async function handleStripeEvent(event) {
  // Check if event already processed (idempotency)
  const existingEvent = await db.webhookEvents.findOne({
    stripe_event_id: event.id
  });
  
  if (existingEvent) {
    console.log('Event already processed:', event.id);
    return;
  }

  // Process based on event type
  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentSucceeded(event.data.object);
      break;
      
    case 'payment_intent.payment_failed':
      await handlePaymentFailed(event.data.object);
      break;
      
    case 'customer.subscription.created':
      await handleSubscriptionCreated(event.data.object);
      break;
      
    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event.data.object);
      break;
      
    case 'customer.subscription.deleted':
      await handleSubscriptionCanceled(event.data.object);
      break;
      
    case 'invoice.payment_succeeded':
      await handleInvoicePaymentSucceeded(event.data.object);
      break;
      
    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event.data.object);
      break;
      
    default:
      console.log('Unhandled event type:', event.type);
  }

  // Mark event as processed
  await db.webhookEvents.create({
    stripe_event_id: event.id,
    event_type: event.type,
    processed_at: new Date(),
    data: event.data.object
  });
}
```

**Event Processing Functions:**

```javascript
// Payment success handler
async function handlePaymentSucceeded(paymentIntent) {
  const { id, amount, currency, customer, metadata } = paymentIntent;
  
  try {
    // Update order status
    if (metadata.order_id) {
      await db.orders.update(metadata.order_id, {
        status: 'paid',
        payment_intent_id: id,
        paid_at: new Date(),
        amount_paid: amount,
        currency
      });
      
      // Send confirmation email
      await emailService.sendOrderConfirmation(metadata.order_id);
      
      // Update inventory
      await inventoryService.updateStock(metadata.order_id);
    }
    
    // Update customer data
    if (customer) {
      await db.customers.update(customer, {
        last_payment_at: new Date(),
        total_spent: db.raw('total_spent + ?', [amount])
      });
    }
    
    console.log('Payment processed successfully:', id);
  } catch (error) {
    console.error('Error processing payment success:', error);
    throw error; // Will trigger webhook retry
  }
}

// Subscription event handlers
async function handleSubscriptionCreated(subscription) {
  const { id, customer, status, current_period_start, current_period_end } = subscription;
  
  await db.subscriptions.create({
    stripe_subscription_id: id,
    customer_id: customer,
    status,
    current_period_start: new Date(current_period_start * 1000),
    current_period_end: new Date(current_period_end * 1000),
    created_at: new Date()
  });
  
  // Grant access to subscription features
  await userService.grantSubscriptionAccess(customer, subscription);
  
  // Send welcome email
  await emailService.sendSubscriptionWelcome(customer, subscription);
}

async function handleSubscriptionUpdated(subscription) {
  const { id, status, cancel_at_period_end } = subscription;
  
  await db.subscriptions.update(
    { stripe_subscription_id: id },
    {
      status,
      cancel_at_period_end,
      updated_at: new Date()
    }
  );
  
  // Handle status changes
  if (status === 'active') {
    await userService.reactivateSubscription(subscription.customer);
  } else if (status === 'canceled') {
    await userService.cancelSubscription(subscription.customer);
  }
}
```

**Webhook Security Best Practices:**

```javascript
// Advanced webhook security
class StripeWebhookHandler {
  constructor(options = {}) {
    this.endpointSecret = options.endpointSecret || process.env.STRIPE_WEBHOOK_SECRET;
    this.tolerance = options.tolerance || 300; // 5 minutes
    this.retryConfig = options.retry || { maxRetries: 3, backoffMultiplier: 2 };
  }

  async verifySignature(body, signature, timestamp) {
    // Check timestamp to prevent replay attacks
    const timestampDiff = Math.abs(Date.now() / 1000 - timestamp);
    if (timestampDiff > this.tolerance) {
      throw new Error('Webhook timestamp too old');
    }

    // Verify signature
    const expectedSignature = crypto
      .createHmac('sha256', this.endpointSecret)
      .update(`${timestamp}.${body}`)
      .digest('hex');

    const signatureHash = signature.split('=')[1];
    
    if (!crypto.timingSafeEqual(
      Buffer.from(expectedSignature),
      Buffer.from(signatureHash)
    )) {
      throw new Error('Invalid webhook signature');
    }
  }

  async processWithRetry(eventHandler, event, retryCount = 0) {
    try {
      await eventHandler(event);
    } catch (error) {
      if (retryCount < this.retryConfig.maxRetries) {
        const delay = Math.pow(this.retryConfig.backoffMultiplier, retryCount) * 1000;
        
        console.log(`Retrying webhook processing in ${delay}ms (attempt ${retryCount + 1})`);
        
        setTimeout(() => {
          this.processWithRetry(eventHandler, event, retryCount + 1);
        }, delay);
      } else {
        console.error('Max retries exceeded for webhook:', event.id);
        
        // Send to dead letter queue or alert system
        await this.handleFailedWebhook(event, error);
        throw error;
      }
    }
  }

  async handleFailedWebhook(event, error) {
    // Log to monitoring system
    await monitoringService.alert('webhook_failed', {
      event_id: event.id,
      event_type: event.type,
      error: error.message,
      retry_count: this.retryConfig.maxRetries
    });

    // Store for manual processing
    await db.failedWebhooks.create({
      stripe_event_id: event.id,
      event_type: event.type,
      error_message: error.message,
      event_data: event.data,
      failed_at: new Date()
    });
  }
}
```

**Testing Webhooks:**

```javascript
// Local webhook testing with Stripe CLI
// stripe listen --forward-to localhost:3000/api/webhooks/stripe

// Test webhook processing
async function testWebhookProcessing() {
  const testEvents = [
    'payment_intent.succeeded',
    'customer.subscription.created',
    'invoice.payment_failed'
  ];

  for (const eventType of testEvents) {
    try {
      // Trigger test event
      const response = await fetch('https://api.stripe.com/v1/webhook_endpoints/trigger', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.STRIPE_SECRET_KEY}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `event_type=${eventType}`
      });

      console.log(`Test event ${eventType} triggered:`, response.status);
    } catch (error) {
      console.error(`Failed to trigger ${eventType}:`, error);
    }
  }
}

// Webhook monitoring and analytics
async function getWebhookMetrics(timeframe = '7d') {
  const metrics = await db.webhookEvents.aggregate([
    {
      $match: {
        processed_at: {
          $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
        }
      }
    },
    {
      $group: {
        _id: '$event_type',
        count: { $sum: 1 },
        avgProcessingTime: { $avg: '$processing_time' }
      }
    }
  ]);

  return {
    totalEvents: metrics.reduce((sum, m) => sum + m.count, 0),
    eventTypes: metrics,
    successRate: await calculateWebhookSuccessRate(timeframe),
    avgProcessingTime: metrics.reduce((sum, m) => sum + m.avgProcessingTime, 0) / metrics.length
  };
}
```

---

## Navigation Links

⬅️ **[Previous: GitHub Questions](./github-questions.md)**  
➡️ **[Next: Resend Questions](./resend-questions.md)**  
🏠 **[Home: Interview Questions Index](./README.md)**

---

*This research covers Stripe payment processing, webhooks, security, and API integration for the Dev Partners Senior Full Stack Developer position.*
