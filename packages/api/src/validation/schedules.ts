import { z } from "zod/v4";
import { uuid, isoDate, scheduleType, instanceStatus } from "./shared.js";

export const createScheduleRule = z.object({
  id: uuid.optional(),
  directiveId: uuid,
  ruleType: scheduleType,
  params: z.record(z.string(), z.array(z.int())),
});

export const updateScheduleInstance = z.object({
  status: instanceStatus,
});

export type CreateScheduleRuleInput = z.infer<typeof createScheduleRule>;
export type UpdateScheduleInstanceInput = z.infer<typeof updateScheduleInstance>;
