import { z } from "zod/v4";

export const verifyReceipt = z.object({
  receiptData: z.string().min(1),
});

export type VerifyReceiptInput = z.infer<typeof verifyReceipt>;
