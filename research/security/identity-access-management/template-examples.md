# Template Examples: Working Configurations & Code Samples

> **Ready-to-use templates, configurations, and code examples for implementing OAuth2, SAML, and MFA in EdTech platforms**

## 🚀 Quick Start Templates

### **OAuth2 Provider Configuration**

#### **Auth0 Configuration for EdTech**

```json
{
  "name": "EdTech Platform - Production",
  "description": "Educational technology platform for K-12 schools",
  "logo_uri": "https://edtech-platform.com/logo.png",
  "callbacks": [
    "https://edtech-platform.com/auth/callback",
    "https://app.edtech-platform.com/auth/callback",
    "https://admin.edtech-platform.com/auth/callback"
  ],
  "allowed_logout_urls": [
    "https://edtech-platform.com/logout",
    "https://app.edtech-platform.com/logout"
  ],
  "allowed_origins": [
    "https://edtech-platform.com",
    "https://app.edtech-platform.com",
    "https://admin.edtech-platform.com"
  ],
  "web_origins": [
    "https://edtech-platform.com",
    "https://app.edtech-platform.com"
  ],
  "token_endpoint_auth_method": "client_secret_post",
  "app_type": "regular_web",
  "grant_types": [
    "authorization_code",
    "refresh_token"
  ],
  "response_types": [
    "code"
  ],
  "jwt_configuration": {
    "lifetime_in_seconds": 3600,
    "secret_encoded": false,
    "alg": "RS256",
    "scopes": {}
  },
  "sso_disabled": false,
  "cross_origin_auth": false,
  "custom_login_page_on": true,
  "custom_login_page": "<!DOCTYPE html>\n<html>\n<head>\n  <title>EdTech Platform Login</title>\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <link rel=\"stylesheet\" href=\"https://edtech-platform.com/auth/login.css\">\n</head>\n<body>\n  <div id=\"login-container\">\n    <!-- Auth0 Lock will be rendered here -->\n  </div>\n  <script src=\"https://cdn.auth0.com/js/lock/11.33.0/lock.min.js\"></script>\n  <script>\n    var lock = new Auth0Lock(config.clientID, config.auth0Domain, {\n      auth: {\n        redirectUrl: config.callbackURL,\n        responseType: 'code',\n        params: config.internalOptions\n      },\n      theme: {\n        logo: 'https://edtech-platform.com/logo.png',\n        primaryColor: '#007bff'\n      },\n      languageDictionary: {\n        title: 'EdTech Platform'\n      },\n      allowedConnections: ['Username-Password-Authentication', 'google-oauth2'],\n      rememberLastLogin: false,\n      socialButtonStyle: 'big'\n    });\n    lock.show();\n  </script>\n</body>\n</html>"
}
```

#### **Keycloak Realm Configuration**

```json
{
  "realm": "edtech-platform",
  "displayName": "EdTech Platform",
  "displayNameHtml": "<div class=\"kc-logo-text\"><span>EdTech Platform</span></div>",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": false,
  "registrationEmailAsUsername": true,
  "rememberMe": true,
  "verifyEmail": true,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWait": 900,
  "minimumQuickLoginWait": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 30,
  "defaultRoles": ["student"],
  "requiredCredentials": ["password"],
  "passwordPolicy": "length(8) and digits(1) and lowerCase(1) and upperCase(1) and specialChars(1) and notUsername",
  "otpPolicyType": "totp",
  "otpPolicyAlgorithm": "HmacSHA256",
  "otpPolicyInitialCounter": 0,
  "otpPolicyDigits": 6,
  "otpPolicyLookAheadWindow": 1,
  "otpPolicyPeriod": 30,
  "accessTokenLifespan": 900,
  "accessTokenLifespanForImplicitFlow": 900,
  "ssoSessionIdleTimeout": 1800,
  "ssoSessionMaxLifespan": 36000,
  "offlineSessionIdleTimeout": 2592000,
  "offlineSessionMaxLifespanEnabled": false,
  "accessCodeLifespan": 60,
  "accessCodeLifespanUserAction": 300,
  "accessCodeLifespanLogin": 1800,
  "actionTokenGeneratedByAdminLifespan": 43200,
  "actionTokenGeneratedByUserLifespan": 300,
  "smtpServer": {
    "host": "smtp.edtech-platform.com",
    "port": "587",
    "starttls": "true",
    "auth": "true",
    "user": "noreply@edtech-platform.com",
    "password": "smtp-password",
    "from": "EdTech Platform <noreply@edtech-platform.com>",
    "fromDisplayName": "EdTech Platform"
  },
  "internationalizationEnabled": true,
  "supportedLocales": ["en", "es", "fr", "de"],
  "defaultLocale": "en",
  "clients": [
    {
      "clientId": "edtech-web-app",
      "name": "EdTech Web Application",
      "description": "Main web application for students and teachers",
      "enabled": true,
      "clientAuthenticatorType": "client-secret",
      "secret": "web-app-client-secret",
      "redirectUris": [
        "https://app.edtech-platform.com/auth/callback/*"
      ],
      "webOrigins": [
        "https://app.edtech-platform.com"
      ],
      "protocol": "openid-connect",
      "fullScopeAllowed": false,
      "nodeReRegistrationTimeout": -1,
      "protocolMappers": [
        {
          "name": "role list",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-realm-role-mapper",
          "consentRequired": false,
          "config": {
            "multivalued": "true",
            "userinfo.token.claim": "true",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "roles",
            "jsonType.label": "String"
          }
        }
      ]
    }
  ]
}
```

## 🔐 SAML Configuration Templates

### **Service Provider Metadata Template**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor entityID="https://edtech-platform.com/saml/sp"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
                  xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
                  xmlns:shibmd="urn:mace:shibboleth:metadata:1.0"
                  xmlns:xml="http://www.w3.org/XML/1998/namespace"
                  xmlns:mdui="urn:oasis:names:tc:SAML:metadata:ui">

  <Extensions>
    <mdui:UIInfo>
      <mdui:DisplayName xml:lang="en">EdTech Learning Platform</mdui:DisplayName>
      <mdui:Description xml:lang="en">
        Educational technology platform providing personalized learning experiences for K-12 students
      </mdui:Description>
      <mdui:Logo height="64" width="64" xml:lang="en">
        https://edtech-platform.com/assets/logo-64.png
      </mdui:Logo>
      <mdui:InformationURL xml:lang="en">
        https://edtech-platform.com/about
      </mdui:InformationURL>
      <mdui:PrivacyStatementURL xml:lang="en">
        https://edtech-platform.com/privacy
      </mdui:PrivacyStatementURL>
    </mdui:UIInfo>
  </Extensions>

  <SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"
                   AuthnRequestsSigned="true"
                   WantAssertionsSigned="true">

    <!-- Signing Certificate -->
    <KeyDescriptor use="signing">
      <ds:KeyInfo>
        <ds:X509Data>
          <ds:X509Certificate>
            MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3Df...
          </ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </KeyDescriptor>

    <!-- Encryption Certificate -->
    <KeyDescriptor use="encryption">
      <ds:KeyInfo>
        <ds:X509Data>
          <ds:X509Certificate>
            MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3Df...
          </ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </KeyDescriptor>

    <!-- Single Logout Service -->
    <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                         Location="https://edtech-platform.com/saml/sls"/>
    <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                         Location="https://edtech-platform.com/saml/sls"/>

    <!-- NameID Formats -->
    <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</NameIDFormat>
    <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
    <NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress</NameIDFormat>

    <!-- Assertion Consumer Services -->
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                              Location="https://edtech-platform.com/saml/acs"
                              index="1"
                              isDefault="true"/>
    <AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"
                              Location="https://edtech-platform.com/saml/acs"
                              index="2"/>

    <!-- Attribute Consuming Service for Educational Data -->
    <AttributeConsumingService index="1">
      <ServiceName xml:lang="en">EdTech Platform Educational Services</ServiceName>
      <ServiceDescription xml:lang="en">
        Personalized learning platform requiring student and staff information for educational purposes
      </ServiceDescription>

      <!-- Required Attributes -->
      <RequestedAttribute Name="urn:oid:0.9.2342.19200300.100.1.1"
                          FriendlyName="uid"
                          isRequired="true"/>
      <RequestedAttribute Name="urn:oid:0.9.2342.19200300.100.1.3"
                          FriendlyName="mail"
                          isRequired="true"/>
      <RequestedAttribute Name="urn:oid:2.5.4.42"
                          FriendlyName="givenName"
                          isRequired="true"/>
      <RequestedAttribute Name="urn:oid:2.5.4.4"
                          FriendlyName="sn"
                          isRequired="true"/>

      <!-- Educational Role -->
      <RequestedAttribute Name="urn:mace:dir:attribute-def:eduPersonAffiliation"
                          FriendlyName="affiliation"
                          isRequired="true"/>
      <RequestedAttribute Name="urn:mace:dir:attribute-def:eduPersonPrimaryAffiliation"
                          FriendlyName="primaryAffiliation"
                          isRequired="false"/>

      <!-- School-Specific Attributes -->
      <RequestedAttribute Name="urn:school:attribute:gradeLevel"
                          FriendlyName="gradeLevel"
                          isRequired="false"/>
      <RequestedAttribute Name="urn:school:attribute:studentId"
                          FriendlyName="studentId"
                          isRequired="false"/>
      <RequestedAttribute Name="urn:school:attribute:schoolCode"
                          FriendlyName="schoolCode"
                          isRequired="false"/>
      <RequestedAttribute Name="urn:school:attribute:enrolledClasses"
                          FriendlyName="classes"
                          isRequired="false"/>
      <RequestedAttribute Name="urn:school:attribute:teachingAssignments"
                          FriendlyName="teachingAssignments"
                          isRequired="false"/>

    </AttributeConsumingService>

  </SPSSODescriptor>

  <!-- Organization Information -->
  <Organization>
    <OrganizationName xml:lang="en">EdTech Platform Inc.</OrganizationName>
    <OrganizationDisplayName xml:lang="en">EdTech Learning Platform</OrganizationDisplayName>
    <OrganizationURL xml:lang="en">https://edtech-platform.com</OrganizationURL>
  </Organization>

  <!-- Contact Information -->
  <ContactPerson contactType="technical">
    <GivenName>Technical Support</GivenName>
    <EmailAddress>tech-support@edtech-platform.com</EmailAddress>
    <TelephoneNumber>+1-555-123-4567</TelephoneNumber>
  </ContactPerson>

  <ContactPerson contactType="support">
    <GivenName>Customer Support</GivenName>
    <EmailAddress>support@edtech-platform.com</EmailAddress>
    <TelephoneNumber>+1-555-123-4568</TelephoneNumber>
  </ContactPerson>

  <ContactPerson contactType="administrative">
    <GivenName>Privacy Officer</GivenName>
    <EmailAddress>privacy@edtech-platform.com</EmailAddress>
  </ContactPerson>

</EntityDescriptor>
```

### **School District IdP Configuration Template**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor entityID="https://school-district.edu/saml/idp"
                  xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
                  xmlns:ds="http://www.w3.org/2000/09/xmldsig#">

  <IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">

    <!-- Signing Certificate -->
    <KeyDescriptor use="signing">
      <ds:KeyInfo>
        <ds:X509Data>
          <ds:X509Certificate>
            MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3Df...
          </ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </KeyDescriptor>

    <!-- Single Logout Service -->
    <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                         Location="https://school-district.edu/saml/sls"/>

    <!-- NameID Formats -->
    <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</NameIDFormat>
    <NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress</NameIDFormat>

    <!-- Single Sign-On Service -->
    <SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                         Location="https://school-district.edu/saml/sso"/>
    <SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                         Location="https://school-district.edu/saml/sso"/>

    <!-- Supported Attributes -->
    <Attribute Name="urn:oid:0.9.2342.19200300.100.1.1"
               FriendlyName="uid"/>
    <Attribute Name="urn:oid:0.9.2342.19200300.100.1.3"
               FriendlyName="mail"/>
    <Attribute Name="urn:oid:2.5.4.42"
               FriendlyName="givenName"/>
    <Attribute Name="urn:oid:2.5.4.4"
               FriendlyName="sn"/>
    <Attribute Name="urn:mace:dir:attribute-def:eduPersonAffiliation"
               FriendlyName="affiliation"/>
    <Attribute Name="urn:school:attribute:gradeLevel"
               FriendlyName="gradeLevel"/>
    <Attribute Name="urn:school:attribute:studentId"
               FriendlyName="studentId"/>

  </IDPSSODescriptor>

  <!-- Organization Information -->
  <Organization>
    <OrganizationName xml:lang="en">Example School District</OrganizationName>
    <OrganizationDisplayName xml:lang="en">Example School District</OrganizationDisplayName>
    <OrganizationURL xml:lang="en">https://school-district.edu</OrganizationURL>
  </Organization>

  <!-- Contact Information -->
  <ContactPerson contactType="technical">
    <GivenName>IT Administrator</GivenName>
    <EmailAddress>it-admin@school-district.edu</EmailAddress>
  </ContactPerson>

</EntityDescriptor>
```

## 🔑 MFA Implementation Templates

### **TOTP Setup Flow**

```typescript
// Complete TOTP Setup Implementation
import { authenticator } from 'otplib';
import QRCode from 'qrcode';
import crypto from 'crypto';

export class TOTPSetupService {
  async initiateTOTPSetup(userId: string, userEmail: string): Promise<TOTPSetupResult> {
    // Generate secret
    const secret = authenticator.generateSecret();
    
    // Create service name and account name
    const serviceName = 'EdTech Platform';
    const accountName = userEmail;
    
    // Generate OTP Auth URL
    const otpauthUrl = authenticator.keyuri(accountName, serviceName, secret);
    
    // Generate QR code
    const qrCodeDataUrl = await QRCode.toDataURL(otpauthUrl);
    
    // Generate backup codes
    const backupCodes = this.generateBackupCodes();
    
    // Store setup data temporarily (encrypted)
    const setupToken = this.generateSetupToken();
    await this.storeSetupData(setupToken, {
      userId,
      secret: this.encrypt(secret),
      backupCodes: backupCodes.map(code => this.hash(code)),
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes
    });

    return {
      setupToken,
      qrCodeDataUrl,
      manualEntryKey: this.formatSecretForManualEntry(secret),
      backupCodes,
      instructions: {
        qrCode: 'Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
        manualEntry: 'Or enter this key manually in your authenticator app',
        verification: 'Enter the 6-digit code from your app to complete setup',
        backupCodes: 'Save these backup codes in a secure location. Each can only be used once.'
      }
    };
  }

  async completeTOTPSetup(
    setupToken: string, 
    verificationCode: string
  ): Promise<TOTPSetupCompletion> {
    // Retrieve setup data
    const setupData = await this.getSetupData(setupToken);
    if (!setupData || setupData.expiresAt < new Date()) {
      throw new Error('Setup token expired or invalid');
    }

    // Decrypt secret
    const secret = this.decrypt(setupData.secret);
    
    // Verify the code
    const isValid = authenticator.verify({
      token: verificationCode,
      secret: secret,
    });

    if (!isValid) {
      throw new Error('Invalid verification code');
    }

    // Store TOTP configuration permanently
    await this.storeTOTPConfig({
      userId: setupData.userId,
      secret: this.encrypt(secret),
      backupCodes: setupData.backupCodes,
      setupCompletedAt: new Date(),
      isEnabled: true,
    });

    // Clean up temporary setup data
    await this.deleteSetupData(setupToken);

    // Log setup completion
    await this.logMFAEvent({
      userId: setupData.userId,
      event: 'TOTP_SETUP_COMPLETED',
      timestamp: new Date(),
    });

    return {
      success: true,
      backupCodesRemaining: setupData.backupCodes.length,
      recoveryInstructions: this.getRecoveryInstructions(),
    };
  }

  private generateBackupCodes(): string[] {
    const codes = [];
    for (let i = 0; i < 10; i++) {
      // Generate 8-character alphanumeric codes
      codes.push(crypto.randomBytes(4).toString('hex'));
    }
    return codes;
  }

  private formatSecretForManualEntry(secret: string): string {
    // Format secret in groups of 4 characters for easier manual entry
    return secret.match(/.{1,4}/g)?.join(' ') || secret;
  }

  private generateSetupToken(): string {
    return crypto.randomBytes(32).toString('base64url');
  }

  private encrypt(data: string): string {
    const algorithm = 'aes-256-gcm';
    const key = Buffer.from(process.env.MFA_ENCRYPTION_KEY!, 'hex');
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipher(algorithm, key);
    cipher.setAAD(Buffer.from('mfa-setup'));
    
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    const authTag = cipher.getAuthTag();
    
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
  }

  private decrypt(encryptedData: string): string {
    const [ivHex, authTagHex, encrypted] = encryptedData.split(':');
    const algorithm = 'aes-256-gcm';
    const key = Buffer.from(process.env.MFA_ENCRYPTION_KEY!, 'hex');
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    
    const decipher = crypto.createDecipher(algorithm, key);
    decipher.setAAD(Buffer.from('mfa-setup'));
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  private hash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }
}
```

### **SMS MFA Implementation**

```typescript
// SMS MFA Service with Multiple Providers
import { Twilio } from 'twilio';
import AWS from 'aws-sdk';

export class SMSMFAService {
  private twilio: Twilio;
  private sns: AWS.SNS;
  private messagebird: any; // MessageBird client

  constructor() {
    // Initialize SMS providers
    this.twilio = new Twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
    
    this.sns = new AWS.SNS({
      region: process.env.AWS_REGION,
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    });
  }

  async sendMFACode(userId: string, phoneNumber: string): Promise<SMSMFAResult> {
    // Generate 6-digit code
    const code = this.generateMFACode();
    
    // Store code with expiration
    await this.storeMFACode(userId, code, 5 * 60); // 5 minutes
    
    // Determine best SMS provider based on phone number
    const provider = this.selectSMSProvider(phoneNumber);
    
    // Send SMS with fallback
    const sendResult = await this.sendSMSWithFallback(phoneNumber, code, provider);
    
    return {
      success: sendResult.success,
      provider: sendResult.provider,
      messageId: sendResult.messageId,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    };
  }

  private async sendSMSWithFallback(
    phoneNumber: string, 
    code: string, 
    primaryProvider: string
  ): Promise<SMSSendResult> {
    const providers = [primaryProvider, ...this.getFallbackProviders(primaryProvider)];
    
    for (const provider of providers) {
      try {
        const result = await this.sendViaSingleProvider(provider, phoneNumber, code);
        return { ...result, provider };
      } catch (error) {
        console.warn(`SMS provider ${provider} failed:`, error.message);
        continue;
      }
    }
    
    throw new Error('All SMS providers failed');
  }

  private async sendViaSingleProvider(
    provider: string, 
    phoneNumber: string, 
    code: string
  ): Promise<ProviderSendResult> {
    const message = `Your EdTech Platform verification code is: ${code}. This code expires in 5 minutes.`;
    
    switch (provider) {
      case 'twilio':
        const twilioResult = await this.twilio.messages.create({
          body: message,
          from: process.env.TWILIO_PHONE_NUMBER,
          to: phoneNumber,
        });
        return { success: true, messageId: twilioResult.sid };
      
      case 'aws-sns':
        const snsResult = await this.sns.publish({
          Message: message,
          PhoneNumber: phoneNumber,
          MessageAttributes: {
            'AWS.SNS.SMS.SMSType': {
              DataType: 'String',
              StringValue: 'Transactional',
            },
          },
        }).promise();
        return { success: true, messageId: snsResult.MessageId };
      
      default:
        throw new Error(`Unknown SMS provider: ${provider}`);
    }
  }

  private selectSMSProvider(phoneNumber: string): string {
    // Select provider based on phone number country code
    const countryCode = this.extractCountryCode(phoneNumber);
    
    const providerMap: Record<string, string> = {
      '+1': 'twilio',     // US/Canada
      '+44': 'twilio',    // UK
      '+63': 'aws-sns',   // Philippines
      '+61': 'aws-sns',   // Australia
    };
    
    return providerMap[countryCode] || 'twilio';
  }

  private generateMFACode(): string {
    // Generate cryptographically secure 6-digit code
    let code;
    do {
      code = crypto.randomInt(100000, 999999).toString();
    } while (this.isSuspiciousCode(code));
    
    return code;
  }

  private isSuspiciousCode(code: string): boolean {
    // Avoid codes that might be confusing or easy to guess
    const suspiciousPatterns = [
      /^(\d)\1{5}$/, // All same digit (111111)
      /^123456$/,    // Sequential
      /^654321$/,    // Reverse sequential
      /^000000$/,    // All zeros
    ];
    
    return suspiciousPatterns.some(pattern => pattern.test(code));
  }

  async verifyMFACode(userId: string, providedCode: string): Promise<boolean> {
    const storedCodeData = await this.getMFACode(userId);
    if (!storedCodeData) {
      return false;
    }

    // Check if code has expired
    if (Date.now() > storedCodeData.expiresAt) {
      await this.deleteMFACode(userId);
      return false;
    }

    // Verify code
    const isValid = storedCodeData.code === providedCode.trim();
    
    if (isValid) {
      // Code is valid, remove it (single use)
      await this.deleteMFACode(userId);
      
      // Log successful verification
      await this.logMFAEvent({
        userId,
        event: 'SMS_MFA_SUCCESS',
        timestamp: new Date(),
      });
    } else {
      // Increment failed attempts
      await this.incrementFailedAttempts(userId);
      
      // Log failed verification
      await this.logMFAEvent({
        userId,
        event: 'SMS_MFA_FAILURE',
        timestamp: new Date(),
      });
    }

    return isValid;
  }
}
```

## 📊 Monitoring & Analytics Templates

### **Security Metrics Dashboard Configuration**

```typescript
// Grafana Dashboard Configuration for IAM Metrics
export const iamDashboardConfig = {
  dashboard: {
    id: null,
    title: "EdTech IAM Security Dashboard",
    tags: ["security", "iam", "authentication"],
    timezone: "browser",
    panels: [
      {
        id: 1,
        title: "Authentication Success Rate",
        type: "stat",
        targets: [
          {
            expr: "sum(rate(auth_attempts_total[5m])) by (status)",
            legendFormat: "{{status}}",
          }
        ],
        fieldConfig: {
          defaults: {
            color: {
              mode: "thresholds"
            },
            thresholds: {
              steps: [
                { color: "red", value: 0 },
                { color: "yellow", value: 0.95 },
                { color: "green", value: 0.98 }
              ]
            },
            unit: "percentunit"
          }
        }
      },
      {
        id: 2,
        title: "MFA Adoption Rate by User Type",
        type: "piechart",
        targets: [
          {
            expr: "sum by (user_type) (mfa_enabled_users) / sum by (user_type) (total_users)",
            legendFormat: "{{user_type}}",
          }
        ]
      },
      {
        id: 3,
        title: "Failed Login Attempts",
        type: "graph",
        targets: [
          {
            expr: "sum(rate(failed_login_attempts_total[5m])) by (failure_reason)",
            legendFormat: "{{failure_reason}}",
          }
        ],
        alert: {
          conditions: [
            {
              query: { params: ["A", "5m", "now"] },
              reducer: { params: [], type: "last" },
              evaluator: { params: [10], type: "gt" }
            }
          ],
          executionErrorState: "alerting",
          frequency: "1m",
          handler: 1,
          name: "High Failed Login Rate",
          noDataState: "no_data",
          notifications: []
        }
      },
      {
        id: 4,
        title: "OAuth2 Token Metrics",
        type: "table",
        targets: [
          {
            expr: "oauth2_tokens_issued_total",
            format: "table",
            instant: true
          }
        ],
        transformations: [
          {
            id: "organize",
            options: {
              excludeByName: {},
              indexByName: {},
              renameByName: {
                "client_id": "Client ID",
                "grant_type": "Grant Type",
                "Value": "Tokens Issued"
              }
            }
          }
        ]
      },
      {
        id: 5,
        title: "SAML Authentication Latency",
        type: "graph",
        targets: [
          {
            expr: "histogram_quantile(0.95, saml_auth_duration_seconds_bucket)",
            legendFormat: "95th percentile",
          },
          {
            expr: "histogram_quantile(0.50, saml_auth_duration_seconds_bucket)",
            legendFormat: "50th percentile",
          }
        ],
        yAxes: [
          {
            label: "Seconds",
            max: null,
            min: 0
          }
        ]
      },
      {
        id: 6,
        title: "Compliance Violations",
        type: "logs",
        targets: [
          {
            expr: '{job="edtech-platform"} |= "COMPLIANCE_VIOLATION"',
          }
        ],
        options: {
          showLabels: true,
          showTime: true,
          sortOrder: "Descending",
          wrapLogMessage: true
        }
      }
    ],
    time: {
      from: "now-1h",
      to: "now"
    },
    refresh: "30s"
  }
};

// Prometheus Metrics Collection
export const prometheusMetrics = `
# HELP auth_attempts_total Total number of authentication attempts
# TYPE auth_attempts_total counter
auth_attempts_total{method="oauth2",status="success"} 1524
auth_attempts_total{method="oauth2",status="failure"} 23
auth_attempts_total{method="saml",status="success"} 856
auth_attempts_total{method="saml",status="failure"} 12

# HELP mfa_challenges_total Total number of MFA challenges issued
# TYPE mfa_challenges_total counter
mfa_challenges_total{method="totp",status="success"} 892
mfa_challenges_total{method="totp",status="failure"} 45
mfa_challenges_total{method="sms",status="success"} 234
mfa_challenges_total{method="sms",status="failure"} 8

# HELP oauth2_tokens_issued_total Total OAuth2 tokens issued
# TYPE oauth2_tokens_issued_total counter
oauth2_tokens_issued_total{client_id="web-app",grant_type="authorization_code"} 1245
oauth2_tokens_issued_total{client_id="mobile-app",grant_type="authorization_code"} 856

# HELP saml_auth_duration_seconds Time spent processing SAML authentication
# TYPE saml_auth_duration_seconds histogram
saml_auth_duration_seconds_bucket{le="0.1"} 234
saml_auth_duration_seconds_bucket{le="0.25"} 567
saml_auth_duration_seconds_bucket{le="0.5"} 789
saml_auth_duration_seconds_bucket{le="1.0"} 834
saml_auth_duration_seconds_bucket{le="2.5"} 856
saml_auth_duration_seconds_bucket{le="+Inf"} 856

# HELP compliance_checks_total Total compliance validation checks
# TYPE compliance_checks_total counter
compliance_checks_total{framework="ferpa",status="pass"} 1234
compliance_checks_total{framework="ferpa",status="fail"} 5
compliance_checks_total{framework="coppa",status="pass"} 567
compliance_checks_total{framework="coppa",status="fail"} 2
`;
```

### **Alert Configuration Templates**

```yaml
# Alertmanager Configuration for IAM Security
groups:
  - name: iam-security-alerts
    rules:
      - alert: HighFailedLoginRate
        expr: sum(rate(failed_login_attempts_total[5m])) > 10
        for: 2m
        labels:
          severity: warning
          service: authentication
        annotations:
          summary: "High failed login attempt rate detected"
          description: "Failed login rate is {{ $value }} per second, which exceeds the threshold of 10/sec"
          runbook_url: "https://docs.edtech-platform.com/runbooks/high-failed-logins"

      - alert: MFABypassAttempt
        expr: increase(mfa_bypass_attempts_total[1h]) > 0
        for: 0m
        labels:
          severity: critical
          service: mfa
        annotations:
          summary: "MFA bypass attempt detected"
          description: "{{ $value }} MFA bypass attempts detected in the last hour"
          runbook_url: "https://docs.edtech-platform.com/runbooks/mfa-bypass"

      - alert: ComplianceViolation
        expr: increase(compliance_violations_total[1h]) > 0
        for: 0m
        labels:
          severity: critical
          service: compliance
        annotations:
          summary: "Compliance violation detected"
          description: "{{ $value }} compliance violations in the last hour: {{ $labels.framework }}"
          runbook_url: "https://docs.edtech-platform.com/runbooks/compliance-violation"

      - alert: SAMLAuthenticationDown
        expr: up{job="saml-service"} == 0
        for: 1m
        labels:
          severity: critical
          service: saml
        annotations:
          summary: "SAML authentication service is down"
          description: "SAML service has been down for more than 1 minute"
          runbook_url: "https://docs.edtech-platform.com/runbooks/saml-down"

      - alert: TokenExpirationIssues
        expr: sum(rate(token_refresh_failures_total[5m])) > 5
        for: 2m
        labels:
          severity: warning
          service: oauth2
        annotations:
          summary: "High token refresh failure rate"
          description: "Token refresh failure rate is {{ $value }} per second"
          runbook_url: "https://docs.edtech-platform.com/runbooks/token-issues"

      - alert: UnauthorizedDataAccess
        expr: sum(rate(unauthorized_data_access_total[1m])) > 0
        for: 0m
        labels:
          severity: critical
          service: authorization
        annotations:
          summary: "Unauthorized data access attempt"
          description: "{{ $value }} unauthorized data access attempts detected"
          runbook_url: "https://docs.edtech-platform.com/runbooks/unauthorized-access"

  - name: iam-performance-alerts
    rules:
      - alert: HighAuthenticationLatency
        expr: histogram_quantile(0.95, rate(auth_duration_seconds_bucket[5m])) > 3
        for: 5m
        labels:
          severity: warning
          service: authentication
        annotations:
          summary: "High authentication latency"
          description: "95th percentile authentication latency is {{ $value }}s"

      - alert: DatabaseConnectionIssues
        expr: sum(rate(database_connection_errors_total[1m])) > 1
        for: 1m
        labels:
          severity: critical
          service: database
        annotations:
          summary: "Database connection issues"
          description: "Database connection error rate: {{ $value }} per second"

# Notification Configuration
route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
    - match:
        service: compliance
      receiver: 'compliance-team'

receivers:
  - name: 'default-receiver'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#platform-alerts'
        title: 'EdTech Platform Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#critical-alerts'
        title: 'CRITICAL: EdTech Platform Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}'
    email_configs:
      - to: 'security-team@edtech-platform.com'
        from: 'alerts@edtech-platform.com'
        subject: 'CRITICAL: EdTech Security Alert'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Runbook: {{ .Annotations.runbook_url }}
          {{ end }}

  - name: 'compliance-team'
    email_configs:
      - to: 'compliance@edtech-platform.com'
        from: 'alerts@edtech-platform.com'
        subject: 'Compliance Violation Alert'
        body: |
          {{ range .Alerts }}
          Compliance Framework: {{ .Labels.framework }}
          Violation: {{ .Annotations.description }}
          {{ end }}
```

## 🧪 Testing Configuration Templates

### **Jest Test Configuration**

```javascript
// jest.config.js - Security-focused testing configuration
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: [
    '**/__tests__/**/*.ts',
    '**/?(*.)+(spec|test).ts'
  ],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.interface.ts',
    '!src/types/**/*',
  ],
  coverageReporters: [
    'text',
    'lcov',
    'html',
    'cobertura'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    // Higher coverage requirements for security modules
    './src/auth/': {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    },
    './src/security/': {
      branches: 95,
      functions: 95,
      lines: 95,
      statements: 95
    }
  },
  setupFilesAfterEnv: [
    '<rootDir>/tests/setup.ts'
  ],
  testTimeout: 30000,
  maxWorkers: 1, // Run security tests sequentially for consistency
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/coverage/'
  ],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1'
  },
  globalSetup: '<rootDir>/tests/global-setup.ts',
  globalTeardown: '<rootDir>/tests/global-teardown.ts',
};
```

### **Cypress E2E Test Configuration**

```typescript
// cypress.config.ts - End-to-end authentication testing
import { defineConfig } from 'cypress';

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    supportFile: 'cypress/support/e2e.ts',
    specPattern: 'cypress/e2e/**/*.cy.ts',
    videosFolder: 'cypress/videos',
    screenshotsFolder: 'cypress/screenshots',
    video: false,
    screenshotOnRunFailure: true,
    
    // Security-focused test configuration
    chromeWebSecurity: false, // For testing cross-origin scenarios
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    
    env: {
      // Test environment variables
      TEST_USER_STUDENT: 'student@test.edu',
      TEST_USER_TEACHER: 'teacher@test.edu',
      TEST_USER_ADMIN: 'admin@test.edu',
      TEST_PASSWORD: 'TestPassword123!',
      
      // OAuth2 test configuration
      OAUTH2_CLIENT_ID: 'test-client-id',
      OAUTH2_REDIRECT_URI: 'http://localhost:3000/auth/callback',
      
      // SAML test configuration
      SAML_IDP_URL: 'http://localhost:8080/saml/idp',
      SAML_SP_URL: 'http://localhost:3000/saml/sp',
      
      // MFA test configuration
      TOTP_SECRET: 'test-totp-secret',
      SMS_TEST_NUMBER: '+1234567890',
    },
    
    setupNodeEvents(on, config) {
      // Custom tasks for security testing
      on('task', {
        // Generate TOTP code for testing
        generateTOTPCode(secret: string) {
          const authenticator = require('otplib').authenticator;
          return authenticator.generate(secret);
        },
        
        // Clear test data
        clearTestData() {
          // Implementation to clear test user data
          return null;
        },
        
        // Setup test SAML response
        setupSAMLResponse(config: any) {
          // Implementation to setup SAML test response
          return null;
        },
      });
      
      return config;
    },
  },
  
  component: {
    devServer: {
      framework: 'next',
      bundler: 'webpack',
    },
    specPattern: 'src/**/*.cy.ts',
  },
});

// cypress/support/commands.ts - Custom commands for auth testing
declare global {
  namespace Cypress {
    interface Chainable {
      loginAsStudent(): Chainable<void>;
      loginAsTeacher(): Chainable<void>;
      loginAsAdmin(): Chainable<void>;
      loginWithMFA(userType: string, mfaMethod: string): Chainable<void>;
      testOAuth2Flow(): Chainable<void>;
      testSAMLFlow(): Chainable<void>;
      setupMFA(method: string): Chainable<void>;
      verifyMFA(code: string): Chainable<void>;
    }
  }
}

// Login command implementations
Cypress.Commands.add('loginAsStudent', () => {
  cy.visit('/login');
  cy.get('[data-cy=email-input]').type(Cypress.env('TEST_USER_STUDENT'));
  cy.get('[data-cy=password-input]').type(Cypress.env('TEST_PASSWORD'));
  cy.get('[data-cy=login-button]').click();
  cy.url().should('include', '/student/dashboard');
});

Cypress.Commands.add('loginWithMFA', (userType: string, mfaMethod: string) => {
  // Regular login first
  cy.visit('/login');
  cy.get('[data-cy=email-input]').type(Cypress.env(`TEST_USER_${userType.toUpperCase()}`));
  cy.get('[data-cy=password-input]').type(Cypress.env('TEST_PASSWORD'));
  cy.get('[data-cy=login-button]').click();
  
  // Handle MFA challenge
  cy.get('[data-cy=mfa-challenge]').should('be.visible');
  
  if (mfaMethod === 'totp') {
    cy.task('generateTOTPCode', Cypress.env('TOTP_SECRET')).then((code) => {
      cy.get('[data-cy=mfa-code-input]').type(code as string);
      cy.get('[data-cy=mfa-verify-button]').click();
    });
  } else if (mfaMethod === 'sms') {
    // For testing, use a predefined test code
    cy.get('[data-cy=mfa-code-input]').type('123456');
    cy.get('[data-cy=mfa-verify-button]').click();
  }
  
  cy.url().should('include', `/${userType}/dashboard`);
});

Cypress.Commands.add('testOAuth2Flow', () => {
  // Test OAuth2 authorization code flow
  cy.visit('/oauth2/authorize?client_id=' + Cypress.env('OAUTH2_CLIENT_ID') + 
           '&redirect_uri=' + encodeURIComponent(Cypress.env('OAUTH2_REDIRECT_URI')) +
           '&response_type=code&scope=read:profile&state=test-state');
  
  // Should redirect to login if not authenticated
  cy.url().should('include', '/login');
  
  // Login
  cy.get('[data-cy=email-input]').type(Cypress.env('TEST_USER_STUDENT'));
  cy.get('[data-cy=password-input]').type(Cypress.env('TEST_PASSWORD'));
  cy.get('[data-cy=login-button]').click();
  
  // Should show consent screen
  cy.get('[data-cy=oauth2-consent]').should('be.visible');
  cy.get('[data-cy=oauth2-allow-button]').click();
  
  // Should redirect back with authorization code
  cy.url().should('include', '/auth/callback');
  cy.url().should('include', 'code=');
  cy.url().should('include', 'state=test-state');
});
```

---

### Navigation
**Previous**: [Testing Strategies](./testing-strategies.md) | **Next**: [Main README](./README.md)

---

*Template Examples & Working Configurations | July 2025*