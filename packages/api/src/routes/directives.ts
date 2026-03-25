import type { FastifyInstance } from "fastify";
import * as directives from "../features/directives.js";
import { createDirective, updateDirective } from "../validation/directives.js";
import { ok, created, noContent } from "../lib/responses.js";

export async function directiveRoutes(app: FastifyInstance) {
  app.get("/", async (req, reply) => {
    const { status } = req.query as Record<string, string>;
    return ok(reply, await directives.listDirectives(req.userId, { status }));
  });

  app.get("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    return ok(reply, await directives.getDirective(req.userId, id));
  });

  app.post("/", async (req, reply) => {
    const body = createDirective.parse(req.body);
    const result = await directives.createDirective(req.userId, body);
    return created(reply, result);
  });

  app.patch("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateDirective.parse(req.body);
    return ok(reply, await directives.updateDirective(req.userId, id, body));
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await directives.deleteDirective(req.userId, id);
    return noContent(reply);
  });

  app.post("/:id/pump", async (req, reply) => {
    const { id } = req.params as { id: string };
    return ok(reply, await directives.pumpDirective(req.userId, id));
  });

  app.get("/:id/history", async (req, reply) => {
    const { id } = req.params as { id: string };
    return ok(reply, await directives.getHistory(req.userId, id));
  });
}
