import OpenAI from "openai";
import { config } from "../config.js";
import { writeFileSync, unlinkSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { randomUUID } from "crypto";
import * as usageQueries from "../db/queries/usage.js";
import * as profileQueries from "../db/queries/profiles.js";

export async function transcribe(userId: string, audioBase64: string): Promise<{ text: string }> {
  // Check pro status
  const user = await profileQueries.findById(userId);
  if (!user || user.plan !== "pro") {
    throw { status: 403, error: "pro_required", message: "Whisper transcription requires a Pro subscription" };
  }

  const openai = new OpenAI({ apiKey: config.openaiApiKey });
  if (!config.openaiApiKey) {
    throw { status: 500, error: "not_configured", message: "OpenAI API key not configured" };
  }

  // Decode base64 audio to a temp file
  const buffer = Buffer.from(audioBase64, "base64");
  const tmpPath = join(tmpdir(), `whisper-${randomUUID()}.wav`);

  try {
    writeFileSync(tmpPath, buffer);

    const file = await import("fs").then((fs) => fs.createReadStream(tmpPath));

    const response = await openai.audio.transcriptions.create({
      model: "whisper-1",
      file,
      language: "en",
    });

    // Count against AI quota
    await usageQueries.increment(userId);

    return { text: response.text };
  } finally {
    try { unlinkSync(tmpPath); } catch { /* ignore cleanup errors */ }
  }
}
