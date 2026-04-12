import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";
import * as converseFeature from "../features/converse.js";
import * as transcribeFeature from "../features/transcribe.js";
import * as reviewFeature from "../features/weeklyReview.js";
import { aiSuggest, aiOnboard, directiveWizard } from "../validation/ai.js";
import { LIMITS } from "../validation/limits.js";
import { z } from "zod/v4";
import { ok } from "../lib/responses.js";

const transcribeBody = z.object({
  audio: z.string().min(1), // base64 encoded audio
});

const converseBody = z.object({
  messages: z.array(z.object({
    role: z.enum(["user", "assistant"]),
    content: z.string().max(LIMITS.ai.speakMessage),
  })),
  localDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  // Continuation fields — sent when the client has executed read tools locally
  previousResponseId: z.string().optional(),
  toolOutputs: z.array(z.object({
    callId: z.string(),
    output: z.string(),
  })).optional(),
});

export async function aiRoutes(app: FastifyInstance) {
  app.post("/suggest", async (req, reply) => {
    const body = aiSuggest.parse(req.body);
    return ok(reply, await ai.suggest(req.userId, body.context));
  });

  app.post("/onboard", async (req, reply) => {
    const body = aiOnboard.parse(req.body);
    return ok(reply, await ai.onboard(body.prompt));
  });

  app.post("/directive-wizard", async (req, reply) => {
    const body = directiveWizard.parse(req.body);
    return ok(reply, await ai.directiveWizard(req.userId, body.problem));
  });

  app.post("/converse", async (req, reply) => {
    const body = converseBody.parse(req.body);
    return ok(reply, await converseFeature.converse(
      req.userId, body.messages, body.localDate,
      body.previousResponseId, body.toolOutputs,
    ));
  });

  app.post("/transcribe", async (req, reply) => {
    const body = transcribeBody.parse(req.body);
    return ok(reply, await transcribeFeature.transcribe(req.userId, body.audio));
  });

  // Periodic reviews (weekly + monthly)
  app.get("/reviews", async (req, reply) => {
    const { period } = req.query as { period?: "weekly" | "monthly" };
    const reviews = await reviewFeature.getReviews(req.userId, period);
    return ok(reply, reviews);
  });

  // TEST: force-generate a review for the current week/month
  app.post("/reviews/test-trigger", async (req, reply) => {
    const { period } = (req.body ?? {}) as { period?: "weekly" | "monthly" };
    const result = await reviewFeature.triggerTestReview(req.userId, period ?? "weekly");
    return ok(reply, result);
  });

  app.get("/reviews/:period/:periodStart", async (req, reply) => {
    const { period, periodStart } = req.params as { period: "weekly" | "monthly"; periodStart: string };
    const review = await reviewFeature.getReview(req.userId, period, periodStart);
    if (!review) return reply.code(404).send({ success: false, error: "not_found", message: "No review for this period" });
    return ok(reply, review);
  });
}
