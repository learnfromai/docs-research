# Migration Strategy: Database Migration and Data Transfer

## 🎯 Overview

This comprehensive migration guide covers strategies, tools, and best practices for migrating between PostgreSQL and MongoDB, as well as upgrading within the same database system. The guide addresses common migration scenarios for EdTech applications, including zero-downtime migrations, data transformation strategies, and rollback procedures.

## 🔄 Migration Scenarios and Planning

### Migration Assessment Framework

#### Current State Analysis
```typescript
interface MigrationAssessment {
  // Database characteristics
  currentDatabase: 'postgresql' | 'mongodb';
  targetDatabase: 'postgresql' | 'mongodb';
  dataVolume: {
    totalRecords: number;
    totalSizeGB: number;
    largestTable: string;
    complexityScore: number; // 1-10 scale
  };
  
  // Application constraints
  downtime: {
    maxAllowedMinutes: number;
    maintenanceWindow: string;
    businessImpact: 'low' | 'medium' | 'high' | 'critical';
  };
  
  // Technical constraints
  infrastructure: {
    networkBandwidth: string;
    availableStorage: number;
    computeResources: string;
    backupCapacity: number;
  };
  
  // Complexity factors
  challenges: {
    schemaComplexity: number;
    dataRelationships: number;
    customFunctions: number;
    thirdPartyIntegrations: number;
  };
}

class MigrationPlanner {
  assessMigration(currentDb: string, targetDb: string, specs: any): MigrationAssessment {
    const complexity = this.calculateComplexityScore(specs);
    const estimatedDuration = this.estimateMigrationTime(specs, complexity);
    
    return {
      currentDatabase: currentDb as any,
      targetDatabase: targetDb as any,
      dataVolume: specs.dataVolume,
      downtime: specs.downtime,
      infrastructure: specs.infrastructure,
      challenges: specs.challenges,
      estimatedDuration,
      riskLevel: this.assessRiskLevel(complexity, specs),
      recommendedStrategy: this.recommendStrategy(specs, complexity)
    };
  }

  private calculateComplexityScore(specs: any): number {
    // Scoring algorithm based on data relationships, schema complexity, etc.
    return Math.min(10, Math.max(1, 
      specs.challenges.schemaComplexity * 0.3 +
      specs.challenges.dataRelationships * 0.3 +
      specs.challenges.customFunctions * 0.2 +
      specs.challenges.thirdPartyIntegrations * 0.2
    ));
  }

  private recommendStrategy(specs: any, complexity: number): string {
    if (specs.downtime.maxAllowedMinutes === 0) {
      return 'zero-downtime-blue-green';
    } else if (complexity >= 8) {
      return 'phased-migration-with-parallel-running';
    } else if (specs.dataVolume.totalSizeGB > 1000) {
      return 'incremental-migration-with-replication';
    } else {
      return 'maintenance-window-migration';
    }
  }
}
```

### Migration Strategy Selection Matrix

| Scenario | Data Size | Complexity | Downtime Tolerance | Recommended Strategy | Duration Estimate |
|----------|-----------|------------|-------------------|---------------------|------------------|
| **PostgreSQL → MongoDB** | < 100GB | Low | 2-4 hours | Dump & Restore with transformation | 6-12 hours |
| **PostgreSQL → MongoDB** | > 100GB | Medium | < 30 minutes | Blue-Green with CDC | 2-4 weeks |
| **PostgreSQL → MongoDB** | > 1TB | High | Zero downtime | Phased migration with dual-write | 2-6 months |
| **MongoDB → PostgreSQL** | < 100GB | Low | 2-4 hours | ETL with normalization | 8-16 hours |
| **MongoDB → PostgreSQL** | > 100GB | Medium | < 30 minutes | Streaming replication | 3-6 weeks |
| **MongoDB → PostgreSQL** | > 1TB | High | Zero downtime | Gradual strangler pattern | 3-12 months |
| **PostgreSQL Version Upgrade** | Any | Low | 1-2 hours | pg_upgrade in-place | 2-6 hours |
| **MongoDB Version Upgrade** | Any | Low | 30 minutes | Rolling upgrade | 1-4 hours |

## 🔄 PostgreSQL to MongoDB Migration

### Schema Transformation Strategy

#### Relational to Document Model Conversion
```typescript
// Schema transformation utility
interface RelationalSchema {
  tables: TableDefinition[];
  relationships: Relationship[];
  constraints: Constraint[];
}

interface DocumentSchema {
  collections: CollectionDefinition[];
  indexes: IndexDefinition[];
  validationRules: ValidationRule[];
}

class PostgreSQLToMongoTransformer {
  private conversionRules = {
    // One-to-One: Embed as subdocument
    oneToOne: 'embed',
    // One-to-Many (small): Embed as array
    oneToManySmall: 'embed',
    // One-to-Many (large): Reference with separate collection
    oneToManyLarge: 'reference',
    // Many-to-Many: Reference with junction collection or embedded IDs
    manyToMany: 'reference'
  };

  transformSchema(pgSchema: RelationalSchema): DocumentSchema {
    const collections: CollectionDefinition[] = [];
    
    // Analyze relationships to determine embedding strategy
    const relationshipAnalysis = this.analyzeRelationships(pgSchema);
    
    // Transform each table considering its relationships
    for (const table of pgSchema.tables) {
      const collection = this.transformTable(table, relationshipAnalysis);
      collections.push(collection);
    }

    return {
      collections,
      indexes: this.generateIndexes(collections, pgSchema),
      validationRules: this.generateValidationRules(collections, pgSchema)
    };
  }

  private transformTable(table: TableDefinition, relationships: any): CollectionDefinition {
    const collection: CollectionDefinition = {
      name: table.name,
      fields: {},
      embeddedDocuments: [],
      references: []
    };

    // Transform basic fields
    for (const column of table.columns) {
      collection.fields[column.name] = this.transformDataType(column);
    }

    // Handle relationships
    const tableRelationships = relationships[table.name] || [];
    
    for (const rel of tableRelationships) {
      if (rel.type === 'oneToOne' || (rel.type === 'oneToMany' && rel.expectedSize < 100)) {
        // Embed related data
        collection.embeddedDocuments.push(this.createEmbeddedDocument(rel));
      } else {
        // Use references
        collection.references.push(this.createReference(rel));
      }
    }

    return collection;
  }

  private transformDataType(column: ColumnDefinition): any {
    const typeMapping = {
      'varchar': 'string',
      'text': 'string',
      'integer': 'int',
      'bigint': 'long',
      'decimal': 'decimal',
      'boolean': 'bool',
      'timestamp': 'date',
      'jsonb': 'object',
      'uuid': 'objectId' // Convert UUIDs to ObjectIds
    };

    return {
      bsonType: typeMapping[column.dataType] || 'string',
      required: !column.nullable,
      description: column.comment
    };
  }
}

// Example transformation
const transformer = new PostgreSQLToMongoTransformer();

// PostgreSQL schema
const pgSchema = {
  tables: [
    {
      name: 'users',
      columns: [
        { name: 'id', dataType: 'uuid', nullable: false },
        { name: 'email', dataType: 'varchar', nullable: false },
        { name: 'first_name', dataType: 'varchar', nullable: false },
        { name: 'created_at', dataType: 'timestamp', nullable: false }
      ]
    },
    {
      name: 'user_profiles',
      columns: [
        { name: 'id', dataType: 'uuid', nullable: false },
        { name: 'user_id', dataType: 'uuid', nullable: false },
        { name: 'bio', dataType: 'text', nullable: true },
        { name: 'avatar_url', dataType: 'varchar', nullable: true }
      ]
    }
  ],
  relationships: [
    {
      from: 'users',
      to: 'user_profiles',
      type: 'oneToOne',
      foreignKey: 'user_id'
    }
  ]
};

// Transformed MongoDB schema
const mongoSchema = transformer.transformSchema(pgSchema);
/* Result:
{
  collections: [
    {
      name: 'users',
      fields: {
        email: { bsonType: 'string', required: true },
        firstName: { bsonType: 'string', required: true },
        createdAt: { bsonType: 'date', required: true }
      },
      embeddedDocuments: [
        {
          name: 'profile',
          fields: {
            bio: { bsonType: 'string', required: false },
            avatarUrl: { bsonType: 'string', required: false }
          }
        }
      ]
    }
  ]
}
*/
```

### Data Migration Pipeline

#### ETL Pipeline Implementation
```typescript
// Data migration pipeline for PostgreSQL to MongoDB
import { Pool } from 'pg';
import { MongoClient, BulkWriteOperation } from 'mongodb';
import { Transform, pipeline } from 'stream';

class PostgreSQLToMongoMigrator {
  private pgPool: Pool;
  private mongoClient: MongoClient;
  private batchSize = 1000;
  private maxConcurrency = 5;

  constructor(pgConfig: any, mongoConfig: any) {
    this.pgPool = new Pool(pgConfig);
    this.mongoClient = new MongoClient(mongoConfig.connectionString);
  }

  async migrate(migrationPlan: MigrationPlan): Promise<MigrationResult> {
    console.log('🚀 Starting PostgreSQL to MongoDB migration...');
    
    const result: MigrationResult = {
      startTime: new Date(),
      endTime: null,
      tablesProcessed: 0,
      recordsMigrated: 0,
      errors: [],
      status: 'running'
    };

    try {
      await this.mongoClient.connect();
      
      // Process each table according to the migration plan
      for (const tableConfig of migrationPlan.tables) {
        console.log(`📋 Processing table: ${tableConfig.sourceName}`);
        
        const tableResult = await this.migrateTable(tableConfig);
        result.recordsMigrated += tableResult.recordCount;
        result.tablesProcessed++;
        
        console.log(`✅ Completed ${tableConfig.sourceName}: ${tableResult.recordCount} records`);
      }

      result.status = 'completed';
      result.endTime = new Date();
      
    } catch (error) {
      result.status = 'failed';
      result.errors.push(error.message);
      throw error;
    }

    return result;
  }

  private async migrateTable(config: TableMigrationConfig): Promise<TableMigrationResult> {
    const { sourceName, targetCollection, transformation } = config;
    
    // Get total record count for progress tracking
    const countQuery = `SELECT COUNT(*) as total FROM ${sourceName}`;
    const countResult = await this.pgPool.query(countQuery);
    const totalRecords = parseInt(countResult.rows[0].total);
    
    console.log(`📊 Total records to migrate: ${totalRecords}`);

    // Create read stream from PostgreSQL
    const pgStream = await this.createPostgreSQLStream(sourceName, totalRecords);
    
    // Create transformation stream
    const transformStream = this.createTransformationStream(transformation);
    
    // Create MongoDB write stream
    const mongoStream = this.createMongoDBWriteStream(targetCollection);

    // Execute pipeline
    return new Promise((resolve, reject) => {
      let recordCount = 0;
      let errorCount = 0;

      pipeline(
        pgStream,
        transformStream,
        mongoStream,
        (error) => {
          if (error) {
            reject(error);
          } else {
            resolve({
              recordCount,
              errorCount,
              completedAt: new Date()
            });
          }
        }
      );

      transformStream.on('data', () => recordCount++);
      transformStream.on('error', () => errorCount++);
      
      // Progress reporting
      const progressInterval = setInterval(() => {
        const progress = (recordCount / totalRecords * 100).toFixed(2);
        console.log(`📈 Progress: ${progress}% (${recordCount}/${totalRecords})`);
      }, 10000);

      transformStream.on('end', () => {
        clearInterval(progressInterval);
        console.log(`🎯 Migration completed: ${recordCount} records processed`);
      });
    });
  }

  private async createPostgreSQLStream(tableName: string, totalRecords: number) {
    // Use cursor-based pagination for large datasets
    const pageSize = this.batchSize;
    let offset = 0;

    return new Transform({
      objectMode: true,
      async transform(chunk, encoding, callback) {
        try {
          if (offset >= totalRecords) {
            this.push(null); // End stream
            return callback();
          }

          const query = `
            SELECT * FROM ${tableName} 
            ORDER BY id 
            LIMIT ${pageSize} OFFSET ${offset}
          `;
          
          const result = await this.pgPool.query(query);
          
          for (const row of result.rows) {
            this.push(row);
          }
          
          offset += pageSize;
          callback();
          
        } catch (error) {
          callback(error);
        }
      }
    });
  }

  private createTransformationStream(transformation: TransformationConfig) {
    return new Transform({
      objectMode: true,
      transform(pgRow, encoding, callback) {
        try {
          const mongoDoc = this.transformRecord(pgRow, transformation);
          callback(null, mongoDoc);
        } catch (error) {
          console.error('Transformation error:', error);
          callback(error);
        }
      }
    });
  }

  private transformRecord(pgRow: any, transformation: TransformationConfig): any {
    const mongoDoc: any = {};

    // Apply field mappings
    for (const [pgField, mongoField] of Object.entries(transformation.fieldMappings || {})) {
      if (pgRow[pgField] !== undefined) {
        mongoDoc[mongoField] = this.transformValue(pgRow[pgField], transformation.dataTypes?.[mongoField]);
      }
    }

    // Handle embedded documents
    if (transformation.embeddedDocuments) {
      for (const embed of transformation.embeddedDocuments) {
        mongoDoc[embed.fieldName] = this.createEmbeddedDocument(pgRow, embed);
      }
    }

    // Add metadata
    mongoDoc._migrationId = pgRow.id;
    mongoDoc._migratedAt = new Date();

    return mongoDoc;
  }

  private transformValue(value: any, targetType?: string): any {
    if (value === null || value === undefined) return value;

    switch (targetType) {
      case 'objectId':
        return new ObjectId(); // Generate new ObjectId for UUID fields
      case 'date':
        return new Date(value);
      case 'decimal':
        return parseFloat(value);
      case 'int':
        return parseInt(value);
      default:
        return value;
    }
  }

  private createMongoDBWriteStream(collectionName: string) {
    const collection = this.mongoClient.db().collection(collectionName);
    const batch: any[] = [];

    return new Transform({
      objectMode: true,
      async transform(mongoDoc, encoding, callback) {
        batch.push(mongoDoc);

        if (batch.length >= this.batchSize) {
          try {
            await collection.insertMany(batch.splice(0, this.batchSize), {
              ordered: false,
              writeConcern: { w: 1, j: false } // Optimize for speed
            });
            callback();
          } catch (error) {
            callback(error);
          }
        } else {
          callback();
        }
      },
      
      async flush(callback) {
        if (batch.length > 0) {
          try {
            await collection.insertMany(batch, {
              ordered: false,
              writeConcern: { w: 1, j: true } // Ensure durability for final batch
            });
            callback();
          } catch (error) {
            callback(error);
          }
        } else {
          callback();
        }
      }
    });
  }
}

// Usage example
const migrator = new PostgreSQLToMongoMigrator(
  pgConfig,
  mongoConfig
);

const migrationPlan: MigrationPlan = {
  tables: [
    {
      sourceName: 'users',
      targetCollection: 'users',
      transformation: {
        fieldMappings: {
          'id': '_id',
          'first_name': 'firstName',
          'last_name': 'lastName',
          'created_at': 'createdAt'
        },
        dataTypes: {
          '_id': 'objectId',
          'createdAt': 'date'
        },
        embeddedDocuments: [
          {
            fieldName: 'profile',
            sourceQuery: 'SELECT bio, avatar_url FROM user_profiles WHERE user_id = ?',
            fieldMappings: {
              'bio': 'bio',
              'avatar_url': 'avatarUrl'
            }
          }
        ]
      }
    }
  ]
};

await migrator.migrate(migrationPlan);
```

## 🔄 MongoDB to PostgreSQL Migration

### Document to Relational Normalization

#### Schema Normalization Strategy
```typescript
// MongoDB to PostgreSQL schema normalization
class MongoToPostgreSQLTransformer {
  private normalizations = {
    // Flatten embedded documents into separate tables
    embedToTable: 'separate_table',
    // Keep simple embedded documents as JSONB
    embedToJsonb: 'jsonb_column',
    // Arrays to junction tables
    arrayToJunction: 'junction_table'
  };

  transformSchema(mongoSchema: MongoSchema): PostgreSQLSchema {
    const tables: TableDefinition[] = [];
    const relationships: Relationship[] = [];

    for (const collection of mongoSchema.collections) {
      const mainTable = this.createMainTable(collection);
      tables.push(mainTable);

      // Handle embedded documents
      for (const embedded of collection.embeddedDocuments || []) {
        if (this.shouldNormalizeToTable(embedded)) {
          const embeddedTable = this.createEmbeddedTable(collection.name, embedded);
          tables.push(embeddedTable);
          
          relationships.push({
            from: embeddedTable.name,
            to: mainTable.name,
            type: 'many_to_one',
            foreignKey: `${collection.name}_id`
          });
        }
      }

      // Handle arrays
      for (const arrayField of collection.arrayFields || []) {
        if (this.shouldCreateJunctionTable(arrayField)) {
          const junctionTable = this.createJunctionTable(collection.name, arrayField);
          tables.push(junctionTable);
          
          relationships.push({
            from: junctionTable.name,
            to: mainTable.name,
            type: 'many_to_one',
            foreignKey: `${collection.name}_id`
          });
        }
      }
    }

    return { tables, relationships };
  }

  private createMainTable(collection: CollectionDefinition): TableDefinition {
    const columns: ColumnDefinition[] = [
      {
        name: 'id',
        dataType: 'UUID',
        nullable: false,
        primaryKey: true,
        defaultValue: 'uuid_generate_v4()'
      }
    ];

    // Transform basic fields
    for (const [fieldName, fieldDef] of Object.entries(collection.fields)) {
      if (!this.isComplexField(fieldDef)) {
        columns.push({
          name: this.toSnakeCase(fieldName),
          dataType: this.mapMongoTypeToPostgreSQL(fieldDef.bsonType),
          nullable: !fieldDef.required,
          constraints: this.generateConstraints(fieldDef)
        });
      }
    }

    // Keep complex embedded documents as JSONB
    for (const embedded of collection.embeddedDocuments || []) {
      if (!this.shouldNormalizeToTable(embedded)) {
        columns.push({
          name: this.toSnakeCase(embedded.name),
          dataType: 'JSONB',
          nullable: true
        });
      }
    }

    // Add audit fields
    columns.push(
      {
        name: 'created_at',
        dataType: 'TIMESTAMP WITH TIME ZONE',
        nullable: false,
        defaultValue: 'NOW()'
      },
      {
        name: 'updated_at',
        dataType: 'TIMESTAMP WITH TIME ZONE',
        nullable: false,
        defaultValue: 'NOW()'
      }
    );

    return {
      name: this.toSnakeCase(collection.name),
      columns,
      indexes: this.generateIndexes(collection),
      constraints: this.generateTableConstraints(collection)
    };
  }

  private mapMongoTypeToPostgreSQL(bsonType: string): string {
    const typeMap = {
      'string': 'VARCHAR(255)',
      'int': 'INTEGER',
      'long': 'BIGINT',
      'double': 'DOUBLE PRECISION',
      'decimal': 'DECIMAL(10,2)',
      'bool': 'BOOLEAN',
      'date': 'TIMESTAMP WITH TIME ZONE',
      'objectId': 'UUID',
      'object': 'JSONB',
      'array': 'JSONB'
    };

    return typeMap[bsonType] || 'TEXT';
  }

  private shouldNormalizeToTable(embedded: EmbeddedDocument): boolean {
    // Normalize if embedded document has many fields or is frequently queried
    return embedded.fields && Object.keys(embedded.fields).length > 5;
  }

  private toSnakeCase(str: string): string {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }
}
```

### Data Migration Pipeline for MongoDB to PostgreSQL

```typescript
class MongoToPostgreSQLMigrator {
  private mongoClient: MongoClient;
  private pgPool: Pool;

  constructor(mongoConfig: any, pgConfig: any) {
    this.mongoClient = new MongoClient(mongoConfig.connectionString);
    this.pgPool = new Pool(pgConfig);
  }

  async migrate(migrationPlan: MigrationPlan): Promise<MigrationResult> {
    console.log('🚀 Starting MongoDB to PostgreSQL migration...');

    try {
      await this.mongoClient.connect();
      
      // Create PostgreSQL schema first
      await this.createPostgreSQLSchema(migrationPlan.schema);
      
      // Migrate data collection by collection
      for (const collectionConfig of migrationPlan.collections) {
        await this.migrateCollection(collectionConfig);
      }

      console.log('✅ Migration completed successfully');
      
    } catch (error) {
      console.error('❌ Migration failed:', error);
      throw error;
    }
  }

  private async migrateCollection(config: CollectionMigrationConfig) {
    const { collectionName, targetTables, transformation } = config;
    
    console.log(`📋 Processing collection: ${collectionName}`);
    
    const collection = this.mongoClient.db().collection(collectionName);
    const totalDocs = await collection.countDocuments();
    
    console.log(`📊 Total documents: ${totalDocs}`);

    let processed = 0;
    const batchSize = 1000;

    // Process in batches using cursor
    const cursor = collection.find({}).batchSize(batchSize);
    
    while (await cursor.hasNext()) {
      const batch = [];
      
      // Collect batch
      for (let i = 0; i < batchSize && await cursor.hasNext(); i++) {
        const doc = await cursor.next();
        if (doc) batch.push(doc);
      }

      // Transform and insert batch
      await this.processBatch(batch, targetTables, transformation);
      
      processed += batch.length;
      
      const progress = (processed / totalDocs * 100).toFixed(2);
      console.log(`📈 Progress: ${progress}% (${processed}/${totalDocs})`);
    }

    console.log(`✅ Completed ${collectionName}: ${processed} documents processed`);
  }

  private async processBatch(
    docs: any[], 
    targetTables: string[], 
    transformation: TransformationConfig
  ) {
    const client = await this.pgPool.connect();
    
    try {
      await client.query('BEGIN');

      for (const doc of docs) {
        await this.migrateDocument(client, doc, targetTables, transformation);
      }

      await client.query('COMMIT');
      
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async migrateDocument(
    client: any,
    doc: any,
    targetTables: string[],
    transformation: TransformationConfig
  ) {
    // Generate new UUID for the main record
    const mainRecordId = uuidv4();
    
    // Insert main table record
    const mainTableData = this.transformMainDocument(doc, transformation.mainTable);
    mainTableData.id = mainRecordId;
    
    await this.insertRecord(client, transformation.mainTable.tableName, mainTableData);

    // Handle embedded documents that became separate tables
    for (const embeddedConfig of transformation.embeddedTables || []) {
      const embeddedData = doc[embeddedConfig.sourceField];
      
      if (embeddedData) {
        if (Array.isArray(embeddedData)) {
          // Handle arrays of embedded documents
          for (const item of embeddedData) {
            const normalizedData = this.transformEmbeddedDocument(
              item, 
              embeddedConfig, 
              mainRecordId
            );
            await this.insertRecord(client, embeddedConfig.tableName, normalizedData);
          }
        } else {
          // Handle single embedded document
          const normalizedData = this.transformEmbeddedDocument(
            embeddedData, 
            embeddedConfig, 
            mainRecordId
          );
          await this.insertRecord(client, embeddedConfig.tableName, normalizedData);
        }
      }
    }
  }

  private transformMainDocument(doc: any, config: MainTableConfig): any {
    const transformed: any = {};

    // Map simple fields
    for (const [mongoField, pgField] of Object.entries(config.fieldMappings)) {
      if (doc[mongoField] !== undefined) {
        transformed[pgField] = this.transformValue(doc[mongoField], config.dataTypes?.[pgField]);
      }
    }

    // Keep complex fields as JSONB
    for (const jsonbField of config.jsonbFields || []) {
      if (doc[jsonbField.sourceField] !== undefined) {
        transformed[jsonbField.targetField] = JSON.stringify(doc[jsonbField.sourceField]);
      }
    }

    // Add metadata
    transformed.created_at = doc.createdAt || doc._id.getTimestamp();
    transformed.updated_at = doc.updatedAt || doc.createdAt || doc._id.getTimestamp();

    return transformed;
  }

  private transformEmbeddedDocument(
    embeddedDoc: any, 
    config: EmbeddedTableConfig, 
    parentId: string
  ): any {
    const transformed: any = {
      id: uuidv4(),
      [config.foreignKeyField]: parentId
    };

    // Map embedded document fields
    for (const [sourceField, targetField] of Object.entries(config.fieldMappings)) {
      if (embeddedDoc[sourceField] !== undefined) {
        transformed[targetField] = this.transformValue(
          embeddedDoc[sourceField], 
          config.dataTypes?.[targetField]
        );
      }
    }

    return transformed;
  }

  private async insertRecord(client: any, tableName: string, data: any) {
    const fields = Object.keys(data);
    const values = Object.values(data);
    const placeholders = fields.map((_, index) => `$${index + 1}`).join(', ');
    
    const query = `
      INSERT INTO ${tableName} (${fields.join(', ')}) 
      VALUES (${placeholders})
    `;
    
    await client.query(query, values);
  }

  private transformValue(value: any, targetType?: string): any {
    if (value === null || value === undefined) return null;

    switch (targetType) {
      case 'uuid':
        // Convert ObjectId to UUID or generate new UUID
        return uuidv4();
      case 'timestamp':
        return new Date(value);
      case 'decimal':
        return parseFloat(value);
      case 'integer':
        return parseInt(value);
      case 'jsonb':
        return JSON.stringify(value);
      default:
        return value;
    }
  }
}
```

## 🔄 Zero-Downtime Migration Strategies

### Blue-Green Deployment Migration

```typescript
// Blue-Green migration implementation
class BlueGreenMigrator {
  private currentDb: DatabaseConnection;
  private newDb: DatabaseConnection;
  private applicationGateway: ApplicationGateway;

  constructor(current: DatabaseConnection, target: DatabaseConnection) {
    this.currentDb = current;
    this.newDb = target;
    this.applicationGateway = new ApplicationGateway();
  }

  async executeBlueGreenMigration(plan: MigrationPlan): Promise<void> {
    console.log('🔵 Starting Blue-Green migration...');

    try {
      // Phase 1: Setup new database (Green)
      console.log('📋 Phase 1: Setting up Green environment...');
      await this.setupGreenEnvironment(plan);

      // Phase 2: Initial data sync
      console.log('📋 Phase 2: Initial data synchronization...');
      await this.initialDataSync(plan);

      // Phase 3: Enable dual-write mode
      console.log('📋 Phase 3: Enabling dual-write mode...');
      await this.enableDualWrite();

      // Phase 4: Incremental sync
      console.log('📋 Phase 4: Incremental synchronization...');
      await this.incrementalSync(plan);

      // Phase 5: Data validation
      console.log('📋 Phase 5: Data validation...');
      const validationResult = await this.validateData(plan);
      
      if (!validationResult.isValid) {
        throw new Error(`Data validation failed: ${validationResult.errors.join(', ')}`);
      }

      // Phase 6: Switch traffic to Green
      console.log('📋 Phase 6: Switching traffic to Green...');
      await this.switchToGreen();

      // Phase 7: Monitor and validate
      console.log('📋 Phase 7: Monitoring new environment...');
      await this.monitorGreenEnvironment();

      console.log('✅ Blue-Green migration completed successfully!');

    } catch (error) {
      console.error('❌ Migration failed, rolling back...');
      await this.rollbackToBlue();
      throw error;
    }
  }

  private async setupGreenEnvironment(plan: MigrationPlan): Promise<void> {
    // Create schema in new database
    await this.newDb.createSchema(plan.schema);
    
    // Create indexes
    await this.newDb.createIndexes(plan.indexes);
    
    // Setup monitoring
    await this.setupMonitoring(this.newDb);
  }

  private async initialDataSync(plan: MigrationPlan): Promise<void> {
    // Snapshot current data and migrate to new database
    const snapshot = await this.currentDb.createSnapshot();
    
    for (const table of plan.tables) {
      console.log(`📊 Syncing ${table.name}...`);
      
      const data = await this.currentDb.extractTable(table.name);
      const transformedData = await this.transformData(data, table.transformation);
      await this.newDb.loadData(table.targetName, transformedData);
      
      console.log(`✅ Synced ${table.name}: ${data.length} records`);
    }
  }

  private async enableDualWrite(): Promise<void> {
    // Configure application to write to both databases
    await this.applicationGateway.enableDualWrite({
      primary: this.currentDb,
      secondary: this.newDb,
      writeMode: 'best_effort', // Don't fail if secondary write fails
      consistency: 'eventually_consistent'
    });
  }

  private async incrementalSync(plan: MigrationPlan): Promise<void> {
    // Sync changes that occurred during initial migration
    const changeLog = await this.currentDb.getChangesSince(plan.syncPoint);
    
    for (const change of changeLog) {
      try {
        await this.applyChangeToGreen(change, plan);
      } catch (error) {
        console.warn(`Failed to sync change ${change.id}:`, error);
        // Store failed changes for manual review
        await this.logFailedChange(change, error);
      }
    }
  }

  private async validateData(plan: MigrationPlan): Promise<ValidationResult> {
    const errors: string[] = [];
    let totalRecords = 0;
    let validatedRecords = 0;

    for (const table of plan.tables) {
      console.log(`🔍 Validating ${table.name}...`);
      
      const currentCount = await this.currentDb.getRecordCount(table.name);
      const newCount = await this.newDb.getRecordCount(table.targetName);
      
      totalRecords += currentCount;
      validatedRecords += newCount;

      if (Math.abs(currentCount - newCount) > plan.acceptableDiscrepancy) {
        errors.push(`Record count mismatch in ${table.name}: ${currentCount} vs ${newCount}`);
      }

      // Sample data validation
      const sampleValidation = await this.validateSampleData(table, 100);
      if (!sampleValidation.isValid) {
        errors.push(...sampleValidation.errors);
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
      totalRecords,
      validatedRecords,
      accuracy: validatedRecords / totalRecords
    };
  }

  private async switchToGreen(): Promise<void> {
    // Gradually shift traffic to new database
    const trafficShiftPlan = [
      { percentage: 1, duration: 300 },   // 1% for 5 minutes
      { percentage: 5, duration: 300 },   // 5% for 5 minutes
      { percentage: 25, duration: 600 },  // 25% for 10 minutes
      { percentage: 50, duration: 600 },  // 50% for 10 minutes
      { percentage: 100, duration: 0 }    // 100% immediately
    ];

    for (const phase of trafficShiftPlan) {
      console.log(`🔄 Shifting ${phase.percentage}% traffic to Green...`);
      
      await this.applicationGateway.setTrafficSplit({
        blue: 100 - phase.percentage,
        green: phase.percentage
      });

      if (phase.duration > 0) {
        await this.sleep(phase.duration * 1000);
        
        // Monitor for errors during traffic shift
        const healthCheck = await this.checkGreenHealth();
        if (!healthCheck.healthy) {
          throw new Error(`Green environment unhealthy: ${healthCheck.issues.join(', ')}`);
        }
      }
    }

    // Finalize switch
    await this.applicationGateway.setTrafficSplit({ blue: 0, green: 100 });
    console.log('✅ Traffic fully switched to Green environment');
  }

  private async rollbackToBlue(): Promise<void> {
    console.log('🔙 Rolling back to Blue environment...');
    
    await this.applicationGateway.setTrafficSplit({ blue: 100, green: 0 });
    await this.applicationGateway.disableDualWrite();
    
    console.log('✅ Rollback completed');
  }

  private async monitorGreenEnvironment(): Promise<void> {
    // Monitor for 30 minutes after switch
    const monitoringDuration = 30 * 60 * 1000; // 30 minutes
    const checkInterval = 60 * 1000; // 1 minute
    const endTime = Date.now() + monitoringDuration;

    while (Date.now() < endTime) {
      const health = await this.checkGreenHealth();
      
      if (!health.healthy) {
        console.warn('⚠️ Green environment issues detected:', health.issues);
        // Could trigger automatic rollback here if issues are severe
      }

      await this.sleep(checkInterval);
    }

    // Cleanup Blue environment if everything is stable
    console.log('🧹 Green environment stable, scheduling Blue cleanup...');
    await this.scheduleBlueCleanup();
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

### Change Data Capture (CDC) for Real-time Sync

```typescript
// CDC implementation for real-time synchronization
class CDCMigrator {
  private sourceDb: DatabaseConnection;
  private targetDb: DatabaseConnection;
  private cdcStream: EventEmitter;

  constructor(source: DatabaseConnection, target: DatabaseConnection) {
    this.sourceDb = source;
    this.targetDb = target;
    this.cdcStream = new EventEmitter();
  }

  async startRealtimeSync(config: CDCConfig): Promise<void> {
    console.log('🔄 Starting real-time CDC synchronization...');

    // Setup CDC listeners based on database type
    if (this.sourceDb.type === 'postgresql') {
      await this.setupPostgreSQLCDC(config);
    } else if (this.sourceDb.type === 'mongodb') {
      await this.setupMongoCDC(config);
    }

    // Setup change processors
    this.cdcStream.on('insert', (change) => this.processInsert(change));
    this.cdcStream.on('update', (change) => this.processUpdate(change));
    this.cdcStream.on('delete', (change) => this.processDelete(change));

    console.log('✅ Real-time sync started');
  }

  private async setupPostgreSQLCDC(config: CDCConfig): Promise<void> {
    // Use PostgreSQL logical replication
    const { Client } = require('pg');
    const client = new Client(config.sourceConnection);
    
    await client.connect();

    // Create replication slot
    await client.query(`
      SELECT pg_create_logical_replication_slot('migration_slot', 'pgoutput')
    `);

    // Start replication stream
    const replicationClient = new Client({
      ...config.sourceConnection,
      replication: 'database'
    });

    await replicationClient.connect();

    replicationClient.on('replicationMessage', (msg) => {
      const change = this.parsePostgreSQLChange(msg);
      this.cdcStream.emit(change.operation, change);
    });

    await replicationClient.query(`
      START_REPLICATION SLOT migration_slot LOGICAL 0/0
    `);
  }

  private async setupMongoCDC(config: CDCConfig): Promise<void> {
    // Use MongoDB Change Streams
    const db = this.sourceDb.getDatabase();
    
    for (const collection of config.collections) {
      const changeStream = db.collection(collection).watch(
        [], // Watch all changes
        { 
          fullDocument: 'updateLookup',
          resumeAfter: config.resumeToken // For resumability
        }
      );

      changeStream.on('change', (change) => {
        const normalizedChange = this.normalizeMongoChange(change, collection);
        this.cdcStream.emit(normalizedChange.operation, normalizedChange);
      });

      changeStream.on('error', (error) => {
        console.error(`Change stream error for ${collection}:`, error);
        // Implement retry logic
        setTimeout(() => this.setupMongoCDC(config), 5000);
      });
    }
  }

  private async processInsert(change: ChangeEvent): Promise<void> {
    try {
      const transformedData = await this.transformChange(change);
      await this.targetDb.insert(change.table, transformedData);
      
      console.log(`✅ Processed INSERT: ${change.table}/${change.recordId}`);
    } catch (error) {
      console.error(`❌ Failed to process INSERT:`, error);
      await this.handleSyncError(change, error);
    }
  }

  private async processUpdate(change: ChangeEvent): Promise<void> {
    try {
      const transformedData = await this.transformChange(change);
      await this.targetDb.update(change.table, change.recordId, transformedData);
      
      console.log(`✅ Processed UPDATE: ${change.table}/${change.recordId}`);
    } catch (error) {
      console.error(`❌ Failed to process UPDATE:`, error);
      await this.handleSyncError(change, error);
    }
  }

  private async processDelete(change: ChangeEvent): Promise<void> {
    try {
      await this.targetDb.delete(change.table, change.recordId);
      console.log(`✅ Processed DELETE: ${change.table}/${change.recordId}`);
    } catch (error) {
      console.error(`❌ Failed to process DELETE:`, error);
      await this.handleSyncError(change, error);
    }
  }

  private async handleSyncError(change: ChangeEvent, error: Error): Promise<void> {
    // Log error for manual review
    await this.logSyncError({
      change,
      error: error.message,
      timestamp: new Date(),
      retryCount: change.retryCount || 0
    });

    // Implement retry logic with exponential backoff
    if ((change.retryCount || 0) < 3) {
      const delay = Math.pow(2, change.retryCount || 0) * 1000; // 1s, 2s, 4s
      
      setTimeout(() => {
        change.retryCount = (change.retryCount || 0) + 1;
        this.cdcStream.emit(change.operation, change);
      }, delay);
    }
  }
}
```

This comprehensive migration strategy guide provides detailed approaches for various migration scenarios, emphasizing zero-downtime strategies crucial for production EdTech applications.

---

⬅️ **[Previous: Security Considerations](./security-considerations.md)**  
➡️ **[Next: Testing Strategies](./testing-strategies.md)**  
🏠 **[Research Home](../../README.md)**

---

*Migration Strategy - Comprehensive database migration and data transfer methodologies*