import Fastify from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import { requireAuth } from "./middleware/auth.js";

// Routes
import { noteRoutes } from "./routes/notes.js";
import { directiveRoutes } from "./routes/directives.js";
import { folderRoutes } from "./routes/folders.js";
import { dayEntryRoutes } from "./routes/dayEntries.js";
import { tagRoutes } from "./routes/tags.js";
import { scheduleRoutes } from "./routes/schedules.js";
import { modeRoutes } from "./routes/modes.js";
import { linkRoutes } from "./routes/links.js";
import { syncRoutes } from "./routes/sync.js";
import { profileRoutes } from "./routes/profile.js";
import { friendRoutes } from "./routes/friends.js";
import { subscriptionRoutes } from "./routes/subscription.js";
import { usageRoutes } from "./routes/usage.js";
import { aiRoutes } from "./routes/ai.js";
import { deviceRoutes } from "./routes/devices.js";
import { authRoutes } from "./routes/auth.js";
import { cleanupRoutes } from "./routes/cleanup.js";
import { webhookRoutes } from "./routes/webhooks.js";

const app = Fastify({ logger: true, bodyLimit: 15 * 1024 * 1024 }); // 10MB for base64 audio uploads

// ── Plugins ─────────────────────────────────
await app.register(cors, { origin: true });

// ── Global auth hook ────────────────────────
app.addHook("onRequest", async (request, reply) => {
  // Skip auth for health check and public endpoints
  const publicPaths = ["/health", "/v1/ai/onboard", "/v1/auth/", "/v1/cleanup/", "/v1/webhooks/"];
  if (publicPaths.some((p) => request.url.startsWith(p))) return;

  // Dev bypass: skip auth and use a test user ID
  if (process.env.DEV_SKIP_AUTH === "true") {
    request.userId = process.env.DEV_USER_ID || "dev-test-user";
    return;
  }

  await requireAuth(request, reply);
});

// ── Health check ────────────────────────────
app.get("/health", async () => ({ status: "ok" }));

// ── Error handler ───────────────────────────
app.setErrorHandler((error, _request, reply) => {
  // Zod validation errors → 400
  if (error && typeof error === "object" && "issues" in error && Array.isArray((error as { issues: unknown[] }).issues)) {
    const issues = (error as { issues: Array<{ message: string; path: (string | number)[] }> }).issues;
    return reply.code(400).send({
      success: false,
      data: null,
      error: "validation_error",
      message: "Invalid request body",
      details: issues.map((i) => ({ path: i.path.join("."), message: i.message })),
    });
  }

  // Feature layer throws { status, error, message }
  if (error && typeof error === "object" && "status" in error) {
    const err = error as { status: number; error: string; message: string };
    return reply.code(err.status).send({
      success: false,
      data: null,
      error: err.error,
      message: err.message,
    });
  }

  app.log.error(error);
  return reply.code(500).send({
    success: false,
    data: null,
    error: "internal_error",
    message: "Something went wrong",
  });
});

// ── Register routes ─────────────────────────
await app.register(noteRoutes, { prefix: "/v1/notes" });
await app.register(directiveRoutes, { prefix: "/v1/directives" });
await app.register(folderRoutes, { prefix: "/v1/folders" });
await app.register(dayEntryRoutes, { prefix: "/v1/day-entries" });
await app.register(tagRoutes, { prefix: "/v1/tags" });
await app.register(scheduleRoutes, { prefix: "/v1/schedule" });
await app.register(modeRoutes, { prefix: "/v1/active-modes" });
await app.register(linkRoutes, { prefix: "/v1/links" });
await app.register(syncRoutes, { prefix: "/v1/sync" });
await app.register(profileRoutes, { prefix: "/v1" });
await app.register(friendRoutes, { prefix: "/v1/friends" });
await app.register(subscriptionRoutes, { prefix: "/v1/subscription" });
await app.register(usageRoutes, { prefix: "/v1/usage" });
await app.register(aiRoutes, { prefix: "/v1/ai" });
await app.register(deviceRoutes, { prefix: "/v1/devices" });
await app.register(authRoutes, { prefix: "/v1/auth" });
await app.register(cleanupRoutes, { prefix: "/v1/cleanup" });
await app.register(webhookRoutes, { prefix: "/v1/webhooks" });

// ── Scheduled Jobs ─────────────────────────
import cron from "node-cron";
import { purgeExpired } from "./features/cleanup.js";
import { generateWeeklyReviews, generateMonthlyReviews } from "./features/weeklyReview.js";

// Run cleanup daily at 3:00 AM UTC
cron.schedule("0 3 * * *", async () => {
  try {
    const result = await purgeExpired();
    app.log.info(`[Cleanup] Purged ${result.syncOpLogsDeleted} op logs, ${result.tombstonesDeleted} tombstones`);
  } catch (err) {
    app.log.error("[Cleanup] Failed: %s", err);
  }
});

// Run weekly reviews every Sunday at 11 PM UTC
cron.schedule("0 23 * * 0", async () => {
  try {
    const result = await generateWeeklyReviews();
    app.log.info(`[Review/weekly] Processed ${result.processed}, skipped ${result.skipped}, errors ${result.errors}`);
  } catch (err) {
    app.log.error("[Review/weekly] Failed: %s", err);
  }
});

// Run monthly reviews on the 1st at 2 AM UTC
cron.schedule("0 2 1 * *", async () => {
  try {
    const result = await generateMonthlyReviews();
    app.log.info(`[Review/monthly] Processed ${result.processed}, skipped ${result.skipped}, errors ${result.errors}`);
  } catch (err) {
    app.log.error("[Review/monthly] Failed: %s", err);
  }
});

// ── Start ───────────────────────────────────
try {
  await app.listen({ port: config.port, host: "0.0.0.0" });
  app.log.info(`Server running on port ${config.port}`);
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
