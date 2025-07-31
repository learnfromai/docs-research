# Testing Strategies: WebSocket Real-Time Communication

## 🧪 Testing Pyramid for WebSocket Applications

### Testing Strategy Overview

WebSocket applications require a multi-layered testing approach that addresses the unique challenges of real-time, bidirectional communication:

1. **Unit Tests (60%)**: Individual WebSocket handlers, message processors, and business logic
2. **Integration Tests (30%)**: Client-server communication flows, database interactions, Redis pub/sub
3. **End-to-End Tests (10%)**: Complete user journeys, load testing, chaos engineering

## 🔧 Unit Testing WebSocket Handlers

### Testing Framework Setup

```typescript
// jest.config.js for WebSocket testing
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  setupFilesAfterEnv: [
    '<rootDir>/src/tests/setup.ts'
  ],
  testMatch: [
    '<rootDir>/src/**/*.test.ts'
  ],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/tests/**/*'
  ],
  coverageReporters: ['text', 'lcov'],
  testTimeout: 10000
};
```

```typescript
// src/tests/setup.ts - Test environment setup
import { Server } from 'socket.io';
import { createServer } from 'http';
import { io as ioClient, Socket as ClientSocket } from 'socket.io-client';
import Redis from 'ioredis-mock';

// Mock Redis for testing
jest.mock('ioredis', () => require('ioredis-mock'));

// Global test utilities
global.createTestServer = (): {
  server: Server;
  port: number;
  cleanup: () => Promise<void>;
} => {
  const httpServer = createServer();
  const server = new Server(httpServer, {
    cors: { origin: "*" }
  });
  
  const port = Math.floor(Math.random() * 10000) + 30000;
  
  return {
    server,
    port,
    cleanup: async () => {
      server.close();
      httpServer.close();
    }
  };
};

global.createTestClient = (port: number): Promise<ClientSocket> => {
  return new Promise((resolve, reject) => {
    const client = ioClient(`http://localhost:${port}`, {
      transports: ['websocket']
    });
    
    client.on('connect', () => resolve(client));
    client.on('connect_error', reject);
    
    setTimeout(() => reject(new Error('Connection timeout')), 5000);
  });
};
```

### Unit Test Examples

```typescript
// src/handlers/QuizHandler.test.ts
import { QuizHandler } from '../handlers/QuizHandler';
import { QuizService } from '../services/QuizService';
import { AuthenticationService } from '../services/AuthenticationService';

describe('QuizHandler', () => {
  let quizHandler: QuizHandler;
  let mockQuizService: jest.Mocked<QuizService>;
  let mockAuthService: jest.Mocked<AuthenticationService>;
  let testServer: any;
  let testClient: any;

  beforeEach(async () => {
    // Create mocked services
    mockQuizService = {
      createSession: jest.fn(),
      joinSession: jest.fn(),
      submitAnswer: jest.fn(),
      getLeaderboard: jest.fn(),
      endSession: jest.fn()
    } as any;

    mockAuthService = {
      verifyToken: jest.fn(),
      hasPermission: jest.fn()
    } as any;

    // Set up test server
    testServer = global.createTestServer();
    quizHandler = new QuizHandler(testServer.server, mockQuizService, mockAuthService);
    
    await testServer.server.listen(testServer.port);
    testClient = await global.createTestClient(testServer.port);
  });

  afterEach(async () => {
    if (testClient) {
      testClient.disconnect();
    }
    await testServer.cleanup();
  });

  describe('quiz:join event', () => {
    it('should successfully join a quiz session', async () => {
      // Arrange
      const mockUser = {
        userId: 'user123',
        username: 'testuser',
        role: 'student'
      };
      
      const mockSession = {
        id: 'session123',
        title: 'Test Quiz',
        status: 'waiting'
      };

      mockAuthService.verifyToken.mockResolvedValue(mockUser);
      mockQuizService.joinSession.mockResolvedValue(mockSession);

      // Act
      const responsePromise = new Promise((resolve) => {
        testClient.on('quiz:joined', resolve);
      });

      testClient.emit('quiz:join', {
        sessionId: 'session123',
        token: 'valid_token'
      });

      const response = await responsePromise;

      // Assert
      expect(mockAuthService.verifyToken).toHaveBeenCalledWith('valid_token');
      expect(mockQuizService.joinSession).toHaveBeenCalledWith('session123', mockUser);
      expect(response).toMatchObject({
        sessionId: 'session123',
        title: 'Test Quiz',
        status: 'waiting'
      });
    });

    it('should reject join with invalid token', async () => {
      // Arrange
      mockAuthService.verifyToken.mockResolvedValue(null);

      // Act
      const errorPromise = new Promise((resolve) => {
        testClient.on('quiz:error', resolve);
      });

      testClient.emit('quiz:join', {
        sessionId: 'session123',
        token: 'invalid_token'
      });

      const error = await errorPromise;

      // Assert
      expect(error).toMatchObject({
        message: 'Invalid authentication token'
      });
      expect(mockQuizService.joinSession).not.toHaveBeenCalled();
    });

    it('should handle non-existent quiz session', async () => {
      // Arrange
      const mockUser = { userId: 'user123', username: 'testuser', role: 'student' };
      mockAuthService.verifyToken.mockResolvedValue(mockUser);
      mockQuizService.joinSession.mockRejectedValue(new Error('Session not found'));

      // Act
      const errorPromise = new Promise((resolve) => {
        testClient.on('quiz:error', resolve);
      });

      testClient.emit('quiz:join', {
        sessionId: 'nonexistent',
        token: 'valid_token'
      });

      const error = await errorPromise;

      // Assert
      expect(error).toMatchObject({
        message: 'Session not found'
      });
    });
  });

  describe('quiz:answer event', () => {
    it('should submit answer and return score', async () => {
      // Arrange
      const mockUser = { userId: 'user123', username: 'testuser', role: 'student' };
      const mockResult = {
        correct: true,
        score: 100,
        timeBonus: 25,
        totalScore: 125
      };

      mockAuthService.verifyToken.mockResolvedValue(mockUser);
      mockQuizService.submitAnswer.mockResolvedValue(mockResult);

      // Act
      const responsePromise = new Promise((resolve) => {
        testClient.on('quiz:answer:result', resolve);
      });

      testClient.emit('quiz:answer', {
        sessionId: 'session123',
        questionId: 'q1',
        answer: 2,
        token: 'valid_token'
      });

      const result = await responsePromise;

      // Assert
      expect(mockQuizService.submitAnswer).toHaveBeenCalledWith(
        'session123',
        'q1',
        mockUser,
        2
      );
      expect(result).toMatchObject(mockResult);
    });

    it('should enforce rate limiting on answer submissions', async () => {
      // Arrange
      const mockUser = { userId: 'user123', username: 'testuser', role: 'student' };
      mockAuthService.verifyToken.mockResolvedValue(mockUser);
      mockQuizService.submitAnswer.mockResolvedValue({ correct: true, score: 100 });

      // Act - Submit multiple answers rapidly
      const promises = [];
      for (let i = 0; i < 10; i++) {
        promises.push(new Promise((resolve, reject) => {
          testClient.emit('quiz:answer', {
            sessionId: 'session123',
            questionId: `q${i}`,
            answer: 1,
            token: 'valid_token'
          });
          
          const timeout = setTimeout(() => reject(new Error('No response')), 1000);
          
          testClient.once('quiz:answer:result', () => {
            clearTimeout(timeout);
            resolve('success');
          });
          
          testClient.once('quiz:error', (error) => {
            clearTimeout(timeout);
            resolve(error);
          });
        }));
      }

      const results = await Promise.all(promises);

      // Assert - Some requests should be rate limited
      const rateLimitedResults = results.filter(
        result => typeof result === 'object' && 
        (result as any).message?.includes('rate limit')
      );
      
      expect(rateLimitedResults.length).toBeGreaterThan(0);
    });
  });
});
```

### Testing Message Validation

```typescript
// src/validators/MessageValidator.test.ts
import { MessageValidator } from '../validators/MessageValidator';

describe('MessageValidator', () => {
  let validator: MessageValidator;

  beforeEach(() => {
    validator = new MessageValidator();
  });

  describe('chat message validation', () => {
    it('should validate correct chat message', async () => {
      const message = {
        content: 'Hello world!',
        roomId: '550e8400-e29b-41d4-a716-446655440000',
        type: 'text'
      };

      const result = await validator.validateMessage('chat:message', message, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(true);
      expect(result.data).toMatchObject(message);
    });

    it('should reject message with XSS attempt', async () => {
      const message = {
        content: '<script>alert("xss")</script>Hello',
        roomId: '550e8400-e29b-41d4-a716-446655440000',
        type: 'text'
      };

      const result = await validator.validateMessage('chat:message', message, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(true); // Should be valid after sanitization
      expect(result.data.content).toBe('Hello'); // Script should be removed
    });

    it('should reject message that is too long', async () => {
      const message = {
        content: 'a'.repeat(2001), // Exceeds 2000 character limit
        roomId: '550e8400-e29b-41d4-a716-446655440000',
        type: 'text'
      };

      const result = await validator.validateMessage('chat:message', message, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(false);
      expect(result.error).toContain('Validation error');
    });

    it('should enforce rate limiting', async () => {
      const message = {
        content: 'Test message',
        roomId: '550e8400-e29b-41d4-a716-446655440000',
        type: 'text'
      };

      // Submit messages rapidly
      const results = [];
      for (let i = 0; i < 35; i++) { // Exceeds 30 per minute limit
        const result = await validator.validateMessage('chat:message', message, 'user123', '127.0.0.1');
        results.push(result);
      }

      const rateLimitedResults = results.filter(r => r.rateLimited);
      expect(rateLimitedResults.length).toBeGreaterThan(0);
    });
  });

  describe('quiz answer validation', () => {
    it('should validate numeric answer', async () => {
      const answer = {
        sessionId: '550e8400-e29b-41d4-a716-446655440000',
        questionId: '550e8400-e29b-41d4-a716-446655440001',
        answer: 2,
        timeSpent: 45
      };

      const result = await validator.validateMessage('quiz:answer', answer, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(true);
      expect(result.data).toMatchObject(answer);
    });

    it('should validate text answer', async () => {
      const answer = {
        sessionId: '550e8400-e29b-41d4-a716-446655440000',
        questionId: '550e8400-e29b-41d4-a716-446655440001',
        answer: 'The answer is photosynthesis',
        timeSpent: 120
      };

      const result = await validator.validateMessage('quiz:answer', answer, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(true);
      expect(result.data.answer).toBe('The answer is photosynthesis');
    });

    it('should reject answer with special characters', async () => {
      const answer = {
        sessionId: '550e8400-e29b-41d4-a716-446655440000',
        questionId: '550e8400-e29b-41d4-a716-446655440001',
        answer: 'Answer with <script>alert("hack")</script>',
        timeSpent: 60
      };

      const result = await validator.validateMessage('quiz:answer', answer, 'user123', '127.0.0.1');

      expect(result.isValid).toBe(false);
      expect(result.error).toContain('pattern');
    });
  });
});
```

## 🔄 Integration Testing

### WebSocket Integration Test Setup

```typescript
// src/tests/integration/WebSocketIntegration.test.ts
import { Server } from 'socket.io';
import { io as ioClient } from 'socket.io-client';
import { createServer } from 'http';
import { Pool } from 'pg';
import Redis from 'ioredis-mock';
import { WebSocketServer } from '../src/WebSocketServer';

describe('WebSocket Integration Tests', () => {
  let server: WebSocketServer;
  let dbPool: Pool;
  let redis: Redis;
  let httpServer: any;
  let port: number;

  beforeAll(async () => {
    // Set up test database
    dbPool = new Pool({
      host: process.env.TEST_DB_HOST || 'localhost',
      port: parseInt(process.env.TEST_DB_PORT || '5432'),
      database: process.env.TEST_DB_NAME || 'websocket_test',
      user: process.env.TEST_DB_USER || 'postgres',
      password: process.env.TEST_DB_PASSWORD || 'password'
    });

    // Set up test Redis
    redis = new Redis();

    // Create test server
    httpServer = createServer();
    port = Math.floor(Math.random() * 10000) + 40000;
    
    server = new WebSocketServer(httpServer, {
      dbPool,
      redis,
      cors: { origin: "*" }
    });

    await new Promise<void>((resolve) => {
      httpServer.listen(port, resolve);
    });

    // Set up test data
    await setupTestData();
  });

  afterAll(async () => {
    await server.close();
    await dbPool.end();
    await redis.quit();
    httpServer.close();
  });

  beforeEach(async () => {
    await cleanupTestData();
  });

  async function setupTestData() {
    // Create test users
    await dbPool.query(`
      INSERT INTO users (id, username, email, role, permissions) VALUES
      ('user1', 'student1', 'student1@test.com', 'student', '["quiz:participate"]'),
      ('user2', 'student2', 'student2@test.com', 'student', '["quiz:participate"]'),
      ('instructor1', 'teacher1', 'teacher1@test.com', 'instructor', '["quiz:create", "quiz:manage"]')
      ON CONFLICT (id) DO NOTHING
    `);

    // Create test quiz
    await dbPool.query(`
      INSERT INTO quizzes (id, title, questions, created_by) VALUES
      ('quiz1', 'Integration Test Quiz', $1, 'instructor1')
      ON CONFLICT (id) DO NOTHING
    `, [JSON.stringify([
      {
        id: 'q1',
        question: 'What is 2 + 2?',
        options: ['3', '4', '5', '6'],
        correctAnswer: 1
      },
      {
        id: 'q2',
        question: 'What is the capital of France?',
        options: ['London', 'Berlin', 'Paris', 'Madrid'],
        correctAnswer: 2
      }
    ])]);
  }

  async function cleanupTestData() {
    await dbPool.query('DELETE FROM quiz_answers WHERE session_id LIKE $1', ['test_%']);
    await dbPool.query('DELETE FROM quiz_sessions WHERE id LIKE $1', ['test_%']);
    await redis.flushall();
  }

  describe('Quiz Session Flow', () => {
    it('should handle complete quiz session lifecycle', async () => {
      // Create clients
      const instructorClient = ioClient(`http://localhost:${port}`);
      const student1Client = ioClient(`http://localhost:${port}`);
      const student2Client = ioClient(`http://localhost:${port}`);

      try {
        // Wait for connections
        await Promise.all([
          new Promise(resolve => instructorClient.on('connect', resolve)),
          new Promise(resolve => student1Client.on('connect', resolve)),
          new Promise(resolve => student2Client.on('connect', resolve))
        ]);

        // Authenticate clients
        await Promise.all([
          new Promise(resolve => {
            instructorClient.emit('auth', { token: 'instructor_token' });
            instructorClient.on('auth:success', resolve);
          }),
          new Promise(resolve => {
            student1Client.emit('auth', { token: 'student1_token' });
            student1Client.on('auth:success', resolve);
          }),
          new Promise(resolve => {
            student2Client.emit('auth', { token: 'student2_token' });
            student2Client.on('auth:success', resolve);
          })
        ]);

        // Instructor creates quiz session
        const sessionCreated = new Promise(resolve => {
          instructorClient.on('quiz:session:created', resolve);
        });

        instructorClient.emit('quiz:create_session', {
          quizId: 'quiz1',
          sessionId: 'test_session_1'
        });

        const sessionData = await sessionCreated;
        expect(sessionData).toMatchObject({
          sessionId: 'test_session_1',
          status: 'waiting'
        });

        // Students join session
        const student1Joined = new Promise(resolve => {
          student1Client.on('quiz:joined', resolve);
        });

        const student2Joined = new Promise(resolve => {
          student2Client.on('quiz:joined', resolve);
        });

        student1Client.emit('quiz:join', { sessionId: 'test_session_1' });
        student2Client.emit('quiz:join', { sessionId: 'test_session_1' });

        await Promise.all([student1Joined, student2Joined]);

        // Instructor starts quiz
        const quizStarted = Promise.all([
          new Promise(resolve => student1Client.on('quiz:started', resolve)),
          new Promise(resolve => student2Client.on('quiz:started', resolve))
        ]);

        instructorClient.emit('quiz:start', { sessionId: 'test_session_1' });
        await quizStarted;

        // Students receive first question
        const firstQuestion = Promise.all([
          new Promise(resolve => student1Client.on('quiz:question', resolve)),
          new Promise(resolve => student2Client.on('quiz:question', resolve))
        ]);

        const [q1Student1, q1Student2] = await firstQuestion;
        expect(q1Student1).toMatchObject({
          questionNumber: 1,
          question: 'What is 2 + 2?',
          options: ['3', '4', '5', '6']
        });

        // Students submit answers
        const answerResults = Promise.all([
          new Promise(resolve => student1Client.on('quiz:answer:result', resolve)),
          new Promise(resolve => student2Client.on('quiz:answer:result', resolve))
        ]);

        student1Client.emit('quiz:answer', {
          sessionId: 'test_session_1',
          questionId: 'q1',
          answer: 1 // Correct answer
        });

        student2Client.emit('quiz:answer', {
          sessionId: 'test_session_1',
          questionId: 'q1',
          answer: 0 // Incorrect answer
        });

        const [result1, result2] = await answerResults;
        expect(result1).toMatchObject({ correct: true });
        expect(result2).toMatchObject({ correct: false });

        // Check leaderboard update
        const leaderboardUpdate = Promise.all([
          new Promise(resolve => student1Client.on('quiz:leaderboard', resolve)),
          new Promise(resolve => student2Client.on('quiz:leaderboard', resolve)),
          new Promise(resolve => instructorClient.on('quiz:leaderboard', resolve))
        ]);

        const [lb1, lb2, lb3] = await leaderboardUpdate;
        expect(lb1).toEqual(
          expect.arrayContaining([
            expect.objectContaining({ username: 'student1' }),
            expect.objectContaining({ username: 'student2' })
          ])
        );

        // Verify database state
        const dbAnswers = await dbPool.query(
          'SELECT * FROM quiz_answers WHERE session_id = $1',
          ['test_session_1']
        );
        expect(dbAnswers.rows).toHaveLength(2);

      } finally {
        instructorClient.disconnect();
        student1Client.disconnect();
        student2Client.disconnect();
      }
    });

    it('should handle concurrent answer submissions correctly', async () => {
      // Test race conditions and data consistency
      const clients = [];
      const clientPromises = [];

      // Create 20 concurrent clients
      for (let i = 0; i < 20; i++) {
        const client = ioClient(`http://localhost:${port}`);
        clients.push(client);
        
        clientPromises.push(
          new Promise(resolve => client.on('connect', resolve))
        );
      }

      try {
        await Promise.all(clientPromises);

        // All clients join the same quiz session
        const joinPromises = clients.map((client, index) => 
          new Promise(resolve => {
            client.emit('auth', { token: `student${index}_token` });
            client.on('auth:success', () => {
              client.emit('quiz:join', { sessionId: 'test_concurrent_session' });
              client.on('quiz:joined', resolve);
            });
          })
        );

        await Promise.all(joinPromises);

        // All clients submit answers simultaneously
        const answerPromises = clients.map((client, index) =>
          new Promise(resolve => {
            client.emit('quiz:answer', {
              sessionId: 'test_concurrent_session',
              questionId: 'q1',
              answer: index % 4 // Distribute answers across options
            });
            client.on('quiz:answer:result', resolve);
          })
        );

        const results = await Promise.all(answerPromises);
        expect(results).toHaveLength(20);

        // Verify database consistency
        const dbAnswers = await dbPool.query(
          'SELECT COUNT(*) as count FROM quiz_answers WHERE session_id = $1',
          ['test_concurrent_session']
        );
        expect(parseInt(dbAnswers.rows[0].count)).toBe(20);

      } finally {
        clients.forEach(client => client.disconnect());
      }
    });
  });

  describe('Chat System Integration', () => {
    it('should handle real-time chat with message persistence', async () => {
      const client1 = ioClient(`http://localhost:${port}`);
      const client2 = ioClient(`http://localhost:${port}`);

      try {
        // Connect and authenticate
        await Promise.all([
          new Promise(resolve => client1.on('connect', resolve)),
          new Promise(resolve => client2.on('connect', resolve))
        ]);

        await Promise.all([
          new Promise(resolve => {
            client1.emit('auth', { token: 'student1_token' });
            client1.on('auth:success', resolve);
          }),
          new Promise(resolve => {
            client2.emit('auth', { token: 'student2_token' });
            client2.on('auth:success', resolve);
          })
        ]);

        // Join chat room
        await Promise.all([
          new Promise(resolve => {
            client1.emit('chat:join', { roomId: 'test_room_1' });
            client1.on('chat:joined', resolve);
          }),
          new Promise(resolve => {
            client2.emit('chat:join', { roomId: 'test_room_1' });
            client2.on('chat:joined', resolve);
          })
        ]);

        // Send message from client1
        const messageReceived = new Promise(resolve => {
          client2.on('chat:message', resolve);
        });

        client1.emit('chat:message', {
          roomId: 'test_room_1',
          content: 'Hello from integration test!',
          type: 'text'
        });

        const receivedMessage = await messageReceived;
        expect(receivedMessage).toMatchObject({
          username: 'student1',
          content: 'Hello from integration test!',
          type: 'text'
        });

        // Verify message persistence in Redis
        const messages = await redis.zrange('chat:messages:test_room_1', 0, -1);
        expect(messages).toHaveLength(1);
        
        const storedMessage = JSON.parse(messages[0]);
        expect(storedMessage.content).toBe('Hello from integration test!');

      } finally {
        client1.disconnect();
        client2.disconnect();
      }
    });
  });
});
```

## 🚀 Load Testing Strategies

### Artillery.io Load Testing Configuration

```yaml
# artillery-websocket-load-test.yml
config:
  target: 'https://your-websocket-server.com'
  phases:
    # Warm-up phase
    - duration: 60
      arrivalRate: 5
      name: "Warm-up"
    
    # Ramp-up phase
    - duration: 300
      arrivalRate: 5
      rampTo: 50
      name: "Ramp-up"
    
    # Sustained load
    - duration: 600
      arrivalRate: 50
      name: "Sustained load"
    
    # Peak load test
    - duration: 120
      arrivalRate: 50
      rampTo: 200
      name: "Peak load"
    
    # Cool-down
    - duration: 180
      arrivalRate: 200
      rampTo: 5
      name: "Cool-down"

  environments:
    production:
      target: 'https://prod-websocket.yourapp.com'
      phases:
        - duration: 300
          arrivalRate: 10
          rampTo: 100
    
    staging:
      target: 'https://staging-websocket.yourapp.com'
      phases:
        - duration: 120
          arrivalRate: 5
          rampTo: 25

  payload:
    path: './test-data.csv'
    fields:
      - userId
      - username
      - token

  engines:
    socketio:
      transports: ['websocket']
      timeout: 30000

  plugins:
    metrics-by-endpoint:
      useOnlyRequestNames: true
    
scenarios:
  - name: "Quiz Participant Journey"
    weight: 60
    engine: socketio
    flow:
      # Authentication
      - emit:
          channel: "auth"
          data:
            token: "{{ token }}"
      
      - think: 1
      
      # Join quiz session
      - emit:
          channel: "quiz:join"
          data:
            sessionId: "load-test-session-{{ $randomInt(1, 5) }}"
      
      - think: 2
      
      # Simulate quiz participation (10 questions)
      - loop:
          - emit:
              channel: "quiz:answer"
              data:
                questionId: "q-{{ $loopElement }}"
                answer: "{{ $randomInt(0, 3) }}"
                timeSpent: "{{ $randomInt(5, 30) }}"
          - think: "{{ $randomInt(3, 8) }}"
        over:
          - 1
          - 2
          - 3
          - 4
          - 5
          - 6
          - 7
          - 8
          - 9
          - 10
      
      # Leave session
      - emit:
          channel: "quiz:leave"

  - name: "Chat User Journey"
    weight: 30
    engine: socketio
    flow:
      # Authentication
      - emit:
          channel: "auth"
          data:
            token: "{{ token }}"
      
      - think: 1
      
      # Join chat room
      - emit:
          channel: "chat:join"
          data:
            roomId: "chat-room-{{ $randomInt(1, 3) }}"
      
      - think: 2
      
      # Send messages
      - loop:
          - emit:
              channel: "chat:message"
              data:
                content: "Load test message {{ $randomString() }}"
                type: "text"
          - think: "{{ $randomInt(5, 15) }}"
        count: "{{ $randomInt(5, 20) }}"
      
      # Leave chat
      - emit:
          channel: "chat:leave"

  - name: "Dashboard Observer"
    weight: 10
    engine: socketio
    flow:
      - emit:
          channel: "auth"
          data:
            token: "{{ token }}"
      
      - emit:
          channel: "dashboard:subscribe"
          data:
            metrics: ["active_users", "quiz_sessions", "messages_per_second"]
      
      # Just observe for the duration
      - think: 300
      
      - emit:
          channel: "dashboard:unsubscribe"
```

### Custom Load Testing Framework

```typescript
// src/tests/load/LoadTestRunner.ts
import { io as ioClient, Socket } from 'socket.io-client';
import { performance } from 'perf_hooks';

interface LoadTestConfig {
  targetUrl: string;
  maxConcurrentUsers: number;
  rampUpDuration: number; // seconds
  testDuration: number; // seconds
  userJourneys: UserJourney[];
}

interface UserJourney {
  name: string;
  weight: number; // percentage of users following this journey
  steps: JourneyStep[];
}

interface JourneyStep {
  type: 'emit' | 'wait' | 'expect';
  event?: string;
  data?: any;
  duration?: number;
  expectedEvent?: string;
  timeout?: number;
}

interface LoadTestMetrics {
  connectionsSuccessful: number;
  connectionsFailed: number;
  messagessent: number;
  messagesReceived: number;
  averageLatency: number;
  p95Latency: number;
  p99Latency: number;
  errorsCount: number;
  throughputPerSecond: number;
}

class LoadTestRunner {
  private metrics: LoadTestMetrics = {
    connectionsSuccessful: 0,
    connectionsFailed: 0,
    messagesOut: 0,
    messagesReceived: 0,
    averageLatency: 0,
    p95Latency: 0,
    p99Latency: 0,
    errorsCount: 0,
    throughputPerSecond: 0
  };
  
  private latencyMeasurements: number[] = [];
  private activeConnections: Set<Socket> = new Set();
  private testStartTime: number = 0;
  
  constructor(private config: LoadTestConfig) {}
  
  public async runLoadTest(): Promise<LoadTestMetrics> {
    console.log(`Starting load test: ${this.config.maxConcurrentUsers} users over ${this.config.testDuration}s`);
    
    this.testStartTime = performance.now();
    
    // Calculate user ramp-up schedule
    const rampUpInterval = (this.config.rampUpDuration * 1000) / this.config.maxConcurrentUsers;
    
    // Start users gradually
    for (let i = 0; i < this.config.maxConcurrentUsers; i++) {
      setTimeout(() => {
        this.startUser(i);
      }, i * rampUpInterval);
    }
    
    // Wait for test completion
    await new Promise(resolve => {
      setTimeout(resolve, (this.config.rampUpDuration + this.config.testDuration) * 1000);
    });
    
    // Cleanup
    await this.cleanup();
    
    // Calculate final metrics
    this.calculateFinalMetrics();
    
    return this.metrics;
  }
  
  private async startUser(userId: number): Promise<void> {
    try {
      const socket = ioClient(this.config.targetUrl, {
        transports: ['websocket'],
        timeout: 10000
      });
      
      this.activeConnections.add(socket);
      
      socket.on('connect', () => {
        this.metrics.connectionsSuccessful++;
        this.executeUserJourney(socket, userId);
      });
      
      socket.on('connect_error', (error) => {
        this.metrics.connectionsFailed++;
        console.error(`User ${userId} connection failed:`, error.message);
      });
      
      socket.on('disconnect', () => {
        this.activeConnections.delete(socket);
      });
      
      // Set up message tracking
      socket.onAny((eventName, data) => {
        this.metrics.messagesReceived++;
        
        if (data && data._sentAt) {
          const latency = performance.now() - data._sentAt;
          this.latencyMeasurements.push(latency);
        }
      });
      
    } catch (error) {
      this.metrics.connectionsFailed++;
      console.error(`Failed to create user ${userId}:`, error);
    }
  }
  
  private async executeUserJourney(socket: Socket, userId: number): Promise<void> {
    // Select journey based on weights
    const journey = this.selectJourney();
    
    console.log(`User ${userId} starting journey: ${journey.name}`);
    
    try {
      for (const step of journey.steps) {
        await this.executeStep(socket, step, userId);
      }
    } catch (error) {
      this.metrics.errorsCount++;
      console.error(`User ${userId} journey failed:`, error.message);
    }
  }
  
  private async executeStep(socket: Socket, step: JourneyStep, userId: number): Promise<void> {
    switch (step.type) {
      case 'emit':
        if (step.event && step.data) {
          const dataWithTimestamp = {
            ...step.data,
            _sentAt: performance.now()
          };
          socket.emit(step.event, dataWithTimestamp);
          this.metrics.messagesOut++;
        }
        break;
        
      case 'wait':
        if (step.duration) {
          await new Promise(resolve => setTimeout(resolve, step.duration));
        }
        break;
        
      case 'expect':
        if (step.expectedEvent) {
          await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
              reject(new Error(`Expected event ${step.expectedEvent} not received`));
            }, step.timeout || 5000);
            
            socket.once(step.expectedEvent, () => {
              clearTimeout(timeout);
              resolve(undefined);
            });
          });
        }
        break;
    }
  }
  
  private selectJourney(): UserJourney {
    const random = Math.random() * 100;
    let cumulative = 0;
    
    for (const journey of this.config.userJourneys) {
      cumulative += journey.weight;
      if (random <= cumulative) {
        return journey;
      }
    }
    
    return this.config.userJourneys[0]; // Fallback
  }
  
  private async cleanup(): Promise<void> {
    console.log('Cleaning up connections...');
    
    const disconnectPromises = Array.from(this.activeConnections).map(socket => {
      return new Promise<void>(resolve => {
        socket.disconnect();
        socket.on('disconnect', resolve);
        setTimeout(resolve, 1000); // Force resolve after 1 second
      });
    });
    
    await Promise.all(disconnectPromises);
  }
  
  private calculateFinalMetrics(): void {
    if (this.latencyMeasurements.length > 0) {
      // Sort latencies for percentile calculation
      this.latencyMeasurements.sort((a, b) => a - b);
      
      const sum = this.latencyMeasurements.reduce((a, b) => a + b, 0);
      this.metrics.averageLatency = sum / this.latencyMeasurements.length;
      
      const p95Index = Math.floor(this.latencyMeasurements.length * 0.95);
      const p99Index = Math.floor(this.latencyMeasurements.length * 0.99);
      
      this.metrics.p95Latency = this.latencyMeasurements[p95Index];
      this.metrics.p99Latency = this.latencyMeasurements[p99Index];
    }
    
    // Calculate throughput
    const testDuration = (performance.now() - this.testStartTime) / 1000;
    this.metrics.throughputPerSecond = this.metrics.messagesReceived / testDuration;
  }
  
  public printResults(): void {
    console.log('\n=== Load Test Results ===');
    console.log(`Successful Connections: ${this.metrics.connectionsSuccessful}`);
    console.log(`Failed Connections: ${this.metrics.connectionsFailed}`);
    console.log(`Messages Sent: ${this.metrics.messagesOut}`);
    console.log(`Messages Received: ${this.metrics.messagesReceived}`);
    console.log(`Average Latency: ${this.metrics.averageLatency.toFixed(2)}ms`);
    console.log(`95th Percentile Latency: ${this.metrics.p95Latency.toFixed(2)}ms`);
    console.log(`99th Percentile Latency: ${this.metrics.p99Latency.toFixed(2)}ms`);
    console.log(`Errors: ${this.metrics.errorsCount}`);
    console.log(`Throughput: ${this.metrics.throughputPerSecond.toFixed(2)} msg/sec`);
    console.log('========================\n');
  }
}

// Example usage
async function runQuizLoadTest() {
  const config: LoadTestConfig = {
    targetUrl: 'http://localhost:3001',
    maxConcurrentUsers: 100,
    rampUpDuration: 60, // 1 minute ramp-up
    testDuration: 300,  // 5 minute test
    userJourneys: [
      {
        name: 'Quiz Participant',
        weight: 80,
        steps: [
          { type: 'emit', event: 'auth', data: { token: 'test_token' } },
          { type: 'expect', expectedEvent: 'auth:success', timeout: 5000 },
          { type: 'emit', event: 'quiz:join', data: { sessionId: 'load_test_session' } },
          { type: 'expect', expectedEvent: 'quiz:joined', timeout: 5000 },
          { type: 'wait', duration: 2000 },
          ...Array.from({ length: 10 }, (_, i) => [
            { type: 'emit', event: 'quiz:answer', data: { questionId: `q${i}`, answer: Math.floor(Math.random() * 4) } },
            { type: 'wait', duration: Math.random() * 5000 + 2000 }
          ]).flat()
        ]
      },
      {
        name: 'Observer',
        weight: 20,
        steps: [
          { type: 'emit', event: 'auth', data: { token: 'observer_token' } },
          { type: 'expect', expectedEvent: 'auth:success', timeout: 5000 },
          { type: 'emit', event: 'quiz:observe', data: { sessionId: 'load_test_session' } },
          { type: 'wait', duration: 300000 } // Just observe for 5 minutes
        ]
      }
    ]
  };
  
  const runner = new LoadTestRunner(config);
  const results = await runner.runLoadTest();
  runner.printResults();
  
  return results;
}

export { LoadTestRunner, runQuizLoadTest };
```

## 🔗 Navigation

**Previous**: [Performance Analysis](./performance-analysis.md)  
**Next**: [Template Examples](./template-examples.md)

---

*Testing Strategies | Comprehensive testing approaches for production-ready WebSocket applications*