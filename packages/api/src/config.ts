import "dotenv/config";

function required(name: string): string {
  const val = process.env[name];
  if (!val) throw new Error(`Missing required env var: ${name}`);
  return val;
}

const skipAuth = process.env.DEV_SKIP_AUTH === "true";

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  databaseUrl: required("DATABASE_URL"),
  skipAuth,
  devUserId: process.env.DEV_USER_ID || "00000000-0000-0000-0000-000000000001",
  jwtSecret: process.env.JWT_SECRET || "dev-secret-change-in-production",
  anthropicApiKey: process.env.ANTHROPIC_API_KEY ?? "",
  openaiApiKey: process.env.OPENAI_API_KEY ?? "",
} as const;
