# Template Examples: WebSocket Real-Time Communication

## 📝 Complete Implementation Templates

### Basic WebSocket Server Template

```typescript
// server.ts - Complete WebSocket server setup
import express from 'express';
import { createServer } from 'http';
import { Server as SocketServer } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { Pool } from 'pg';
import Redis from 'ioredis';
import jwt from 'jsonwebtoken';

// Environment configuration
const config = {
  port: process.env.PORT || 3001,
  cors: {
    origin: process.env.CLIENT_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
  },
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'edtech_platform',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'password'
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379')
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'your-secret-key',
    expiresIn: '15m'
  }
};

// Initialize Express app
const app = express();
const server = createServer(app);

// Database connection
const dbPool = new Pool(config.database);

// Redis connection
const redis = new Redis(config.redis);

// Middleware setup
app.use(helmet());
app.use(cors(config.cors));
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use('/api/', limiter);

// Socket.IO setup with CORS
const io = new SocketServer(server, {
  cors: config.cors,
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket', 'polling']
});

// Authentication middleware for Socket.IO
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    const decoded = jwt.verify(token, config.jwt.secret) as any;
    
    // Verify user exists in database
    const userResult = await dbPool.query(
      'SELECT id, username, role, permissions FROM users WHERE id = $1',
      [decoded.userId]
    );
    
    if (userResult.rows.length === 0) {
      return next(new Error('User not found'));
    }
    
    const user = userResult.rows[0];
    
    // Attach user info to socket
    (socket as any).userId = user.id;
    (socket as any).username = user.username;
    (socket as any).role = user.role;
    (socket as any).permissions = user.permissions;
    
    next();
  } catch (error) {
    next(new Error('Invalid authentication token'));
  }
});

// Connection handling
io.on('connection', (socket) => {
  console.log(`User ${(socket as any).username} connected`);
  
  // Join user to their personal room for direct messages
  socket.join(`user:${(socket as any).userId}`);
  
  // Handle disconnection
  socket.on('disconnect', (reason) => {
    console.log(`User ${(socket as any).username} disconnected: ${reason}`);
  });
  
  // Handle ping/pong for connection health
  socket.on('ping', () => {
    socket.emit('pong');
  });
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await dbPool.query('SELECT 1');
    
    // Check Redis connection
    await redis.ping();
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      connections: io.engine.clientsCount
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

// Start server
server.listen(config.port, () => {
  console.log(`Server running on port ${config.port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  
  server.close(() => {
    console.log('HTTP server closed');
  });
  
  await dbPool.end();
  await redis.quit();
  
  process.exit(0);
});

export { io, dbPool, redis };
```

### Educational Quiz System Template

```typescript
// QuizManager.ts - Complete quiz system implementation
import { Server as SocketServer, Socket } from 'socket.io';
import { Pool } from 'pg';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

interface Question {
  id: string;
  question: string;
  options: string[];
  correctAnswer: number;
  timeLimit: number;
  points: number;
  explanation?: string;
}

interface QuizSession {
  id: string;
  quizId: string;
  title: string;
  questions: Question[];
  participants: Map<string, Participant>;
  currentQuestionIndex: number;
  status: 'waiting' | 'active' | 'paused' | 'completed';
  startedAt?: Date;
  settings: {
    timePerQuestion: number;
    allowLateJoin: boolean;
    showLeaderboard: boolean;
    shuffleQuestions: boolean;
  };
}

interface Participant {
  userId: string;
  username: string;
  joinedAt: Date;
  answers: Array<{
    questionId: string;
    answer: number | string;
    submittedAt: Date;
    timeSpent: number;
    isCorrect: boolean;
    points: number;
  }>;
  totalScore: number;
  rank?: number;
}

class QuizManager {
  private sessions = new Map<string, QuizSession>();
  private questionTimers = new Map<string, NodeJS.Timeout>();
  
  constructor(
    private io: SocketServer,
    private db: Pool,
    private redis: Redis
  ) {
    this.setupEventHandlers();
  }
  
  private setupEventHandlers() {
    this.io.on('connection', (socket) => {
      // Create quiz session (instructor only)
      socket.on('quiz:create', async (data) => {
        try {
          if ((socket as any).role !== 'instructor') {
            socket.emit('quiz:error', { message: 'Only instructors can create quizzes' });
            return;
          }
          
          const session = await this.createQuizSession(data.quizId, (socket as any).userId);
          socket.emit('quiz:created', {
            sessionId: session.id,
            title: session.title,
            questionCount: session.questions.length
          });
          
        } catch (error) {
          socket.emit('quiz:error', { message: error.message });
        }
      });
      
      // Join quiz session
      socket.on('quiz:join', async (data) => {
        try {
          const { sessionId } = data;
          const session = this.sessions.get(sessionId);
          
          if (!session) {
            socket.emit('quiz:error', { message: 'Quiz session not found' });
            return;
          }
          
          if (session.status === 'completed') {
            socket.emit('quiz:error', { message: 'Quiz has already completed' });
            return;
          }
          
          if (session.status === 'active' && !session.settings.allowLateJoin) {
            socket.emit('quiz:error', { message: 'Quiz has already started' });
            return;
          }
          
          // Add participant
          const participant: Participant = {
            userId: (socket as any).userId,
            username: (socket as any).username,
            joinedAt: new Date(),
            answers: [],
            totalScore: 0
          };
          
          session.participants.set((socket as any).userId, participant);
          
          // Join socket room
          await socket.join(`quiz:${sessionId}`);
          
          // Send session info to participant
          socket.emit('quiz:joined', {
            sessionId,
            title: session.title,
            status: session.status,
            currentQuestion: session.status === 'active' ? session.currentQuestionIndex + 1 : null,
            totalQuestions: session.questions.length,
            participantCount: session.participants.size
          });
          
          // If quiz is active, send current question
          if (session.status === 'active') {
            this.sendCurrentQuestion(socket, session);
          }
          
          // Broadcast participant count update
          this.io.to(`quiz:${sessionId}`).emit('quiz:participant_update', {
            count: session.participants.size
          });
          
          // Store session state in Redis
          await this.saveSessionToRedis(session);
          
        } catch (error) {
          socket.emit('quiz:error', { message: error.message });
        }
      });
      
      // Start quiz (instructor only)
      socket.on('quiz:start', async (data) => {
        try {
          const { sessionId } = data;
          const session = this.sessions.get(sessionId);
          
          if (!session) {
            socket.emit('quiz:error', { message: 'Quiz session not found' });
            return;
          }
          
          if ((socket as any).role !== 'instructor') {
            socket.emit('quiz:error', { message: 'Only instructors can start quizzes' });
            return;
          }
          
          if (session.status !== 'waiting') {
            socket.emit('quiz:error', { message: 'Quiz cannot be started in current state' });
            return;
          }
          
          // Start the quiz
          session.status = 'active';
          session.startedAt = new Date();
          session.currentQuestionIndex = 0;
          
          // Shuffle questions if enabled
          if (session.settings.shuffleQuestions) {
            this.shuffleArray(session.questions);
          }
          
          // Broadcast quiz started
          this.io.to(`quiz:${sessionId}`).emit('quiz:started', {
            message: 'Quiz has started!',
            totalQuestions: session.questions.length
          });
          
          // Send first question
          this.sendQuestionToAll(session);
          
          // Save to database
          await this.saveSessionToDatabase(session);
          
        } catch (error) {
          socket.emit('quiz:error', { message: error.message });
        }
      });
      
      // Submit answer
      socket.on('quiz:answer', async (data) => {
        try {
          const { sessionId, questionId, answer, timeSpent } = data;
          const session = this.sessions.get(sessionId);
          
          if (!session || session.status !== 'active') {
            socket.emit('quiz:error', { message: 'Quiz is not active' });
            return;
          }
          
          const participant = session.participants.get((socket as any).userId);
          if (!participant) {
            socket.emit('quiz:error', { message: 'You are not a participant in this quiz' });
            return;
          }
          
          const currentQuestion = session.questions[session.currentQuestionIndex];
          if (currentQuestion.id !== questionId) {
            socket.emit('quiz:error', { message: 'Invalid question ID' });
            return;
          }
          
          // Check if already answered
          const existingAnswer = participant.answers.find(a => a.questionId === questionId);
          if (existingAnswer) {
            socket.emit('quiz:error', { message: 'You have already answered this question' });
            return;
          }
          
          // Process answer
          const isCorrect = answer === currentQuestion.correctAnswer;
          const points = isCorrect ? this.calculatePoints(currentQuestion, timeSpent) : 0;
          
          const answerRecord = {
            questionId,
            answer,
            submittedAt: new Date(),
            timeSpent: timeSpent || 0,
            isCorrect,
            points
          };
          
          participant.answers.push(answerRecord);
          participant.totalScore += points;
          
          // Send acknowledgment to participant
          socket.emit('quiz:answer:submitted', {
            questionId,
            isCorrect,
            points,
            totalScore: participant.totalScore
          });
          
          // Save answer to database
          await this.saveAnswerToDatabase(sessionId, (socket as any).userId, answerRecord);
          
          // Update leaderboard if enabled
          if (session.settings.showLeaderboard) {
            this.updateLeaderboard(session);
          }
          
        } catch (error) {
          socket.emit('quiz:error', { message: error.message });
        }
      });
      
      // Leave quiz
      socket.on('quiz:leave', async (data) => {
        const { sessionId } = data;
        const session = this.sessions.get(sessionId);
        
        if (session) {
          session.participants.delete((socket as any).userId);
          await socket.leave(`quiz:${sessionId}`);
          
          // Broadcast participant count update
          this.io.to(`quiz:${sessionId}`).emit('quiz:participant_update', {
            count: session.participants.size
          });
        }
      });
      
      // Handle disconnection cleanup
      socket.on('disconnect', () => {
        // Remove participant from all sessions
        for (const [sessionId, session] of this.sessions.entries()) {
          if (session.participants.has((socket as any).userId)) {
            session.participants.delete((socket as any).userId);
            
            // Broadcast update
            this.io.to(`quiz:${sessionId}`).emit('quiz:participant_update', {
              count: session.participants.size
            });
          }
        }
      });
    });
  }
  
  private async createQuizSession(quizId: string, instructorId: string): Promise<QuizSession> {
    // Fetch quiz from database
    const quizResult = await this.db.query(
      'SELECT id, title, questions, settings FROM quizzes WHERE id = $1 AND created_by = $2',
      [quizId, instructorId]
    );
    
    if (quizResult.rows.length === 0) {
      throw new Error('Quiz not found or you do not have permission to use it');
    }
    
    const quiz = quizResult.rows[0];
    const sessionId = uuidv4();
    
    const session: QuizSession = {
      id: sessionId,
      quizId: quiz.id,
      title: quiz.title,
      questions: JSON.parse(quiz.questions),
      participants: new Map(),
      currentQuestionIndex: 0,
      status: 'waiting',
      settings: {
        timePerQuestion: 30,
        allowLateJoin: false,
        showLeaderboard: true,
        shuffleQuestions: false,
        ...JSON.parse(quiz.settings || '{}')
      }
    };
    
    this.sessions.set(sessionId, session);
    
    return session;
  }
  
  private sendQuestionToAll(session: QuizSession) {
    const question = session.questions[session.currentQuestionIndex];
    
    this.io.to(`quiz:${session.id}`).emit('quiz:question', {
      questionNumber: session.currentQuestionIndex + 1,
      totalQuestions: session.questions.length,
      question: question.question,
      options: question.options,
      timeLimit: question.timeLimit,
      points: question.points
    });
    
    // Set timer for question
    const timer = setTimeout(() => {
      this.moveToNextQuestion(session);
    }, question.timeLimit * 1000);
    
    this.questionTimers.set(session.id, timer);
  }
  
  private sendCurrentQuestion(socket: Socket, session: QuizSession) {
    const question = session.questions[session.currentQuestionIndex];
    
    socket.emit('quiz:question', {
      questionNumber: session.currentQuestionIndex + 1,
      totalQuestions: session.questions.length,
      question: question.question,
      options: question.options,
      timeLimit: question.timeLimit,
      points: question.points
    });
  }
  
  private async moveToNextQuestion(session: QuizSession) {
    // Clear timer
    const timer = this.questionTimers.get(session.id);
    if (timer) {
      clearTimeout(timer);
      this.questionTimers.delete(session.id);
    }
    
    const currentQuestion = session.questions[session.currentQuestionIndex];
    
    // Show results for current question
    const questionStats = this.calculateQuestionStats(session, currentQuestion.id);
    
    this.io.to(`quiz:${session.id}`).emit('quiz:question:results', {
      questionId: currentQuestion.id,
      correctAnswer: currentQuestion.correctAnswer,
      explanation: currentQuestion.explanation,
      statistics: questionStats
    });
    
    // Move to next question or end quiz
    session.currentQuestionIndex++;
    
    if (session.currentQuestionIndex >= session.questions.length) {
      await this.endQuiz(session);
    } else {
      // Wait 5 seconds before next question
      setTimeout(() => {
        this.sendQuestionToAll(session);
      }, 5000);
    }
  }
  
  private async endQuiz(session: QuizSession) {
    session.status = 'completed';
    
    // Calculate final rankings
    const participants = Array.from(session.participants.values());
    participants.sort((a, b) => b.totalScore - a.totalScore);
    
    participants.forEach((participant, index) => {
      participant.rank = index + 1;
    });
    
    // Prepare final results
    const results = participants.map((participant, index) => ({
      rank: index + 1,
      username: participant.username,
      totalScore: participant.totalScore,
      correctAnswers: participant.answers.filter(a => a.isCorrect).length,
      totalAnswers: participant.answers.length,
      averageTime: participant.answers.reduce((sum, a) => sum + a.timeSpent, 0) / participant.answers.length
    }));
    
    // Broadcast final results
    this.io.to(`quiz:${session.id}`).emit('quiz:completed', {
      results,
      totalQuestions: session.questions.length,
      totalParticipants: session.participants.size
    });
    
    // Save final results to database
    await this.saveFinalResults(session, results);
    
    // Schedule session cleanup
    setTimeout(() => {
      this.sessions.delete(session.id);
    }, 5 * 60 * 1000); // Clean up after 5 minutes
  }
  
  private calculatePoints(question: Question, timeSpent: number): number {
    const basePoints = question.points;
    const timeBonus = Math.max(0, question.timeLimit - timeSpent) / question.timeLimit;
    return Math.round(basePoints * (0.7 + 0.3 * timeBonus));
  }
  
  private calculateQuestionStats(session: QuizSession, questionId: string) {
    const answers = [];
    
    for (const participant of session.participants.values()) {
      const answer = participant.answers.find(a => a.questionId === questionId);
      if (answer) {
        answers.push(answer);
      }
    }
    
    const stats = {
      totalResponses: answers.length,
      correctCount: answers.filter(a => a.isCorrect).length,
      averageTime: answers.reduce((sum, a) => sum + a.timeSpent, 0) / answers.length,
      answerDistribution: {}
    };
    
    // Count answer distribution
    answers.forEach(answer => {
      const key = answer.answer.toString();
      stats.answerDistribution[key] = (stats.answerDistribution[key] || 0) + 1;
    });
    
    return stats;
  }
  
  private updateLeaderboard(session: QuizSession) {
    const participants = Array.from(session.participants.values());
    participants.sort((a, b) => b.totalScore - a.totalScore);
    
    const leaderboard = participants.slice(0, 10).map((participant, index) => ({
      rank: index + 1,
      username: participant.username,
      totalScore: participant.totalScore,
      answersCount: participant.answers.length
    }));
    
    this.io.to(`quiz:${session.id}`).emit('quiz:leaderboard', leaderboard);
  }
  
  private shuffleArray<T>(array: T[]): void {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }
  
  private async saveSessionToDatabase(session: QuizSession): Promise<void> {
    await this.db.query(
      `INSERT INTO quiz_sessions (id, quiz_id, status, started_at, settings)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE SET
       status = $3, started_at = $4, settings = $5`,
      [
        session.id,
        session.quizId,
        session.status,
        session.startedAt,
        JSON.stringify(session.settings)
      ]
    );
  }
  
  private async saveSessionToRedis(session: QuizSession): Promise<void> {
    const sessionData = {
      id: session.id,
      quizId: session.quizId,
      title: session.title,
      status: session.status,
      currentQuestionIndex: session.currentQuestionIndex,
      participantCount: session.participants.size,
      startedAt: session.startedAt
    };
    
    await this.redis.setex(
      `quiz_session:${session.id}`,
      3600, // 1 hour expiry
      JSON.stringify(sessionData)
    );
  }
  
  private async saveAnswerToDatabase(
    sessionId: string,
    userId: string,
    answer: any
  ): Promise<void> {
    await this.db.query(
      `INSERT INTO quiz_answers 
       (session_id, user_id, question_id, answer, submitted_at, time_spent, is_correct, points)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        sessionId,
        userId,
        answer.questionId,
        JSON.stringify(answer.answer),
        answer.submittedAt,
        answer.timeSpent,
        answer.isCorrect,
        answer.points
      ]
    );
  }
  
  private async saveFinalResults(session: QuizSession, results: any[]): Promise<void> {
    await this.db.query(
      `UPDATE quiz_sessions SET 
       status = 'completed', 
       completed_at = NOW(),
       final_results = $2
       WHERE id = $1`,
      [session.id, JSON.stringify(results)]
    );
  }
  
  // Public methods for external use
  public getActiveSessionsCount(): number {
    return Array.from(this.sessions.values()).filter(s => s.status === 'active').length;
  }
  
  public getSessionById(sessionId: string): QuizSession | undefined {
    return this.sessions.get(sessionId);
  }
  
  public async getSessionResults(sessionId: string): Promise<any> {
    const result = await this.db.query(
      'SELECT final_results FROM quiz_sessions WHERE id = $1',
      [sessionId]
    );
    
    return result.rows[0]?.final_results ? JSON.parse(result.rows[0].final_results) : null;
  }
}

export { QuizManager, QuizSession, Participant };
```

### Real-Time Chat System Template

```typescript
// ChatManager.ts - Complete chat system implementation
import { Server as SocketServer, Socket } from 'socket.io';
import { Pool } from 'pg';
import Redis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';
import DOMPurify from 'isomorphic-dompurify';

interface ChatRoom {
  id: string;
  name: string;
  description: string;
  type: 'public' | 'private' | 'study_group';
  participants: Set<string>;
  moderators: Set<string>;
  settings: {
    maxParticipants: number;
    allowFiles: boolean;
    moderationEnabled: boolean;
    slowModeSeconds: number;
    messageHistory: number;
  };
  createdAt: Date;
  lastActivity: Date;
}

interface ChatMessage {
  id: string;
  roomId: string;
  userId: string;
  username: string;
  content: string;
  type: 'text' | 'image' | 'file' | 'system';
  timestamp: Date;
  edited?: boolean;
  editedAt?: Date;
  replyTo?: string;
  reactions: Map<string, string[]>; // emoji -> user IDs
}

interface UserTyping {
  userId: string;
  username: string;
  timestamp: Date;
}

class ChatManager {
  private rooms = new Map<string, ChatRoom>();
  private messageHistory = new Map<string, ChatMessage[]>();
  private userLastMessage = new Map<string, Date>();
  private typingUsers = new Map<string, Map<string, UserTyping>>(); // roomId -> userId -> typing info
  
  constructor(
    private io: SocketServer,
    private db: Pool,
    private redis: Redis
  ) {
    this.setupEventHandlers();
    this.setupCleanupTasks();
  }
  
  private setupEventHandlers() {
    this.io.on('connection', (socket) => {
      // Join chat room
      socket.on('chat:join', async (data) => {
        try {
          const { roomId } = data;
          const room = await this.getOrCreateRoom(roomId);
          
          if (!room) {
            socket.emit('chat:error', { message: 'Room not found' });
            return;
          }
          
          // Check room capacity
          if (room.participants.size >= room.settings.maxParticipants) {
            socket.emit('chat:error', { message: 'Room is full' });
            return;
          }
          
          // Add user to room
          room.participants.add((socket as any).userId);
          room.lastActivity = new Date();
          
          // Join socket room
          await socket.join(`chat:${roomId}`);
          
          // Send room info and recent messages
          const recentMessages = await this.getRecentMessages(roomId, 50);
          
          socket.emit('chat:joined', {
            roomId,
            roomName: room.name,
            participantCount: room.participants.size,
            messages: recentMessages,
            settings: room.settings
          });
          
          // Broadcast user joined (except to the user themselves)
          socket.to(`chat:${roomId}`).emit('chat:user_joined', {
            userId: (socket as any).userId,
            username: (socket as any).username,
            participantCount: room.participants.size
          });
          
          // Update room in Redis
          await this.saveRoomToRedis(room);
          
        } catch (error) {
          socket.emit('chat:error', { message: error.message });
        }
      });
      
      // Send message
      socket.on('chat:message', async (data) => {
        try {
          const { roomId, content, type = 'text', replyTo } = data;
          const room = this.rooms.get(roomId);
          
          if (!room || !room.participants.has((socket as any).userId)) {
            socket.emit('chat:error', { message: 'You are not in this room' });
            return;
          }
          
          // Check slow mode
          if (room.settings.slowModeSeconds > 0) {
            const lastMessage = this.userLastMessage.get((socket as any).userId);
            if (lastMessage) {
              const timeDiff = (Date.now() - lastMessage.getTime()) / 1000;
              if (timeDiff < room.settings.slowModeSeconds) {
                socket.emit('chat:error', {
                  message: `Please wait ${Math.ceil(room.settings.slowModeSeconds - timeDiff)} seconds`
                });
                return;
              }
            }
          }
          
          // Validate and sanitize content
          const sanitizedContent = this.sanitizeMessage(content);
          if (!sanitizedContent || sanitizedContent.length === 0) {
            socket.emit('chat:error', { message: 'Invalid message content' });
            return;
          }
          
          // Check for profanity/inappropriate content
          if (room.settings.moderationEnabled && await this.containsInappropriateContent(sanitizedContent)) {
            socket.emit('chat:error', { message: 'Message blocked by content filter' });
            return;
          }
          
          // Create message
          const message: ChatMessage = {
            id: uuidv4(),
            roomId,
            userId: (socket as any).userId,
            username: (socket as any).username,
            content: sanitizedContent,
            type,
            timestamp: new Date(),
            replyTo,
            reactions: new Map()
          };
          
          // Add to message history
          if (!this.messageHistory.has(roomId)) {
            this.messageHistory.set(roomId, []);
          }
          
          const messages = this.messageHistory.get(roomId)!;
          messages.push(message);
          
          // Keep only recent messages in memory
          if (messages.length > room.settings.messageHistory) {
            messages.splice(0, messages.length - room.settings.messageHistory);
          }
          
          // Save to database and Redis
          await Promise.all([
            this.saveMessageToDatabase(message),
            this.saveMessageToRedis(message)
          ]);
          
          // Broadcast message to room
          this.io.to(`chat:${roomId}`).emit('chat:message', {
            id: message.id,
            userId: message.userId,
            username: message.username,
            content: message.content,
            type: message.type,
            timestamp: message.timestamp,
            replyTo: message.replyTo
          });
          
          // Update last message timestamp
          this.userLastMessage.set((socket as any).userId, new Date());
          room.lastActivity = new Date();
          
          // Clear typing indicator for this user
          this.clearTypingIndicator(roomId, (socket as any).userId);
          
        } catch (error) {
          socket.emit('chat:error', { message: error.message });
        }
      });
      
      // Edit message
      socket.on('chat:edit', async (data) => {
        try {
          const { messageId, newContent } = data;
          
          // Find the message
          let targetMessage: ChatMessage | null = null;
          let targetRoomId: string | null = null;
          
          for (const [roomId, messages] of this.messageHistory.entries()) {
            const message = messages.find(m => m.id === messageId && m.userId === (socket as any).userId);
            if (message) {
              targetMessage = message;
              targetRoomId = roomId;
              break;
            }
          }
          
          if (!targetMessage || !targetRoomId) {
            socket.emit('chat:error', { message: 'Message not found or permission denied' });
            return;
          }
          
          // Check if message is too old to edit (5 minutes)
          const messageAge = Date.now() - targetMessage.timestamp.getTime();
          if (messageAge > 5 * 60 * 1000) {
            socket.emit('chat:error', { message: 'Message too old to edit' });
            return;
          }
          
          // Sanitize new content
          const sanitizedContent = this.sanitizeMessage(newContent);
          
          // Update message
          targetMessage.content = sanitizedContent;
          targetMessage.edited = true;
          targetMessage.editedAt = new Date();
          
          // Update in database and Redis
          await Promise.all([
            this.updateMessageInDatabase(targetMessage),
            this.saveMessageToRedis(targetMessage)
          ]);
          
          // Broadcast edit to room
          this.io.to(`chat:${targetRoomId}`).emit('chat:message_edited', {
            messageId: targetMessage.id,
            newContent: targetMessage.content,
            editedAt: targetMessage.editedAt
          });
          
        } catch (error) {
          socket.emit('chat:error', { message: error.message });
        }
      });
      
      // Delete message
      socket.on('chat:delete', async (data) => {
        try {
          const { messageId } = data;
          
          // Find the message
          let targetMessage: ChatMessage | null = null;
          let targetRoomId: string | null = null;
          
          for (const [roomId, messages] of this.messageHistory.entries()) {
            const room = this.rooms.get(roomId);
            const messageIndex = messages.findIndex(m => m.id === messageId);
            
            if (messageIndex >= 0) {
              const message = messages[messageIndex];
              
              // Check permissions (own message or moderator)
              if (message.userId === (socket as any).userId || 
                  (room && room.moderators.has((socket as any).userId))) {
                targetMessage = message;
                targetRoomId = roomId;
                
                // Remove from memory
                messages.splice(messageIndex, 1);
                break;
              }
            }
          }
          
          if (!targetMessage || !targetRoomId) {
            socket.emit('chat:error', { message: 'Message not found or permission denied' });
            return;
          }
          
          // Delete from database and Redis
          await Promise.all([
            this.deleteMessageFromDatabase(messageId),
            this.deleteMessageFromRedis(targetRoomId, messageId)
          ]);
          
          // Broadcast deletion
          this.io.to(`chat:${targetRoomId}`).emit('chat:message_deleted', {
            messageId
          });
          
        } catch (error) {
          socket.emit('chat:error', { message: error.message });
        }
      });
      
      // Typing indicator
      socket.on('chat:typing', (data) => {
        const { roomId, isTyping } = data;
        
        if (isTyping) {
          this.setTypingIndicator(roomId, (socket as any).userId, (socket as any).username);
        } else {
          this.clearTypingIndicator(roomId, (socket as any).userId);
        }
      });
      
      // Message reactions
      socket.on('chat:react', async (data) => {
        try {
          const { messageId, emoji } = data;
          
          // Find the message
          let targetMessage: ChatMessage | null = null;
          let targetRoomId: string | null = null;
          
          for (const [roomId, messages] of this.messageHistory.entries()) {
            const message = messages.find(m => m.id === messageId);
            if (message) {
              targetMessage = message;
              targetRoomId = roomId;
              break;
            }
          }
          
          if (!targetMessage || !targetRoomId) {
            socket.emit('chat:error', { message: 'Message not found' });
            return;
          }
          
          // Toggle reaction
          const userId = (socket as any).userId;
          const userReactions = targetMessage.reactions.get(emoji) || [];
          
          if (userReactions.includes(userId)) {
            // Remove reaction
            const newReactions = userReactions.filter(id => id !== userId);
            if (newReactions.length === 0) {
              targetMessage.reactions.delete(emoji);
            } else {
              targetMessage.reactions.set(emoji, newReactions);
            }
          } else {
            // Add reaction
            targetMessage.reactions.set(emoji, [...userReactions, userId]);
          }
          
          // Save to database
          await this.updateMessageReactions(messageId, targetMessage.reactions);
          
          // Broadcast reaction update
          this.io.to(`chat:${targetRoomId}`).emit('chat:reaction_updated', {
            messageId,
            reactions: Object.fromEntries(targetMessage.reactions)
          });
          
        } catch (error) {
          socket.emit('chat:error', { message: error.message });
        }
      });
      
      // Leave room
      socket.on('chat:leave', async (data) => {
        const { roomId } = data;
        await this.handleUserLeave(socket, roomId);
      });
      
      // Handle disconnection
      socket.on('disconnect', async () => {
        // Remove user from all rooms
        for (const [roomId, room] of this.rooms.entries()) {
          if (room.participants.has((socket as any).userId)) {
            await this.handleUserLeave(socket, roomId);
          }
        }
      });
    });
  }
  
  private async handleUserLeave(socket: Socket, roomId: string) {
    const room = this.rooms.get(roomId);
    if (!room) return;
    
    room.participants.delete((socket as any).userId);
    await socket.leave(`chat:${roomId}`);
    
    // Clear typing indicator
    this.clearTypingIndicator(roomId, (socket as any).userId);
    
    // Broadcast user left
    socket.to(`chat:${roomId}`).emit('chat:user_left', {
      userId: (socket as any).userId,
      username: (socket as any).username,
      participantCount: room.participants.size
    });
    
    // Update room in Redis
    await this.saveRoomToRedis(room);
  }
  
  private sanitizeMessage(content: string): string {
    if (!content || typeof content !== 'string') return '';
    
    // Basic HTML sanitization
    const sanitized = DOMPurify.sanitize(content, {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'code'],
      ALLOWED_ATTR: []
    });
    
    return sanitized.trim().substring(0, 2000); // Max 2000 characters
  }
  
  private async containsInappropriateContent(content: string): Promise<boolean> {
    // Simple profanity filter - in production, use a proper service
    const inappropriateWords = ['spam', 'inappropriate']; // Add actual filter words
    const lowerContent = content.toLowerCase();
    
    return inappropriateWords.some(word => lowerContent.includes(word));
  }
  
  private setTypingIndicator(roomId: string, userId: string, username: string) {
    if (!this.typingUsers.has(roomId)) {
      this.typingUsers.set(roomId, new Map());
    }
    
    const roomTyping = this.typingUsers.get(roomId)!;
    roomTyping.set(userId, {
      userId,
      username,
      timestamp: new Date()
    });
    
    // Broadcast typing update
    this.broadcastTypingUpdate(roomId);
    
    // Auto-clear after 5 seconds
    setTimeout(() => {
      this.clearTypingIndicator(roomId, userId);
    }, 5000);
  }
  
  private clearTypingIndicator(roomId: string, userId: string) {
    const roomTyping = this.typingUsers.get(roomId);
    if (roomTyping && roomTyping.has(userId)) {
      roomTyping.delete(userId);
      this.broadcastTypingUpdate(roomId);
    }
  }
  
  private broadcastTypingUpdate(roomId: string) {
    const roomTyping = this.typingUsers.get(roomId);
    const typingUsers = roomTyping ? Array.from(roomTyping.values()) : [];
    
    this.io.to(`chat:${roomId}`).emit('chat:typing_update', {
      typingUsers: typingUsers.map(user => ({
        userId: user.userId,
        username: user.username
      }))
    });
  }
  
  private async getOrCreateRoom(roomId: string): Promise<ChatRoom | null> {
    // Check memory cache first
    if (this.rooms.has(roomId)) {
      return this.rooms.get(roomId)!;
    }
    
    // Check Redis cache
    const cachedRoom = await this.redis.get(`chat_room:${roomId}`);
    if (cachedRoom) {
      const roomData = JSON.parse(cachedRoom);
      const room: ChatRoom = {
        ...roomData,
        participants: new Set(roomData.participants),
        moderators: new Set(roomData.moderators),
        createdAt: new Date(roomData.createdAt),
        lastActivity: new Date(roomData.lastActivity)
      };
      
      this.rooms.set(roomId, room);
      return room;
    }
    
    // Check database
    const dbResult = await this.db.query(
      'SELECT * FROM chat_rooms WHERE id = $1',
      [roomId]
    );
    
    if (dbResult.rows.length === 0) {
      return null; // Room doesn't exist
    }
    
    const dbRoom = dbResult.rows[0];
    const room: ChatRoom = {
      id: dbRoom.id,
      name: dbRoom.name,
      description: dbRoom.description,
      type: dbRoom.type,
      participants: new Set(),
      moderators: new Set(JSON.parse(dbRoom.moderators || '[]')),
      settings: JSON.parse(dbRoom.settings),
      createdAt: dbRoom.created_at,
      lastActivity: dbRoom.last_activity || new Date()
    };
    
    this.rooms.set(roomId, room);
    await this.saveRoomToRedis(room);
    
    return room;
  }
  
  private async getRecentMessages(roomId: string, limit: number): Promise<any[]> {
    // Check memory first
    const memoryMessages = this.messageHistory.get(roomId);
    if (memoryMessages && memoryMessages.length >= limit) {
      return memoryMessages.slice(-limit).map(this.formatMessage);
    }
    
    // Fetch from database
    const dbResult = await this.db.query(
      `SELECT cm.*, u.username FROM chat_messages cm
       JOIN users u ON cm.user_id = u.id
       WHERE cm.room_id = $1
       ORDER BY cm.timestamp DESC
       LIMIT $2`,
      [roomId, limit]
    );
    
    const messages = dbResult.rows.reverse().map(row => ({
      id: row.id,
      userId: row.user_id,
      username: row.username,
      content: row.content,
      type: row.type,
      timestamp: row.timestamp,
      edited: row.edited,
      editedAt: row.edited_at,
      replyTo: row.reply_to,
      reactions: JSON.parse(row.reactions || '{}')
    }));
    
    return messages;
  }
  
  private formatMessage(message: ChatMessage): any {
    return {
      id: message.id,
      userId: message.userId,
      username: message.username,
      content: message.content,
      type: message.type,
      timestamp: message.timestamp,
      edited: message.edited,
      editedAt: message.editedAt,
      replyTo: message.replyTo,
      reactions: Object.fromEntries(message.reactions)
    };
  }
  
  private async saveRoomToRedis(room: ChatRoom): Promise<void> {
    const roomData = {
      ...room,
      participants: Array.from(room.participants),
      moderators: Array.from(room.moderators)
    };
    
    await this.redis.setex(
      `chat_room:${room.id}`,
      3600, // 1 hour expiry
      JSON.stringify(roomData)
    );
  }
  
  private async saveMessageToDatabase(message: ChatMessage): Promise<void> {
    await this.db.query(
      `INSERT INTO chat_messages 
       (id, room_id, user_id, content, type, timestamp, reply_to, reactions)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        message.id,
        message.roomId,
        message.userId,
        message.content,
        message.type,
        message.timestamp,
        message.replyTo,
        JSON.stringify(Object.fromEntries(message.reactions))
      ]
    );
  }
  
  private async saveMessageToRedis(message: ChatMessage): Promise<void> {
    const messageData = {
      ...message,
      reactions: Object.fromEntries(message.reactions)
    };
    
    await this.redis.zadd(
      `chat:messages:${message.roomId}`,
      message.timestamp.getTime(),
      JSON.stringify(messageData)
    );
    
    // Keep only recent messages (1000 max)
    await this.redis.zremrangebyrank(`chat:messages:${message.roomId}`, 0, -1001);
  }
  
  private async updateMessageInDatabase(message: ChatMessage): Promise<void> {
    await this.db.query(
      `UPDATE chat_messages SET 
       content = $1, edited = true, edited_at = $2
       WHERE id = $3`,
      [message.content, message.editedAt, message.id]
    );
  }
  
  private async deleteMessageFromDatabase(messageId: string): Promise<void> {
    await this.db.query('DELETE FROM chat_messages WHERE id = $1', [messageId]);
  }
  
  private async deleteMessageFromRedis(roomId: string, messageId: string): Promise<void> {
    const messages = await this.redis.zrange(`chat:messages:${roomId}`, 0, -1);
    
    for (const msgStr of messages) {
      const msg = JSON.parse(msgStr);
      if (msg.id === messageId) {
        await this.redis.zrem(`chat:messages:${roomId}`, msgStr);
        break;
      }
    }
  }
  
  private async updateMessageReactions(messageId: string, reactions: Map<string, string[]>): Promise<void> {
    await this.db.query(
      'UPDATE chat_messages SET reactions = $1 WHERE id = $2',
      [JSON.stringify(Object.fromEntries(reactions)), messageId]
    );
  }
  
  private setupCleanupTasks() {
    // Clear old typing indicators every 30 seconds
    setInterval(() => {
      const cutoff = Date.now() - 10000; // 10 seconds ago
      
      for (const [roomId, roomTyping] of this.typingUsers.entries()) {
        let changed = false;
        
        for (const [userId, typing] of roomTyping.entries()) {
          if (typing.timestamp.getTime() < cutoff) {
            roomTyping.delete(userId);
            changed = true;
          }
        }
        
        if (changed) {
          this.broadcastTypingUpdate(roomId);
        }
      }
    }, 30000);
    
    // Clean up empty rooms every 5 minutes
    setInterval(() => {
      for (const [roomId, room] of this.rooms.entries()) {
        if (room.participants.size === 0) {
          const lastActivity = room.lastActivity.getTime();
          const cutoff = Date.now() - 10 * 60 * 1000; // 10 minutes ago
          
          if (lastActivity < cutoff) {
            this.rooms.delete(roomId);
            this.messageHistory.delete(roomId);
            this.typingUsers.delete(roomId);
            
            // Clean up Redis
            this.redis.del(`chat_room:${roomId}`);
          }
        }
      }
    }, 5 * 60 * 1000);
  }
  
  // Public methods
  public createRoom(roomData: {
    name: string;
    description: string;
    type: 'public' | 'private' | 'study_group';
    settings?: Partial<ChatRoom['settings']>;
  }, creatorId: string): Promise<string> {
    return new Promise(async (resolve, reject) => {
      try {
        const roomId = uuidv4();
        
        const room: ChatRoom = {
          id: roomId,
          name: roomData.name,
          description: roomData.description,
          type: roomData.type,
          participants: new Set(),
          moderators: new Set([creatorId]),
          settings: {
            maxParticipants: 100,
            allowFiles: true,
            moderationEnabled: true,
            slowModeSeconds: 0,
            messageHistory: 1000,
            ...roomData.settings
          },
          createdAt: new Date(),
          lastActivity: new Date()
        };
        
        // Save to database
        await this.db.query(
          `INSERT INTO chat_rooms (id, name, description, type, moderators, settings, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            roomId,
            room.name,
            room.description,
            room.type,
            JSON.stringify(Array.from(room.moderators)),
            JSON.stringify(room.settings),
            room.createdAt
          ]
        );
        
        this.rooms.set(roomId, room);
        await this.saveRoomToRedis(room);
        
        resolve(roomId);
      } catch (error) {
        reject(error);
      }
    });
  }
  
  public getRoomStats(): any {
    const stats = {
      totalRooms: this.rooms.size,
      activeRooms: 0,
      totalParticipants: 0,
      messagesInMemory: 0
    };
    
    for (const room of this.rooms.values()) {
      if (room.participants.size > 0) {
        stats.activeRooms++;
      }
      stats.totalParticipants += room.participants.size;
    }
    
    for (const messages of this.messageHistory.values()) {
      stats.messagesInMemory += messages.length;
    }
    
    return stats;
  }
}

export { ChatManager, ChatRoom, ChatMessage };
```

## 🔗 Navigation

**Previous**: [Testing Strategies](./testing-strategies.md)  
**Next**: [Deployment Guide](./deployment-guide.md)

---

*Template Examples | Ready-to-use WebSocket implementation templates for educational platforms*