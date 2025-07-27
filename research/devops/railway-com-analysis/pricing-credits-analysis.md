# Pricing and Credits Analysis

## Overview

Railway.com operates on a **consumption-based credit system** where you pay for actual resource usage rather than traditional fixed monthly hosting fees. This document provides a comprehensive analysis of how the credit system works, subscription plans, and specific cost implications for different application types.

## Credit System Mechanics

### How Credits Work

Railway credits are **monetary units** that represent actual dollar amounts:
- **1 credit = $1 USD**
- Credits are consumed in real-time based on resource usage
- Usage is calculated **per second** for fine-grained billing
- Credits are **non-transferable** and **don't roll over** between months

### Resource Consumption Metrics

Credits are consumed based on the following resources:

| Resource Type | Billing Model | Typical Cost |
|---------------|---------------|--------------|
| **CPU Usage** | Per vCPU-hour | $0.000231/vCPU-hour |
| **Memory (RAM)** | Per GB-hour | $0.000231/GB-hour |
| **Storage** | Per GB-month | $0.25/GB-month |
| **Network Egress** | Per GB transferred | $0.10/GB |
| **Network Ingress** | Free | $0.00 |
| **Database CPU** | Per vCPU-hour | $0.000694/vCPU-hour |
| **Database Memory** | Per GB-hour | $0.000694/GB-hour |

### Billing Calculation Examples

**Example 1: Express.js API Server**
- 1 vCPU, 1GB RAM running 24/7 for a month (720 hours)
- CPU cost: 720 × $0.000231 = $0.17
- Memory cost: 720 × $0.000231 = $0.17
- **Total: ~$0.34/month**

**Example 2: MySQL Database**
- 1 vCPU, 2GB RAM, 5GB storage running 24/7
- CPU cost: 720 × $0.000694 = $0.50
- Memory cost: 720 × 2 × $0.000694 = $1.00
- Storage cost: 5 × $0.25 = $1.25
- **Total: ~$2.75/month**

## Subscription Plans Detailed Analysis

### Trial Plan (Free)
- **Duration**: 500 hours of usage or $5 in credits (whichever comes first)
- **Credits**: $5 total
- **Resource Limits**: 8GB RAM, 8 vCPU per service
- **Features**: All core features, limited time
- **Best For**: Testing and evaluation

### Hobby Plan ($5/month)
- **Monthly Cost**: $5 minimum
- **Credits Included**: $5 worth of usage
- **Resource Limits**: 8GB RAM, 8 vCPU per service
- **Features**: Personal projects, basic support
- **Overage**: Pay for usage above $5
- **Best For**: Side projects, personal applications

### Pro Plan ($20/month) - Detailed Analysis

**This is the plan mentioned in your question. Here's exactly how it works:**

#### Pro Plan Features
- **Monthly Minimum**: **$20** (you pay this regardless of usage)
- **Credits Included**: **$20 worth of usage**
- **Resource Limits**: **32GB RAM, 32 vCPU per service**
- **Team Seats**: **Unlimited** team members
- **Support**: **Priority support** with faster response times
- **Regions**: **Concurrent global regions** for multi-region deployments
- **Monitoring**: **Advanced metrics** and observability tools

#### How the $20 Minimum Works

**Scenario 1: Low Usage (Under $20)**
- Your actual usage: $8/month
- Amount charged: **$20** (you pay the minimum)
- Unused credits: $12 (these **don't roll over** to next month)

**Scenario 2: Moderate Usage (Exactly $20)**
- Your actual usage: $20/month
- Amount charged: **$20** (exactly the minimum)
- No additional charges

**Scenario 3: High Usage (Over $20)**
- Your actual usage: $35/month
- Amount charged: **$35** ($20 included + $15 overage)
- You pay for actual consumption above the minimum

#### Pro Plan Value Proposition
- **Higher resource limits**: Essential for production applications
- **Team collaboration**: Multiple developers on same project
- **Priority support**: Faster issue resolution
- **Global deployment**: Multi-region capabilities
- **Professional SLA**: Better uptime guarantees

## Team Plan ($100+/month)
- **Monthly Minimum**: $100+
- **Credits Included**: $100+ worth of usage
- **Resource Limits**: Custom (can be increased)
- **Features**: Enterprise features, custom SLA
- **Best For**: Large teams, enterprise applications

## Clinic Management System Cost Analysis

Based on your specific use case (clinic management system with 2-3 users), here's a detailed cost breakdown:

### Application Architecture
- **Frontend**: React/Vite static site (apps/web)
- **Backend**: Express.js API (apps/api)
- **Database**: MySQL database
- **Users**: 2-3 staff members
- **Traffic**: Low (typical small clinic usage)

### Estimated Resource Usage

#### Frontend (React/Vite Static Site)
- **Deployment**: Static site hosting
- **Monthly Cost**: **$0** (static sites are free on Railway)
- **Bandwidth**: Minimal for 2-3 users

#### Backend (Express.js API)
- **CPU**: 0.5 vCPU (low utilization)
- **Memory**: 512MB (sufficient for small API)
- **Running Time**: 24/7 (always available)
- **Monthly Cost**: 
  - CPU: 720 × 0.5 × $0.000231 = **$0.08**
  - Memory: 720 × 0.5 × $0.000231 = **$0.08**
  - **Subtotal**: **$0.16**

#### MySQL Database
- **CPU**: 0.25 vCPU (low query volume)
- **Memory**: 1GB (adequate for clinic data)
- **Storage**: 2GB initially (patient records, schedules)
- **Monthly Cost**:
  - CPU: 720 × 0.25 × $0.000694 = **$0.12**
  - Memory: 720 × 1 × $0.000694 = **$0.50**
  - Storage: 2 × $0.25 = **$0.50**
  - **Subtotal**: **$1.12**

#### Network and Miscellaneous
- **Bandwidth**: <100MB/month (very low usage)
- **Cost**: **<$0.01**

### Total Monthly Usage Cost
**Frontend**: $0.00  
**Backend**: $0.16  
**Database**: $1.12  
**Network**: <$0.01  
**Total Estimated Usage**: **~$1.30/month**

### Subscription Plan Implications

#### If You Choose Hobby Plan ($5/month)
- **Actual usage**: ~$1.30
- **Amount charged**: **$5** (minimum)
- **Unused credits**: ~$3.70 (don't roll over)
- **Limitations**: 8GB RAM, 8 vCPU (sufficient for your use case)

#### If You Choose Pro Plan ($20/month)
- **Actual usage**: ~$1.30
- **Amount charged**: **$20** (minimum)
- **Unused credits**: ~$18.70 (don't roll over)
- **Benefits**: Higher limits, team features, priority support

### Recommendation for Clinic Management System

**Start with Hobby Plan ($5/month)** because:
1. Your estimated usage (~$1.30) is well within limits
2. 8GB RAM/8 vCPU is sufficient for 2-3 users
3. Saves $15/month compared to Pro plan
4. Can upgrade later if needed

**Consider Pro Plan if**:
- You need team collaboration features
- Require priority support for business-critical application
- Plan to scale beyond 8GB RAM/8 vCPU limits
- Need global deployment capabilities

## Credit System Deep Dive

### Credit Consumption Patterns

**Continuous Usage** (Database, always-on API):
- Credits consumed **24/7** based on allocated resources
- Predictable monthly costs

**On-Demand Usage** (Frontend builds, background jobs):
- Credits consumed only during execution
- Variable costs based on activity

**Scaling Events**:
- Additional credits consumed when services auto-scale
- Temporary cost increases during traffic spikes

### Monitoring and Optimization

#### Usage Monitoring
1. **Dashboard**: Real-time credit consumption tracking
2. **Alerts**: Set up notifications for usage thresholds
3. **Historical Data**: Analyze usage patterns over time
4. **Service Breakdown**: Per-service credit consumption

#### Cost Optimization Strategies
1. **Right-sizing**: Allocate appropriate resources for actual needs
2. **Auto-scaling**: Configure proper scaling thresholds
3. **Resource sharing**: Use single database for multiple services
4. **Efficient builds**: Optimize build processes to reduce compute usage
5. **Monitoring**: Regular review of usage patterns

## Pricing Comparison with Alternatives

| Platform | Entry Cost | Database | Scalability | Best For |
|----------|------------|----------|-------------|----------|
| **Railway (Hobby)** | $5/month | Included | Automatic | Small apps |
| **Railway (Pro)** | $20/month | Included | High limits | Professional |
| **Vercel** | $20/month | External | Frontend focus | Static sites |
| **Render** | $7/month | $7/month | Manual | Full-stack |
| **Heroku** | $7/month | $9/month | Complex | Enterprise |

## Frequently Asked Questions

### Q: Do credits roll over between months?
**A: No.** Unused credits are forfeited at the end of each billing cycle.

### Q: What happens if I exceed my credit allocation?
**A: You're charged for the additional usage** at the same per-unit rates.

### Q: Can I set spending limits?
**A: Yes.** Railway provides spending alerts and hard limits to prevent unexpected charges.

### Q: How is database storage billed?
**A: Storage is billed monthly** based on actual usage, not allocated space.

### Q: Are there any hidden fees?
**A: No.** All costs are based on transparent resource consumption metrics.

### Q: Can I downgrade my plan?
**A: Yes.** You can change plans at any time, taking effect in the next billing cycle.

---

## Next Steps

1. **[Set Up MySQL Database](./mysql-database-deployment.md)** - Database configuration guide
2. **[Review Implementation Guide](./implementation-guide.md)** - Complete deployment instructions
3. **[Check Best Practices](./best-practices.md)** - Cost optimization strategies

---

*Pricing and Credits Analysis | Railway.com Platform | January 2025*