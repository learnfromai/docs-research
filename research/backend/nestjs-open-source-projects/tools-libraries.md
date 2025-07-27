# Tools & Libraries

## 🛠️ Overview

Comprehensive analysis of tools, libraries, and packages used across NestJS open source projects. This document categorizes popular choices and provides usage statistics based on the analyzed projects.

## 📦 Core Framework Dependencies

### **NestJS Core Packages** (100% adoption)
```json
{
  "@nestjs/common": "^10.0.0",
  "@nestjs/core": "^10.0.0",
  "@nestjs/platform-express": "^10.0.0"
}
```

### **Popular NestJS Modules**
| Package | Adoption | Purpose |
|---------|----------|---------|
| `@nestjs/config` | 95% | Configuration management |
| `@nestjs/typeorm` | 45% | TypeORM integration |
| `@nestjs/passport` | 90% | Authentication strategies |
| `@nestjs/jwt` | 90% | JWT token handling |
| `@nestjs/swagger` | 80% | API documentation |
| `@nestjs/mongoose` | 20% | MongoDB integration |
| `@nestjs/cqrs` | 15% | CQRS pattern implementation |

## 🗄️ Database & ORM

### **TypeORM Stack** (45% adoption)
```json
{
  "typeorm": "^0.3.17",
  "@nestjs/typeorm": "^10.0.0",
  "pg": "^8.11.0",
  "@types/pg": "^8.6.6"
}
```

**Common TypeORM Entities:**
```typescript
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column()
  @Exclude({ toPlainOnly: true })
  password: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @ManyToMany(() => Role)
  @JoinTable()
  roles: Role[];
}
```

### **Prisma Stack** (35% adoption)
```json
{
  "prisma": "^5.0.0",
  "@prisma/client": "^5.0.0"
}
```

**Prisma Schema Example:**
```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  profile   Profile?
  posts     Post[]
  
  @@map("users")
}
```

### **Mongoose Stack** (20% adoption)
```json
{
  "mongoose": "^7.5.0",
  "@nestjs/mongoose": "^10.0.0"
}
```

## 🔐 Authentication & Security

### **Authentication Libraries**
```json
{
  "passport": "^0.6.0",
  "passport-jwt": "^4.0.1",
  "passport-local": "^1.0.0",
  "passport-google-oauth20": "^2.0.0",
  "passport-facebook": "^3.0.0",
  "@nestjs/passport": "^10.0.0",
  "@nestjs/jwt": "^10.1.0"
}
```

### **Password & Encryption**
```json
{
  "bcrypt": "^5.1.0",
  "@types/bcrypt": "^5.0.0",
  "crypto": "built-in"
}
```

**Common Usage:**
```typescript
// Password hashing service
@Injectable()
export class CryptoService {
  private readonly saltRounds = 12;

  async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, this.saltRounds);
  }

  async comparePassword(password: string, hash: string): Promise<boolean> {
    return bcrypt.compare(password, hash);
  }
}
```

## ✅ Validation & Transformation

### **Class Validator Stack** (95% adoption)
```json
{
  "class-validator": "^0.14.0",
  "class-transformer": "^0.5.1"
}
```

**Common DTOs:**
```typescript
export class CreateUserDto {
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(50)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
  password: string;

  @IsString()
  @Transform(({ value }) => value?.trim())
  @Length(2, 50)
  firstName: string;
}
```

### **Alternative Validation** (20% adoption)
```json
{
  "joi": "^17.9.0",
  "zod": "^3.22.0"
}
```

## 🧪 Testing

### **Jest Testing Stack** (95% adoption)
```json
{
  "jest": "^29.6.0",
  "@types/jest": "^29.5.0",
  "supertest": "^6.3.0",
  "@types/supertest": "^2.0.12"
}
```

**Test Configuration:**
```json
{
  "testEnvironment": "node",
  "testRegex": ".*\\.spec\\.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  },
  "collectCoverageFrom": [
    "src/**/*.(t|j)s"
  ],
  "coverageDirectory": "../coverage",
  "testPathIgnorePatterns": [
    "/node_modules/",
    "/dist/"
  ]
}
```

### **E2E Testing Utilities**
```typescript
// Test utilities
export class TestUtils {
  static async createTestingModule(imports: any[] = []): Promise<TestingModule> {
    return Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true }),
        TypeOrmModule.forRoot(testDbConfig),
        ...imports,
      ],
    }).compile();
  }

  static async clearDatabase(app: INestApplication): Promise<void> {
    const dataSource = app.get(DataSource);
    const entities = dataSource.entityMetadatas;
    
    for (const entity of entities) {
      const repository = dataSource.getRepository(entity.name);
      await repository.clear();
    }
  }
}
```

## 📚 Documentation

### **Swagger/OpenAPI** (80% adoption)
```json
{
  "@nestjs/swagger": "^7.1.0",
  "swagger-ui-express": "^5.0.0"
}
```

**Swagger Configuration:**
```typescript
// main.ts
const config = new DocumentBuilder()
  .setTitle('API Documentation')
  .setDescription('The API description')
  .setVersion('1.0')
  .addBearerAuth(
    {
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'JWT',
    },
    'access-token',
  )
  .build();

const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('docs', app, document);
```

**API Decorators:**
```typescript
@ApiTags('users')
@Controller('users')
export class UsersController {
  @ApiOperation({ summary: 'Create user' })
  @ApiResponse({ status: 201, description: 'User created', type: UserDto })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiBearerAuth('access-token')
  @Post()
  async create(@Body() createUserDto: CreateUserDto): Promise<UserDto> {
    return this.usersService.create(createUserDto);
  }
}
```

## 🗂️ Configuration Management

### **NestJS Config** (95% adoption)
```json
{
  "@nestjs/config": "^3.0.0",
  "joi": "^17.9.0"
}
```

**Configuration Structure:**
```typescript
// config/app.config.ts
export default registerAs('app', () => ({
  environment: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  apiPrefix: process.env.API_PREFIX || 'api',
}));

// config/database.config.ts
export default registerAs('database', () => ({
  type: process.env.DATABASE_TYPE || 'postgres',
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT, 10) || 5432,
  username: process.env.DATABASE_USERNAME,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
}));
```

### **Environment Validation**
```typescript
export const configValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').required(),
  PORT: Joi.number().default(3000),
  DATABASE_HOST: Joi.string().required(),
  DATABASE_PORT: Joi.number().default(5432),
  DATABASE_USERNAME: Joi.string().required(),
  DATABASE_PASSWORD: Joi.string().required(),
  JWT_SECRET: Joi.string().required(),
});
```

## 📧 Email & Communication

### **NodeMailer Stack** (70% adoption)
```json
{
  "nodemailer": "^6.9.0",
  "@types/nodemailer": "^6.4.0",
  "handlebars": "^4.7.0"
}
```

**Email Service:**
```typescript
@Injectable()
export class MailService {
  private transporter: nodemailer.Transporter;

  constructor(private configService: ConfigService) {
    this.transporter = nodemailer.createTransporter({
      host: this.configService.get('SMTP_HOST'),
      port: this.configService.get('SMTP_PORT'),
      secure: false,
      auth: {
        user: this.configService.get('SMTP_USER'),
        pass: this.configService.get('SMTP_PASS'),
      },
    });
  }

  async sendEmail(to: string, subject: string, template: string, context: any) {
    const html = this.compileTemplate(template, context);
    
    await this.transporter.sendMail({
      from: this.configService.get('SMTP_FROM'),
      to,
      subject,
      html,
    });
  }
}
```

## 🗄️ Caching & Performance

### **Redis Stack** (60% adoption)
```json
{
  "redis": "^4.6.0",
  "@types/redis": "^4.0.0",
  "ioredis": "^5.3.0"
}
```

**Redis Configuration:**
```typescript
@Module({
  providers: [
    {
      provide: 'REDIS_CLIENT',
      useFactory: (configService: ConfigService) => {
        return new Redis({
          host: configService.get('REDIS_HOST'),
          port: configService.get('REDIS_PORT'),
          password: configService.get('REDIS_PASSWORD'),
        });
      },
      inject: [ConfigService],
    },
  ],
  exports: ['REDIS_CLIENT'],
})
export class RedisModule {}
```

### **Caching Interceptor**
```typescript
@Injectable()
export class CacheInterceptor implements NestInterceptor {
  constructor(@Inject('REDIS_CLIENT') private redis: Redis) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<any>> {
    const request = context.switchToHttp().getRequest();
    const cacheKey = `cache:${request.url}`;
    
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return of(JSON.parse(cached));
    }

    return next.handle().pipe(
      tap(async (response) => {
        await this.redis.setex(cacheKey, 300, JSON.stringify(response));
      }),
    );
  }
}
```

## 📁 File Upload & Storage

### **File Upload Stack** (50% adoption)
```json
{
  "multer": "^1.4.5-lts.1",
  "@types/multer": "^1.4.7",
  "aws-sdk": "^2.1450.0",
  "sharp": "^0.32.0"
}
```

**File Upload Service:**
```typescript
@Injectable()
export class FileUploadService {
  constructor(private configService: ConfigService) {}

  async uploadToS3(file: Express.Multer.File): Promise<string> {
    const s3 = new AWS.S3({
      accessKeyId: this.configService.get('AWS_ACCESS_KEY_ID'),
      secretAccessKey: this.configService.get('AWS_SECRET_ACCESS_KEY'),
      region: this.configService.get('AWS_REGION'),
    });

    const params = {
      Bucket: this.configService.get('AWS_S3_BUCKET'),
      Key: `uploads/${Date.now()}-${file.originalname}`,
      Body: file.buffer,
      ContentType: file.mimetype,
    };

    const result = await s3.upload(params).promise();
    return result.Location;
  }
}
```

## 🌍 Internationalization

### **I18N Stack** (40% adoption)
```json
{
  "nestjs-i18n": "^10.4.0",
  "accept-language": "^3.0.18"
}
```

**I18N Configuration:**
```typescript
I18nModule.forRoot({
  fallbackLanguage: 'en',
  loaderOptions: {
    path: path.join(__dirname, '/i18n/'),
    watch: true,
  },
  resolvers: [
    { use: QueryResolver, options: ['lang'] },
    AcceptLanguageResolver,
    new HeaderResolver(['x-lang']),
  ],
})
```

## 🐳 DevOps & Deployment

### **Docker** (85% adoption)
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

USER node

CMD ["node", "dist/main"]
```

### **Docker Compose** (70% adoption)
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    depends_on:
      - db
      - redis

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## 🔍 Logging & Monitoring

### **Logging Stack** (80% adoption)
```json
{
  "winston": "^3.10.0",
  "nest-winston": "^1.9.0",
  "pino": "^8.15.0",
  "nestjs-pino": "^3.5.0"
}
```

**Winston Logger:**
```typescript
const logger = WinstonModule.createLogger({
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.ms(),
        nestWinstonModuleUtilities.format.nestLike('MyApp', {
          colors: true,
          prettyPrint: true,
        }),
      ),
    }),
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
    }),
  ],
});
```

## 📊 Popular Package Combinations

### **Starter Boilerplate Stack**
```json
{
  "@nestjs/common": "^10.0.0",
  "@nestjs/config": "^3.0.0",
  "@nestjs/typeorm": "^10.0.0",
  "@nestjs/passport": "^10.0.0",
  "@nestjs/jwt": "^10.1.0",
  "@nestjs/swagger": "^7.1.0",
  "typeorm": "^0.3.17",
  "pg": "^8.11.0",
  "bcrypt": "^5.1.0",
  "class-validator": "^0.14.0",
  "class-transformer": "^0.5.1"
}
```

### **Enterprise Stack**
```json
{
  "@nestjs/microservices": "^10.0.0",
  "@nestjs/cqrs": "^10.0.0",
  "redis": "^4.6.0",
  "winston": "^3.10.0",
  "helmet": "^7.0.0",
  "compression": "^1.7.4",
  "@nestjs/terminus": "^10.0.0"
}
```

### **Testing Stack**
```json
{
  "jest": "^29.6.0",
  "supertest": "^6.3.0",
  "@nestjs/testing": "^10.0.0",
  "faker": "^8.0.0",
  "testcontainers": "^10.0.0"
}
```

---

**Navigation**
- ↑ Back to: [Architecture Patterns](./architecture-patterns.md)
- ↓ Next: [Best Practices](./best-practices.md)