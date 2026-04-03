import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";
import * as transcribeFeature from "../features/transcribe.js";
import { aiSuggest, aiOnboard, directiveWizard } from "../validation/ai.js";
import { z } from "zod/v4";
import { ok } from "../lib/responses.js";

const transcribeBody = z.object({
  audio: z.string().min(1), // base64 encoded audio
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

  app.post("/transcribe", async (req, reply) => {
    const body = transcribeBody.parse(req.body);
    return ok(reply, await transcribeFeature.transcribe(req.userId, body.audio));
  });
}
