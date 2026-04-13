import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { config } from "../config.js";

// ── Models ─────────────────────────────────────

export const OPENAI_MODEL = "gpt-4.1-nano";
export const ANTHROPIC_MODEL = "claude-3-5-haiku-latest";

// ── Clients ────────────────────────────────────

export const openai = config.openaiApiKey ? new OpenAI({ apiKey: config.openaiApiKey }) : null;
const anthropic = config.anthropicApiKey ? new Anthropic({ apiKey: config.anthropicApiKey }) : null;

// ── Types ──────────────────────────────────────

export interface LLMRequest {
  system: string;
  prompt: string;
  maxTokens?: number;
  /** Optional model override. Defaults to gpt-4o for OpenAI, claude-sonnet-4-6 for Anthropic. */
  model?: string;
}

export interface LLMResponse {
  text: string;
  provider: "openai" | "anthropic";
}

// ── Main Function ──────────────────────────────

/**
 * Calls an LLM — tries OpenAI first, falls back to Anthropic/Claude.
 * Any caller just needs a system prompt and user prompt.
 *
 * Usage:
 * ```ts
 * const { text } = await callLLM({ system: "You are...", prompt: "Help me with..." });
 * const data = JSON.parse(text);
 * ```
 */
export async function callLLM(request: LLMRequest): Promise<LLMResponse> {
  const { system, prompt, maxTokens = 1024 } = request;

  // Try OpenAI first
  if (openai) {
    try {
      return await callOpenAI(system, prompt, maxTokens, request.model);
    } catch (err) {
      console.warn("[LLM] OpenAI failed, falling back to Anthropic:", (err as Error).message);
    }
  }

  // Fallback to Anthropic
  if (anthropic) {
    try {
      return await callAnthropic(system, prompt, maxTokens, request.model);
    } catch (err) {
      console.error("[LLM] Anthropic also failed:", (err as Error).message);
      throw new Error("All LLM providers failed");
    }
  }

  throw new Error("No LLM provider configured. Set OPENAI_API_KEY or ANTHROPIC_API_KEY.");
}

// ── Convenience: parse JSON from LLM ───────────

/**
 * Calls an LLM and parses the response as JSON.
 * Returns the fallback value if parsing fails.
 */
export async function callLLMJson<T>(request: LLMRequest, fallback: T): Promise<{ data: T; provider: string }> {
  const response = await callLLM(request);

  // Strip markdown code fences if present
  let text = response.text.trim();
  if (text.startsWith("```")) {
    text = text.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "");
  }

  try {
    return { data: JSON.parse(text) as T, provider: response.provider };
  } catch {
    console.warn("[LLM] Failed to parse JSON response:", text.substring(0, 200));
    return { data: fallback, provider: response.provider };
  }
}

// ── Provider Implementations ───────────────────

async function callOpenAI(system: string, prompt: string, maxTokens: number, model?: string): Promise<LLMResponse> {
  const completion = await openai!.chat.completions.create({
    model: model ?? OPENAI_MODEL,
    max_tokens: maxTokens,
    messages: [
      { role: "system", content: system },
      { role: "user", content: prompt },
    ],
  });

  const text = completion.choices[0]?.message?.content ?? "";
  return { text, provider: "openai" };
}

async function callAnthropic(system: string, prompt: string, maxTokens: number, model?: string): Promise<LLMResponse> {
  const message = await anthropic!.messages.create({
    model: model ?? ANTHROPIC_MODEL,
    max_tokens: maxTokens,
    system,
    messages: [{ role: "user", content: prompt }],
  });

  const text = message.content[0]?.type === "text" ? message.content[0].text : "";
  return { text, provider: "anthropic" };
}
