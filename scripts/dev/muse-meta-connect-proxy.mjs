#!/usr/bin/env node

import { appendFileSync, chmodSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { connect } from "node:net";

function die(message) {
  process.stderr.write(`muse Meta proxy: ${message}\n`);
  process.exit(1);
}

let readyFile = "";
let logFile = "";
for (let index = 2; index < process.argv.length; index += 1) {
  const flag = process.argv[index];
  const value = () => {
    index += 1;
    if (index >= process.argv.length || process.argv[index] === "") die(`${flag} requires a value`);
    return process.argv[index];
  };
  if (flag === "--ready-file") readyFile = value();
  else if (flag === "--log-file") logFile = value();
  else die(`unknown option: ${flag}`);
}
if (!readyFile || !logFile) die("--ready-file and --log-file are required");

const ALLOWED_AUTHORITY = "api.meta.ai:443";

function record(outcome, authority = "") {
  appendFileSync(logFile, `${JSON.stringify({ outcome, authority, at: new Date().toISOString() })}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  chmodSync(logFile, 0o600);
}

const server = createServer((_request, response) => {
  record("rejected_non_connect");
  response.writeHead(405, { Connection: "close" });
  response.end();
});

server.on("connect", (request, client, head) => {
  const authority = String(request.url ?? "").toLowerCase();
  if (authority !== ALLOWED_AUTHORITY) {
    record("rejected_authority", authority);
    client.end("HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n");
    return;
  }

  const upstream = connect({ host: "api.meta.ai", port: 443 });
  upstream.once("connect", () => {
    record("accepted_authority", authority);
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    if (head.length > 0) upstream.write(head);
    upstream.pipe(client);
    client.pipe(upstream);
  });
  upstream.once("error", () => {
    record("upstream_error", authority);
    client.end("HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n");
  });
  client.once("error", () => upstream.destroy());
});

server.on("error", (error) => die(error.message));
server.listen(0, "127.0.0.1", () => {
  const address = server.address();
  if (!address || typeof address === "string") die("could not determine listening port");
  writeFileSync(readyFile, `${JSON.stringify({ host: "127.0.0.1", port: address.port, pid: process.pid })}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  chmodSync(readyFile, 0o600);
});

function stop() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1_000).unref();
}
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
