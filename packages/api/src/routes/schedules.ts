import type { FastifyInstance } from "fastify";
import * as scheduleQueries from "../db/queries/schedules.js";
import { createScheduleRule, updateScheduleInstance } from "../validation/schedules.js";

export async function scheduleRoutes(app: FastifyInstance) {
  app.get("/rules", async (req) => {
    const { directiveId } = req.query as Record<string, string>;
    return scheduleQueries.findAllRules(req.userId, directiveId);
  });

  app.post("/rules", async (req, reply) => {
    const body = createScheduleRule.parse(req.body);
    const result = await scheduleQueries.insertRule(req.userId, body);
    return reply.code(201).send(result);
  });

  app.delete("/rules/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await scheduleQueries.removeRule(req.userId, id);
    return reply.code(204).send();
  });

  app.get("/instances", async (req) => {
    const { date } = req.query as { date: string };
    return scheduleQueries.findInstancesByDate(req.userId, date);
  });

  app.patch("/instances/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateScheduleInstance.parse(req.body);
    const result = await scheduleQueries.updateInstance(req.userId, id, body.status);
    if (!result) return reply.code(404).send({ error: "not_found", message: "Instance not found" });
    return result;
  });
}
