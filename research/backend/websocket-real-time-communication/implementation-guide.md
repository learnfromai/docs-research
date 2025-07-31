# Implementation Guide: WebSocket Real-Time Communication

## 🚀 Quick Start Implementation

### Prerequisites

```bash
# Required software versions
Node.js >= 18.0.0
Redis >= 6.0.0
PostgreSQL >= 14.0
Docker >= 20.10 (optional but recommended)
```

### Basic Setup Steps

#### 1. Project Initialization

```bash
# Create new project
mkdir edtech-realtime-platform
cd edtech-realtime-platform

# Initialize Node.js project
npm init -y

# Install core dependencies
npm install express socket.io redis ioredis jsonwebtoken
npm install cors helmet express-rate-limit joi
npm install pg @types/pg uuid

# Install development dependencies
npm install -D @types/node @types/express typescript
npm install -D ts-node nodemon jest @types/jest
npm install -D eslint prettier @typescript-eslint/parser
```

#### 2. Basic Server Setup

```typescript
// src/server.ts
import express from 'express';
import { createServer } from 'http';
import { Server as SocketServer } from 'socket.io';
import Redis from 'ioredis';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

const app = express();
const server = createServer(app);
const io = new SocketServer(server, {
  cors: {
    origin: process.env.CLIENT_URL || "http://localhost:3000",
    methods: ["GET", "POST"]
  },
  pingTimeout: 60000,
  pingInterval: 25000
});

// Redis setup for session storage and pub/sub
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  retryDelayOnFailover: 100,
  enableReadyCheck: false,
  lazyConnect: true
});

// Middleware setup
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use('/api/', limiter);

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

#### 3. Authentication Middleware

```typescript
// src/middleware/auth.ts
import jwt from 'jsonwebtoken';
import { Socket } from 'socket.io';
import { redis } from '../server';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  username?: string;
  role?: string;
}

export const authenticateSocket = async (
  socket: AuthenticatedSocket, 
  next: (err?: Error) => void
) => {
  try {
    const token = socket.handshake.auth.token;
    
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    
    // Check if token is blacklisted in Redis
    const isBlacklisted = await redis.get(`blacklist:${token}`);
    if (isBlacklisted) {
      return next(new Error('Token has been revoked'));
    }

    // Attach user info to socket
    socket.userId = decoded.userId;
    socket.username = decoded.username;
    socket.role = decoded.role;

    next();
  } catch (error) {
    next(new Error('Invalid authentication token'));
  }
};

// Rate limiting for WebSocket connections
const connectionCounts = new Map<string, number>();

export const rateLimitConnection = (
  socket: AuthenticatedSocket,
  next: (err?: Error) => void
) => {
  const clientIP = socket.handshake.address;
  const currentCount = connectionCounts.get(clientIP) || 0;
  
  if (currentCount >= 10) { // Max 10 connections per IP
    return next(new Error('Connection limit exceeded'));
  }
  
  connectionCounts.set(clientIP, currentCount + 1);
  
  socket.on('disconnect', () => {
    const count = connectionCounts.get(clientIP) || 0;
    if (count > 1) {
      connectionCounts.set(clientIP, count - 1);
    } else {
      connectionCounts.delete(clientIP);
    }
  });
  
  next();
};
```

## 🎓 Educational Platform Implementations

### Live Quiz System

```typescript
// src/services/QuizService.ts
import { Server as SocketServer } from 'socket.io';
import { redis } from '../server';

interface Question {
  id: string;
  question: string;
  options: string[];
  correctAnswer: number;
  timeLimit: number;
}

interface QuizSession {
  id: string;
  questions: Question[];
  currentQuestionIndex: number;
  participants: Map<string, ParticipantData>;
  startTime: Date;
  status: 'waiting' | 'active' | 'finished';
}

interface ParticipantData {
  userId: string;
  username: string;
  score: number;
  answers: { questionId: string; answer: number; timestamp: Date }[];
}

export class QuizService {
  private quizSessions = new Map<string, QuizSession>();
  private questionTimers = new Map<string, NodeJS.Timeout>();

  constructor(private io: SocketServer) {
    this.setupQuizHandlers();
  }

  private setupQuizHandlers() {
    this.io.on('connection', (socket) => {
      // Join quiz session
      socket.on('quiz:join', async (data: { sessionId: string }) => {
        const { sessionId } = data;
        const session = this.quizSessions.get(sessionId);
        
        if (!session) {
          socket.emit('quiz:error', { message: 'Quiz session not found' });
          return;
        }

        if (session.status !== 'waiting') {
          socket.emit('quiz:error', { message: 'Quiz already started' });
          return;
        }

        // Add participant to session
        session.participants.set(socket.userId!, {
          userId: socket.userId!,
          username: socket.username!,
          score: 0,
          answers: []
        });

        // Join socket room
        await socket.join(`quiz:${sessionId}`);
        
        // Broadcast participant count update
        this.io.to(`quiz:${sessionId}`).emit('quiz:participants', {
          count: session.participants.size,
          participants: Array.from(session.participants.values())
            .map(p => ({ username: p.username, score: p.score }))
        });
      });

      // Submit answer
      socket.on('quiz:answer', async (data: { sessionId: string; answer: number }) => {
        const { sessionId, answer } = data;
        const session = this.quizSessions.get(sessionId);
        
        if (!session || session.status !== 'active') {
          socket.emit('quiz:error', { message: 'Invalid quiz session' });
          return;
        }

        const participant = session.participants.get(socket.userId!);
        if (!participant) {
          socket.emit('quiz:error', { message: 'Not a participant' });
          return;
        }

        const currentQuestion = session.questions[session.currentQuestionIndex];
        
        // Check if already answered this question
        const existingAnswer = participant.answers.find(
          a => a.questionId === currentQuestion.id
        );
        
        if (existingAnswer) {
          socket.emit('quiz:error', { message: 'Already answered this question' });
          return;
        }

        // Record answer
        participant.answers.push({
          questionId: currentQuestion.id,
          answer,
          timestamp: new Date()
        });

        // Calculate score if correct
        if (answer === currentQuestion.correctAnswer) {
          const timeBonus = this.calculateTimeBonus(
            session.startTime,
            new Date(),
            currentQuestion.timeLimit
          );
          participant.score += 100 + timeBonus;
        }

        // Acknowledge answer received
        socket.emit('quiz:answer:acknowledged');

        // Update leaderboard
        this.broadcastLeaderboard(sessionId);
      });

      // Start quiz (instructor only)
      socket.on('quiz:start', async (data: { sessionId: string }) => {
        const { sessionId } = data;
        const session = this.quizSessions.get(sessionId);
        
        if (!session || socket.role !== 'instructor') {
          socket.emit('quiz:error', { message: 'Unauthorized or invalid session' });
          return;
        }

        session.status = 'active';
        session.startTime = new Date();
        session.currentQuestionIndex = 0;

        this.startQuestion(sessionId);
      });
    });
  }

  private async startQuestion(sessionId: string) {
    const session = this.quizSessions.get(sessionId);
    if (!session) return;

    const question = session.questions[session.currentQuestionIndex];
    
    // Broadcast question to all participants
    this.io.to(`quiz:${sessionId}`).emit('quiz:question', {
      questionNumber: session.currentQuestionIndex + 1,
      totalQuestions: session.questions.length,
      question: question.question,
      options: question.options,
      timeLimit: question.timeLimit
    });

    // Set timer for question
    const timer = setTimeout(() => {
      this.endQuestion(sessionId);
    }, question.timeLimit * 1000);

    this.questionTimers.set(sessionId, timer);
  }

  private async endQuestion(sessionId: string) {
    const session = this.quizSessions.get(sessionId);
    if (!session) return;

    const currentQuestion = session.questions[session.currentQuestionIndex];
    
    // Clear timer
    const timer = this.questionTimers.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this.questionTimers.delete(sessionId);
    }

    // Broadcast correct answer and explanations
    this.io.to(`quiz:${sessionId}`).emit('quiz:question:results', {
      correctAnswer: currentQuestion.correctAnswer,
      explanation: (currentQuestion as any).explanation,
      statistics: this.calculateQuestionStats(sessionId, currentQuestion.id)
    });

    // Move to next question or end quiz
    session.currentQuestionIndex++;
    
    if (session.currentQuestionIndex >= session.questions.length) {
      this.endQuiz(sessionId);
    } else {
      // Wait 5 seconds before next question
      setTimeout(() => {
        this.startQuestion(sessionId);
      }, 5000);
    }
  }

  private async endQuiz(sessionId: string) {
    const session = this.quizSessions.get(sessionId);
    if (!session) return;

    session.status = 'finished';

    // Calculate final results
    const results = Array.from(session.participants.values())
      .sort((a, b) => b.score - a.score)
      .map((participant, index) => ({
        rank: index + 1,
        username: participant.username,
        score: participant.score,
        correctAnswers: participant.answers.filter(answer => {
          const question = session.questions.find(q => q.id === answer.questionId);
          return question && answer.answer === question.correctAnswer;
        }).length
      }));

    // Broadcast final results
    this.io.to(`quiz:${sessionId}`).emit('quiz:completed', {
      results,
      totalQuestions: session.questions.length
    });

    // Store results in Redis for persistence
    await redis.setex(
      `quiz:results:${sessionId}`,
      86400, // 24 hours
      JSON.stringify(results)
    );
  }

  private calculateTimeBonus(startTime: Date, answerTime: Date, timeLimit: number): number {
    const elapsedSeconds = (answerTime.getTime() - startTime.getTime()) / 1000;
    const remainingTime = Math.max(0, timeLimit - elapsedSeconds);
    return Math.floor((remainingTime / timeLimit) * 50); // Max 50 bonus points
  }

  private calculateQuestionStats(sessionId: string, questionId: string) {
    const session = this.quizSessions.get(sessionId);
    if (!session) return {};

    const answers = Array.from(session.participants.values())
      .flatMap(p => p.answers)
      .filter(a => a.questionId === questionId);

    const stats = answers.reduce((acc, answer) => {
      acc[answer.answer] = (acc[answer.answer] || 0) + 1;
      return acc;
    }, {} as Record<number, number>);

    return {
      totalAnswers: answers.length,
      answerDistribution: stats
    };
  }

  private broadcastLeaderboard(sessionId: string) {
    const session = this.quizSessions.get(sessionId);
    if (!session) return;

    const leaderboard = Array.from(session.participants.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, 10) // Top 10
      .map((participant, index) => ({
        rank: index + 1,
        username: participant.username,
        score: participant.score
      }));

    this.io.to(`quiz:${sessionId}`).emit('quiz:leaderboard', leaderboard);
  }

  // Public method to create quiz session
  public createQuizSession(questions: Question[]): string {
    const sessionId = require('uuid').v4();
    
    this.quizSessions.set(sessionId, {
      id: sessionId,
      questions,
      currentQuestionIndex: 0,
      participants: new Map(),
      startTime: new Date(),
      status: 'waiting'
    });

    return sessionId;
  }
}
```

### Real-Time Chat System

```typescript
// src/services/ChatService.ts
import { Server as SocketServer } from 'socket.io';
import { redis } from '../server';
import Joi from 'joi';

interface ChatMessage {
  id: string;
  userId: string;
  username: string;
  content: string;
  timestamp: Date;
  roomId: string;
  type: 'text' | 'image' | 'file' | 'system';
  edited?: boolean;
  editedAt?: Date;
}

interface ChatRoom {
  id: string;
  name: string;
  description: string;
  participants: Set<string>;
  moderators: Set<string>;
  settings: {
    maxMessages: number;
    allowFiles: boolean;
    moderationEnabled: boolean;
    slowMode: number; // seconds between messages
  };
  messageHistory: ChatMessage[];
}

export class ChatService {
  private rooms = new Map<string, ChatRoom>();
  private userLastMessage = new Map<string, Date>();
  
  // Message validation schema
  private messageSchema = Joi.object({
    content: Joi.string().min(1).max(1000).required(),
    roomId: Joi.string().uuid().required(),
    type: Joi.string().valid('text', 'image', 'file').default('text')
  });

  constructor(private io: SocketServer) {
    this.setupChatHandlers();
    this.setupModeration();
  }

  private setupChatHandlers() {
    this.io.on('connection', (socket) => {
      // Join chat room
      socket.on('chat:join', async (data: { roomId: string }) => {
        const { error, value } = Joi.object({
          roomId: Joi.string().uuid().required()
        }).validate(data);

        if (error) {
          socket.emit('chat:error', { message: 'Invalid room ID' });
          return;
        }

        const room = this.rooms.get(value.roomId);
        if (!room) {
          socket.emit('chat:error', { message: 'Room not found' });
          return;
        }

        // Add user to room
        room.participants.add(socket.userId!);
        await socket.join(`chat:${value.roomId}`);

        // Send recent message history
        const recentMessages = room.messageHistory
          .slice(-50) // Last 50 messages
          .map(msg => ({
            id: msg.id,
            username: msg.username,
            content: msg.content,
            timestamp: msg.timestamp,
            type: msg.type,
            edited: msg.edited
          }));

        socket.emit('chat:history', { messages: recentMessages });

        // Broadcast user joined
        this.broadcastSystemMessage(
          value.roomId,
          `${socket.username} joined the chat`,
          'user_joined'
        );

        // Update participant count
        this.io.to(`chat:${value.roomId}`).emit('chat:participants', {
          count: room.participants.size
        });
      });

      // Leave chat room
      socket.on('chat:leave', async (data: { roomId: string }) => {
        const room = this.rooms.get(data.roomId);
        if (room) {
          room.participants.delete(socket.userId!);
          await socket.leave(`chat:${data.roomId}`);
          
          this.broadcastSystemMessage(
            data.roomId,
            `${socket.username} left the chat`,
            'user_left'
          );
        }
      });

      // Send message
      socket.on('chat:message', async (data: any) => {
        const { error, value } = this.messageSchema.validate(data);
        
        if (error) {
          socket.emit('chat:error', { 
            message: 'Invalid message format',
            details: error.details
          });
          return;
        }

        const room = this.rooms.get(value.roomId);
        if (!room || !room.participants.has(socket.userId!)) {
          socket.emit('chat:error', { message: 'Not authorized for this room' });
          return;
        }

        // Check slow mode
        if (room.settings.slowMode > 0) {
          const lastMessage = this.userLastMessage.get(socket.userId!);
          if (lastMessage) {
            const timeDiff = (Date.now() - lastMessage.getTime()) / 1000;
            if (timeDiff < room.settings.slowMode) {
              socket.emit('chat:error', {
                message: `Please wait ${Math.ceil(room.settings.slowMode - timeDiff)} seconds`
              });
              return;
            }
          }
        }

        // Content moderation
        const moderatedContent = await this.moderateContent(value.content);
        if (moderatedContent.blocked) {
          socket.emit('chat:error', { 
            message: 'Message blocked by content filter',
            reason: moderatedContent.reason
          });
          return;
        }

        // Create message
        const message: ChatMessage = {
          id: require('uuid').v4(),
          userId: socket.userId!,
          username: socket.username!,
          content: moderatedContent.content,
          timestamp: new Date(),
          roomId: value.roomId,
          type: value.type,
          edited: false
        };

        // Add to room history
        room.messageHistory.push(message);
        
        // Keep only recent messages in memory
        if (room.messageHistory.length > room.settings.maxMessages) {
          room.messageHistory = room.messageHistory.slice(-room.settings.maxMessages);
        }

        // Store in Redis for persistence
        await this.storeMessage(message);

        // Broadcast message to room
        this.io.to(`chat:${value.roomId}`).emit('chat:message', {
          id: message.id,
          username: message.username,
          content: message.content,
          timestamp: message.timestamp,
          type: message.type
        });

        // Update last message timestamp
        this.userLastMessage.set(socket.userId!, new Date());
      });

      // Edit message
      socket.on('chat:edit', async (data: { messageId: string; newContent: string }) => {
        const { error, value } = Joi.object({
          messageId: Joi.string().uuid().required(),
          newContent: Joi.string().min(1).max(1000).required()
        }).validate(data);

        if (error) {
          socket.emit('chat:error', { message: 'Invalid edit request' });
          return;
        }

        // Find message across all rooms user is in
        let targetMessage: ChatMessage | undefined;
        let targetRoomId: string | undefined;

        for (const [roomId, room] of this.rooms.entries()) {
          if (room.participants.has(socket.userId!)) {
            const message = room.messageHistory.find(
              m => m.id === value.messageId && m.userId === socket.userId!
            );
            if (message) {
              targetMessage = message;
              targetRoomId = roomId;
              break;
            }
          }
        }

        if (!targetMessage || !targetRoomId) {
          socket.emit('chat:error', { message: 'Message not found or unauthorized' });
          return;
        }

        // Check if message is too old to edit (5 minutes)
        const messageAge = Date.now() - targetMessage.timestamp.getTime();
        if (messageAge > 5 * 60 * 1000) {
          socket.emit('chat:error', { message: 'Message too old to edit' });
          return;
        }

        // Moderate new content
        const moderatedContent = await this.moderateContent(value.newContent);
        if (moderatedContent.blocked) {
          socket.emit('chat:error', { 
            message: 'Edited message blocked by content filter',
            reason: moderatedContent.reason
          });
          return;
        }

        // Update message
        targetMessage.content = moderatedContent.content;
        targetMessage.edited = true;
        targetMessage.editedAt = new Date();

        // Update in Redis
        await this.storeMessage(targetMessage);

        // Broadcast edit to room
        this.io.to(`chat:${targetRoomId}`).emit('chat:message:edited', {
          messageId: targetMessage.id,
          newContent: targetMessage.content,
          editedAt: targetMessage.editedAt
        });
      });

      // Handle disconnection
      socket.on('disconnect', () => {
        // Remove from all rooms
        for (const [roomId, room] of this.rooms.entries()) {
          if (room.participants.has(socket.userId!)) {
            room.participants.delete(socket.userId!);
            this.broadcastSystemMessage(
              roomId,
              `${socket.username} disconnected`,
              'user_disconnected'
            );
          }
        }
      });
    });
  }

  private async moderateContent(content: string): Promise<{
    content: string;
    blocked: boolean;
    reason?: string;
  }> {
    // Simple profanity filter (in production, use a proper service)
    const profanityWords = ['spam', 'banned_word']; // Add actual profanity list
    const lowerContent = content.toLowerCase();
    
    for (const word of profanityWords) {
      if (lowerContent.includes(word)) {
        return {
          content,
          blocked: true,
          reason: 'Inappropriate content detected'
        };
      }
    }

    // URL validation (optional)
    const urlRegex = /(https?:\/\/[^\s]+)/g;
    const hasUrls = urlRegex.test(content);
    
    if (hasUrls) {
      // For educational platforms, you might want to validate URLs
      // or require moderator approval
    }

    return {
      content,
      blocked: false
    };
  }

  private async storeMessage(message: ChatMessage) {
    const key = `chat:messages:${message.roomId}`;
    await redis.zadd(
      key,
      message.timestamp.getTime(),
      JSON.stringify(message)
    );
    
    // Keep only last 1000 messages per room
    await redis.zremrangebyrank(key, 0, -1001);
    
    // Set expiration (30 days)
    await redis.expire(key, 30 * 24 * 60 * 60);
  }

  private broadcastSystemMessage(roomId: string, content: string, type: string) {
    const systemMessage = {
      id: require('uuid').v4(),
      username: 'System',
      content,
      timestamp: new Date(),
      type: 'system',
      subType: type
    };

    this.io.to(`chat:${roomId}`).emit('chat:system', systemMessage);
  }

  private setupModeration() {
    // Moderation commands (for moderators)
    this.io.on('connection', (socket) => {
      socket.on('chat:moderate', async (data: {
        action: 'mute' | 'kick' | 'delete';
        targetUserId?: string;
        messageId?: string;
        roomId: string;
        duration?: number;
      }) => {
        const room = this.rooms.get(data.roomId);
        if (!room || !room.moderators.has(socket.userId!)) {
          socket.emit('chat:error', { message: 'Unauthorized moderation action' });
          return;
        }

        switch (data.action) {
          case 'delete':
            if (data.messageId) {
              await this.deleteMessage(data.roomId, data.messageId);
            }
            break;
          case 'mute':
            if (data.targetUserId && data.duration) {
              await this.muteUser(data.roomId, data.targetUserId, data.duration);
            }
            break;
          case 'kick':
            if (data.targetUserId) {
              await this.kickUser(data.roomId, data.targetUserId);
            }
            break;
        }
      });
    });
  }

  private async deleteMessage(roomId: string, messageId: string) {
    const room = this.rooms.get(roomId);
    if (!room) return;

    // Remove from memory
    room.messageHistory = room.messageHistory.filter(m => m.id !== messageId);
    
    // Remove from Redis
    const messages = await redis.zrange(`chat:messages:${roomId}`, 0, -1);
    for (const msgStr of messages) {
      const msg = JSON.parse(msgStr);
      if (msg.id === messageId) {
        await redis.zrem(`chat:messages:${roomId}`, msgStr);
        break;
      }
    }

    // Notify room
    this.io.to(`chat:${roomId}`).emit('chat:message:deleted', { messageId });
  }

  private async muteUser(roomId: string, userId: string, duration: number) {
    const muteKey = `chat:mute:${roomId}:${userId}`;
    await redis.setex(muteKey, duration, '1');
    
    this.io.to(`chat:${roomId}`).emit('chat:user:muted', {
      userId,
      duration
    });
  }

  private async kickUser(roomId: string, userId: string) {
    const room = this.rooms.get(roomId);
    if (!room) return;

    room.participants.delete(userId);
    
    // Find socket and disconnect from room
    const sockets = await this.io.in(`chat:${roomId}`).fetchSockets();
    for (const socket of sockets) {
      if ((socket as any).userId === userId) {
        socket.leave(`chat:${roomId}`);
        socket.emit('chat:kicked', { roomId });
        break;
      }
    }
  }

  // Public method to create chat room
  public createChatRoom(
    roomData: {
      name: string;
      description: string;
      settings?: Partial<ChatRoom['settings']>;
    },
    creatorId: string
  ): string {
    const roomId = require('uuid').v4();
    
    const room: ChatRoom = {
      id: roomId,
      name: roomData.name,
      description: roomData.description,
      participants: new Set([creatorId]),
      moderators: new Set([creatorId]),
      settings: {
        maxMessages: 1000,
        allowFiles: true,
        moderationEnabled: true,
        slowMode: 0,
        ...roomData.settings
      },
      messageHistory: []
    };

    this.rooms.set(roomId, room);
    return roomId;
  }
}
```

## 🚀 Production Deployment

### Docker Configuration

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY dist/ ./dist/
COPY public/ ./public/

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3001

CMD ["node", "dist/server.js"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - REDIS_HOST=redis
      - DB_HOST=postgres
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - redis
      - postgres
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=edtech_platform
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app
    restart: unless-stopped

volumes:
  redis_data:
  postgres_data:
```

### NGINX Configuration for WebSocket

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server app:3001;
        # Add more servers for load balancing
        # server app2:3001;
        # server app3:3001;
    }

    # WebSocket proxy settings
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    server {
        listen 80;
        server_name your-domain.com;

        # Redirect HTTP to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        # WebSocket and HTTP proxy
        location / {
            proxy_pass http://app_servers;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # WebSocket timeout settings
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
        }

        # Static file serving
        location /static/ {
            alias /app/public/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### Environment Configuration

```bash
# .env.production
NODE_ENV=production
PORT=3001

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=edtech_platform
DB_USER=postgres
DB_PASSWORD=your_secure_password

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# JWT
JWT_SECRET=your_jwt_secret_key_minimum_32_characters
JWT_REFRESH_SECRET=your_refresh_token_secret

# CORS
CLIENT_URL=https://your-frontend-domain.com

# Rate limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# WebSocket settings
WS_PING_TIMEOUT=60000
WS_PING_INTERVAL=25000
MAX_CONNECTIONS_PER_IP=10
```

## 🔗 Navigation

**Previous**: [Executive Summary](./executive-summary.md)  
**Next**: [Best Practices](./best-practices.md)

---

*Implementation Guide | Practical WebSocket setup for educational platforms*