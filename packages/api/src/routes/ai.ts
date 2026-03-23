import type { FastifyInstance } from "fastify";
import * as ai from "../features/ai.js";
import { aiSuggest, aiOnboard } from "../validation/ai.js";

export async function aiRoutes(app: FastifyInstance) {
  app.post("/suggest", async (req) => {
    const body = aiSuggest.parse(req.body);
    return ai.suggest(req.userId, body.context);
  });

  app.post("/onboard", async (req) => {
    const body = aiOnboard.parse(req.body);
    return ai.onboard(body.prompt);
  });
}
