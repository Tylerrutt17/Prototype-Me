import type { FastifyInstance } from "fastify";
import * as directives from "../features/directives.js";
import { createDirective, updateDirective } from "../validation/directives.js";

export async function directiveRoutes(app: FastifyInstance) {
  app.get("/", async (req) => {
    const { status } = req.query as Record<string, string>;
    return directives.listDirectives(req.userId, { status });
  });

  app.get("/:id", async (req) => {
    const { id } = req.params as { id: string };
    return directives.getDirective(req.userId, id);
  });

  app.post("/", async (req, reply) => {
    const body = createDirective.parse(req.body);
    const result = await directives.createDirective(req.userId, body);
    return reply.code(201).send(result);
  });

  app.patch("/:id", async (req) => {
    const { id } = req.params as { id: string };
    const body = updateDirective.parse(req.body);
    return directives.updateDirective(req.userId, id, body);
  });

  app.delete("/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await directives.deleteDirective(req.userId, id);
    return reply.code(204).send();
  });

  app.post("/:id/pump", async (req) => {
    const { id } = req.params as { id: string };
    return directives.pumpDirective(req.userId, id);
  });

  app.get("/:id/history", async (req) => {
    const { id } = req.params as { id: string };
    return directives.getHistory(req.userId, id);
  });
}
