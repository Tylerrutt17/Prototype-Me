import type { FastifyInstance } from "fastify";
import * as scheduleQueries from "../db/queries/schedules.js";
import { createScheduleRule, updateScheduleInstance } from "../validation/schedules.js";
import { ok, created, noContent, notFound } from "../lib/responses.js";

export async function scheduleRoutes(app: FastifyInstance) {
  app.get("/rules", async (req, reply) => {
    const { directiveId } = req.query as Record<string, string>;
    return ok(reply, await scheduleQueries.findAllRules(req.userId, directiveId));
  });

  app.post("/rules", async (req, reply) => {
    const body = createScheduleRule.parse(req.body);
    const result = await scheduleQueries.insertRule(req.userId, body);
    return created(reply, result);
  });

  app.delete("/rules/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    await scheduleQueries.removeRule(req.userId, id);
    return noContent(reply);
  });

  app.get("/instances", async (req, reply) => {
    const { date } = req.query as { date: string };
    return ok(reply, await scheduleQueries.findInstancesByDate(req.userId, date));
  });

  app.patch("/instances/:id", async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = updateScheduleInstance.parse(req.body);
    const result = await scheduleQueries.updateInstance(req.userId, id, body.status);
    if (!result) return notFound(reply, "Instance");
    return ok(reply, result);
  });
}
