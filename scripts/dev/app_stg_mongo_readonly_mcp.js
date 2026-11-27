#!/usr/bin/env node
"use strict";

const { MongoClient, ObjectID } = require("mongodb");

const TOOL_CONNECT = "connect";
const TOOL_LIST_DATABASES = "list-databases";
const TOOL_LIST_COLLECTIONS = "list-collections";
const TOOL_FIND = "find";
const TOOL_COUNT = "count";
const TOOL_AGGREGATE = "aggregate";
const TOOL_EXPLAIN = "explain";
const TOOL_COLLECTION_INDEXES = "collection-indexes";
const TOOL_COLLECTION_SCHEMA = "collection-schema";
const TOOL_COLLECTION_STORAGE_SIZE = "collection-storage-size";
const TOOL_DB_STATS = "db-stats";

const defaultPort = process.env.APP_STG_MONGO_LOCAL_PORT || "37017";
const defaultDatabase = process.env.APP_STG_MONGO_DATABASE || "mp";
const mongoUrl = process.env.APP_STG_MONGO_URL || buildMongoUrl();
const readPreference = process.env.APP_STG_MONGO_READ_PREFERENCE || "secondaryPreferred";

let stdinBuffer = Buffer.alloc(0);
let mongoClient;

function buildMongoUrl() {
  const host = process.env.APP_STG_MONGO_HOST || "127.0.0.1";
  const authSource = process.env.APP_STG_MONGO_AUTH_SOURCE || "admin";
  const username = process.env.APP_STG_MONGO_USER || "connect_api";
  const password = process.env.APP_STG_MONGO_PASSWORD || "";

  if (!password) {
    return `mongodb://${host}:${defaultPort}/${defaultDatabase}?authSource=${authSource}`;
  }

  return [
    "mongodb://",
    encodeURIComponent(username),
    ":",
    encodeURIComponent(password),
    `@${host}:${defaultPort}/${defaultDatabase}?authSource=`,
    encodeURIComponent(authSource),
  ].join("");
}

function writeMessage(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function parseJsonObject(value, name) {
  if (value === undefined || value === null || value === "") {
    return {};
  }
  if (typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  if (typeof value !== "string") {
    throw new Error(`${name} must be an object or JSON object string`);
  }
  const parsed = JSON.parse(value);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${name} must be a JSON object`);
  }
  return parsed;
}

function parseJsonArray(value, name) {
  if (typeof value === "string") {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      throw new Error(`${name} must be a JSON array`);
    }
    return parsed;
  }
  if (!Array.isArray(value)) {
    throw new Error(`${name} must be an array or JSON array string`);
  }
  return value;
}

function reviveObjectIds(value) {
  if (Array.isArray(value)) {
    return value.map(reviveObjectIds);
  }
  if (!value || typeof value !== "object") {
    return value;
  }
  if (typeof value.$oid === "string" && Object.keys(value).length === 1) {
    return ObjectID(value.$oid);
  }
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, reviveObjectIds(item)]),
  );
}

function assertName(value, name) {
  if (!/^[A-Za-z0-9_.-]+$/.test(value || "")) {
    throw new Error(`${name} contains unsupported characters`);
  }
}

function assertReadonlyPipeline(pipeline) {
  const forbiddenStages = new Set([
    "$out",
    "$merge",
    "$currentOp",
    "$listSessions",
    "$planCacheStats",
  ]);

  for (const stage of pipeline) {
    if (!stage || typeof stage !== "object" || Array.isArray(stage)) {
      throw new Error("Each aggregation pipeline stage must be an object");
    }
    for (const key of Object.keys(stage)) {
      if (forbiddenStages.has(key)) {
        throw new Error(`Aggregation stage ${key} is not allowed in read-only mode`);
      }
    }
  }
}

function collectionNamespace(args) {
  assertName(args.database, "database");
  assertName(args.collection, "collection");
  return [args.database, args.collection];
}

function parseLimit(value, defaultValue, maxValue) {
  return Math.min(Math.max(Number(value || defaultValue), 1), maxValue);
}

async function getClient() {
  if (mongoClient && mongoClient.isConnected()) {
    await assertConnectedToSecondary(mongoClient);
    return mongoClient;
  }

  mongoClient = await MongoClient.connect(mongoUrl, {
    connectTimeoutMS: 5000,
    readPreference,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 30000,
    useNewUrlParser: true,
    useUnifiedTopology: false,
  });
  await assertConnectedToSecondary(mongoClient);
  return mongoClient;
}

function formatToolError(error) {
  if (/ECONNREFUSED 127\.0\.0\.1:37017|connect EPERM 127\.0\.0\.1:37017/.test(error.message)) {
    return (
      `${error.message}\n\n` +
      "The MCP wrapper is not a transport fallback. It connects through the same local staging tunnel. " +
      "Run scripts/dev/app_stg_mongo_tunnel.sh, verify with scripts/dev/app_stg_mongo_tunnel.sh --status, then retry the MCP tool."
    );
  }
  return error.message;
}

async function assertConnectedToSecondary(client) {
  const status = await client.db("admin").command({ isMaster: 1 });
  if (status.ismaster === true) {
    throw new Error(
      `Refusing to query staging MongoDB primary ${status.me || "unknown member"}. ` +
        "Restart the staging MongoDB tunnel so it can select a secondary.",
    );
  }
  if (status.secondary !== true) {
    throw new Error(
      `Connected MongoDB member ${status.me || "unknown member"} is not reporting as secondary.`,
    );
  }
}

async function listDatabases() {
  const client = await getClient();
  try {
    const result = await client.db("admin").admin().listDatabases();
    return {
      databases: result.databases.map((database) => ({
        name: database.name,
        sizeOnDisk: database.sizeOnDisk,
        empty: database.empty,
      })),
      complete: true,
    };
  } catch (error) {
    if (!/not authorized/i.test(error.message)) {
      throw error;
    }
    return {
      databases: [{ name: defaultDatabase }],
      complete: false,
      note: "Database enumeration is not authorized; returned the configured database only.",
    };
  }
}

async function listCollections(args) {
  assertName(args.database, "database");
  const client = await getClient();
  const collections = await client
    .db(args.database)
    .listCollections({}, { nameOnly: true })
    .toArray();
  return collections.map((collection) => collection.name);
}

async function findDocuments(args) {
  const [database, collection] = collectionNamespace(args);

  const filter = reviveObjectIds(parseJsonObject(args.filter, "filter"));
  const projection = reviveObjectIds(parseJsonObject(args.projection, "projection"));
  const limit = parseLimit(args.limit, 20, 100);

  const client = await getClient();
  return client
    .db(database)
    .collection(collection)
    .find(filter, { projection })
    .limit(limit)
    .toArray();
}

async function countDocuments(args) {
  const [database, collection] = collectionNamespace(args);

  const filter = reviveObjectIds(parseJsonObject(args.filter, "filter"));
  const client = await getClient();
  return {
    count: await client.db(database).collection(collection).countDocuments(filter),
  };
}

async function aggregateDocuments(args) {
  const [database, collection] = collectionNamespace(args);

  const pipeline = reviveObjectIds(parseJsonArray(args.pipeline, "pipeline"));
  assertReadonlyPipeline(pipeline);
  const limit = parseLimit(args.limit, 20, 100);

  const client = await getClient();
  const limitedPipeline = pipeline.some((stage) => Object.hasOwn(stage, "$limit"))
    ? pipeline
    : [...pipeline, { $limit: limit }];

  return client
    .db(database)
    .collection(collection)
    .aggregate(limitedPipeline, { allowDiskUse: false })
    .toArray();
}

async function explainQuery(args) {
  const [database, collection] = collectionNamespace(args);
  const client = await getClient();
  const coll = client.db(database).collection(collection);
  const method = args.method || "find";
  if (method === "aggregate") {
    const pipeline = reviveObjectIds(parseJsonArray(args.pipeline, "pipeline"));
    assertReadonlyPipeline(pipeline);
    return coll.aggregate(pipeline, { allowDiskUse: false }).explain();
  }
  const filter = reviveObjectIds(parseJsonObject(args.filter, "filter"));
  const projection = reviveObjectIds(parseJsonObject(args.projection, "projection"));
  return coll.find(filter, { projection }).limit(parseLimit(args.limit, 20, 100)).explain();
}

async function collectionIndexes(args) {
  const [database, collection] = collectionNamespace(args);
  const client = await getClient();
  return client.db(database).collection(collection).listIndexes().toArray();
}

function valueType(value) {
  if (value === null) return "null";
  if (value instanceof ObjectID) return "objectId";
  if (value instanceof Date) return "date";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

function collectSchema(value, prefix, fields) {
  if (!value || typeof value !== "object" || Array.isArray(value) || value instanceof ObjectID) return;
  for (const [key, item] of Object.entries(value)) {
    const path = prefix ? `${prefix}.${key}` : key;
    const entry = fields.get(path) || { path, types: new Set(), appearances: 0 };
    entry.types.add(valueType(item));
    entry.appearances += 1;
    fields.set(path, entry);
    collectSchema(item, path, fields);
  }
}

async function collectionSchema(args) {
  const [database, collection] = collectionNamespace(args);
  const sampleSize = parseLimit(args.sampleSize || args.sample_size, 50, 200);
  const client = await getClient();
  const docs = await client.db(database).collection(collection).find({}).limit(sampleSize).toArray();
  const fields = new Map();
  for (const doc of docs) collectSchema(doc, "", fields);
  return {
    sampledDocuments: docs.length,
    fields: [...fields.values()].map((field) => ({
      path: field.path,
      types: [...field.types].sort(),
      appearances: field.appearances,
    })).sort((left, right) => left.path.localeCompare(right.path)),
  };
}

async function collectionStorageSize(args) {
  const [database, collection] = collectionNamespace(args);
  const client = await getClient();
  const stats = await client.db(database).command({ collStats: collection, scale: 1024 * 1024 });
  return { storageSizeMB: stats.storageSize, sizeMB: stats.size, count: stats.count };
}

async function dbStats(args) {
  assertName(args.database, "database");
  const client = await getClient();
  return client.db(args.database).command({ dbStats: 1, scale: 1024 * 1024 });
}

async function connectInfo() {
  const client = await getClient();
  const status = await client.db("admin").command({ isMaster: 1 });
  return { connected: true, setName: status.setName, member: status.me, secondary: status.secondary === true };
}

function tool(name, description, properties = {}, required = []) {
  return { name, description, inputSchema: { type: "object", properties, required, additionalProperties: false } };
}

const namespaceProps = { database: { type: "string" }, collection: { type: "string" } };
const filterProps = {
  ...namespaceProps,
  filter: { description: "MongoDB filter object or JSON string. Extended ObjectId form {$oid: ...} is supported." },
  projection: { description: "MongoDB projection object or JSON string." },
  limit: { type: "integer", minimum: 1, maximum: 100 },
};

const toolDefinitions = [
  tool(TOOL_CONNECT, "Verify the staging MongoDB connection without returning secrets."),
  tool(TOOL_LIST_DATABASES, "List databases visible through the staging MongoDB tunnel; falls back to the configured database if enumeration is not authorized."),
  tool(TOOL_LIST_COLLECTIONS, "List collections in one staging MongoDB database.", { database: { type: "string" } }, ["database"]),
  tool(TOOL_FIND, "Run a read-only MongoDB find query; returns at most 100 documents.", filterProps, ["database", "collection"]),
  tool(TOOL_COUNT, "Return the number of documents in a collection.", filterProps, ["database", "collection"]),
  tool(TOOL_AGGREGATE, "Run a read-only aggregation pipeline. Blocks write/admin stages.", {
    ...namespaceProps,
    pipeline: { description: "MongoDB aggregation pipeline array or JSON string." },
    limit: { type: "integer", minimum: 1, maximum: 100 },
  }, ["database", "collection", "pipeline"]),
  tool(TOOL_EXPLAIN, "Return query planner statistics for a find or aggregation.", {
    ...filterProps,
    method: { type: "string", enum: ["find", "aggregate"] },
    pipeline: { description: "Aggregation pipeline array or JSON string when method is aggregate." },
  }, ["database", "collection"]),
  tool(TOOL_COLLECTION_INDEXES, "Return index information for a collection.", namespaceProps, ["database", "collection"]),
  tool(TOOL_COLLECTION_SCHEMA, "Infer collection schema from a small sample without returning document values.", {
    ...namespaceProps,
    sampleSize: { type: "integer", minimum: 1, maximum: 200 },
  }, ["database", "collection"]),
  tool(TOOL_COLLECTION_STORAGE_SIZE, "Return collection storage size in megabytes.", namespaceProps, ["database", "collection"]),
  tool(TOOL_DB_STATS, "Return database statistics.", { database: { type: "string" } }, ["database"]),
];

async function callTool(name, args) {
  if (name === TOOL_CONNECT) return connectInfo();
  if (name === TOOL_LIST_DATABASES) return listDatabases();
  if (name === TOOL_LIST_COLLECTIONS) return listCollections(args);
  if (name === TOOL_FIND) return findDocuments(args);
  if (name === TOOL_COUNT) return countDocuments(args);
  if (name === TOOL_AGGREGATE) return aggregateDocuments(args);
  if (name === TOOL_EXPLAIN) return explainQuery(args);
  if (name === TOOL_COLLECTION_INDEXES) return collectionIndexes(args);
  if (name === TOOL_COLLECTION_SCHEMA) return collectionSchema(args);
  if (name === TOOL_COLLECTION_STORAGE_SIZE) return collectionStorageSize(args);
  if (name === TOOL_DB_STATS) return dbStats(args);
  throw new Error(`Unknown tool: ${name}`);
}

async function handleRequest(message) {
  const requestId = message.id;

  if (message.method === "initialize") {
    return {
      jsonrpc: "2.0",
      id: requestId,
      result: {
        protocolVersion: "2025-06-18",
        serverInfo: {
          name: "app-stg-mongo-readonly-local",
          version: "0.1.0",
        },
        capabilities: { tools: {} },
      },
    };
  }

  if (message.method === "notifications/initialized") {
    return null;
  }

  if (message.method === "ping") {
    return { jsonrpc: "2.0", id: requestId, result: {} };
  }

  if (message.method === "tools/list") {
    return { jsonrpc: "2.0", id: requestId, result: { tools: toolDefinitions } };
  }

  if (message.method === "tools/call") {
    try {
      const params = message.params || {};
      const result = await callTool(params.name, params.arguments || {});
      return {
        jsonrpc: "2.0",
        id: requestId,
        result: {
          content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
          structuredContent: { result },
        },
      };
    } catch (error) {
      return {
        jsonrpc: "2.0",
        id: requestId,
        result: {
          content: [{ type: "text", text: formatToolError(error) }],
          isError: true,
        },
      };
    }
  }

  return {
    jsonrpc: "2.0",
    id: requestId,
    error: { code: -32601, message: `Method not found: ${message.method}` },
  };
}

async function processMessage(message) {
  const response = await handleRequest(message);
  if (response) {
    writeMessage(response);
  }
}

function handleLineProtocol() {
  const newline = stdinBuffer.indexOf(10);
  if (newline === -1) {
    return false;
  }
  const line = stdinBuffer.subarray(0, newline).toString("utf8").trim();
  stdinBuffer = stdinBuffer.subarray(newline + 1);
  if (line) {
    processMessage(JSON.parse(line)).catch((error) => {
      writeMessage({ jsonrpc: "2.0", id: null, error: { code: -32603, message: error.message } });
    });
  }
  return true;
}

function handleHeaderProtocol() {
  const headerEnd = stdinBuffer.indexOf("\r\n\r\n");
  const separatorLength = headerEnd === -1 ? 2 : 4;
  const effectiveHeaderEnd = headerEnd === -1 ? stdinBuffer.indexOf("\n\n") : headerEnd;
  if (effectiveHeaderEnd === -1) {
    return false;
  }

  const headers = stdinBuffer.subarray(0, effectiveHeaderEnd).toString("utf8");
  const match = headers.match(/content-length:\s*(\d+)/i);
  if (!match) {
    throw new Error("Missing Content-Length header");
  }

  const contentLength = Number(match[1]);
  const bodyStart = effectiveHeaderEnd + separatorLength;
  const bodyEnd = bodyStart + contentLength;
  if (stdinBuffer.length < bodyEnd) {
    return false;
  }

  const body = stdinBuffer.subarray(bodyStart, bodyEnd).toString("utf8");
  stdinBuffer = stdinBuffer.subarray(bodyEnd);
  processMessage(JSON.parse(body)).catch((error) => {
    writeMessage({ jsonrpc: "2.0", id: null, error: { code: -32603, message: error.message } });
  });
  return true;
}

process.stdin.on("data", (chunk) => {
  stdinBuffer = Buffer.concat([stdinBuffer, chunk]);
  while (stdinBuffer.length > 0) {
    const firstByte = stdinBuffer[0];
    const processed = firstByte === 123 ? handleLineProtocol() : handleHeaderProtocol();
    if (!processed) {
      break;
    }
  }
});

process.on("SIGINT", async () => {
  if (mongoClient) await mongoClient.close();
  process.exit(0);
});
