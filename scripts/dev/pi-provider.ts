// Explicitly loaded in an otherwise discovery-free, credential-free Pi home.
export default function (pi: any) {
  const model = process.env.PI_HARNESS_MODEL!;
  const payload = Buffer.from(JSON.stringify({
    "https://api.openai.com/auth": { chatgpt_account_id: "sandbox-placeholder" }
  })).toString("base64url");
  pi.registerProvider("openai-codex", {
    baseUrl: "http://127.0.0.1:38117",
    apiKey: `placeholder.${payload}.placeholder`, // pragma: allowlist secret
    api: "openai-codex-responses",
    models: [{ id: model, name: model, reasoning: true, input: ["text"],
      thinkingLevelMap: { minimal: "low", xhigh: "xhigh", max: "max" },
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 272000, maxTokens: 1024 }]
  });
}
