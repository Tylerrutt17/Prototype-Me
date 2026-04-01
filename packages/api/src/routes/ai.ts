import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";
import { aiSuggest, aiOnboard, directiveWizard } from "../validation/ai.js";
import { ok } from "../lib/responses.js";

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
}
