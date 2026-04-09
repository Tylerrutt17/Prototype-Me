import { describe, it, expect, beforeAll, afterAll } from "vitest";
import Fastify, { type FastifyInstance } from "fastify";
import { config } from "../config.js";
import { upgradeRequired, ok } from "../lib/responses.js";

/**
 * Tests for the X-Sync-Version enforcement contract.
 *
 * Uses a minimal Fastify instance that mirrors the real sync route's
 * onRequest hook — no database or auth required.
 */

let app: FastifyInstance;

beforeAll(async () => {
  app = Fastify();

  // Mirror the real sync route's version gate
  app.addHook("onRequest", async (req, reply) => {
    const raw = req.headers["x-sync-version"];
    const clientVersion = typeof raw === "string" ? parseInt(raw, 10) : NaN;

    if (isNaN(clientVersion) || clientVersion < config.minSyncVersion) {
      return upgradeRequired(reply);
    }
  });

  // Dummy endpoint — if version check passes, we reach here
  app.get("/sync/pull", async (_req, reply) => ok(reply, { events: [] }));
  app.post("/sync/push", async (_req, reply) => ok(reply, { applied: [] }));

  await app.ready();
});

afterAll(async () => {
  await app.close();
});

// ── Missing header ──────────────────────────────

describe("missing X-Sync-Version header", () => {
  it("returns 426 on GET /sync/pull", async () => {
    const res = await app.inject({ method: "GET", url: "/sync/pull" });
    expect(res.statusCode).toBe(426);
    expect(res.json().error).toBe("upgrade_required");
  });

  it("returns 426 on POST /sync/push", async () => {
    const res = await app.inject({ method: "POST", url: "/sync/push" });
    expect(res.statusCode).toBe(426);
    expect(res.json().error).toBe("upgrade_required");
  });
});

// ── Old version ─────────────────────────────────

describe("outdated X-Sync-Version", () => {
  it("returns 426 when client version is below minimum", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/sync/pull",
      headers: { "x-sync-version": "0" },
    });
    expect(res.statusCode).toBe(426);
    expect(res.json().error).toBe("upgrade_required");
  });
});

// ── Invalid header values ───────────────────────

describe("invalid X-Sync-Version values", () => {
  it("returns 426 for non-numeric value", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/sync/pull",
      headers: { "x-sync-version": "abc" },
    });
    expect(res.statusCode).toBe(426);
  });

  it("returns 426 for empty string", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/sync/pull",
      headers: { "x-sync-version": "" },
    });
    expect(res.statusCode).toBe(426);
  });
});

// ── Current version ─────────────────────────────

describe("current X-Sync-Version", () => {
  it("passes through on GET /sync/pull", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/sync/pull",
      headers: { "x-sync-version": String(config.minSyncVersion) },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().success).toBe(true);
  });

  it("passes through on POST /sync/push", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/sync/push",
      headers: { "x-sync-version": String(config.minSyncVersion) },
    });
    expect(res.statusCode).toBe(200);
  });
});

// ── Future version (forward-compatible) ─────────

describe("future X-Sync-Version", () => {
  it("accepts a version higher than minimum", async () => {
    const res = await app.inject({
      method: "GET",
      url: "/sync/pull",
      headers: { "x-sync-version": String(config.minSyncVersion + 5) },
    });
    expect(res.statusCode).toBe(200);
  });
});
