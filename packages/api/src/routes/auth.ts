import type { FastifyInstance } from "fastify";
import { z } from "zod/v4";
import * as auth from "../features/auth.js";
import { ok } from "../lib/responses.js";
import { verifyToken } from "../lib/jwt.js";

const appleLoginBody = z.object({
  identityToken: z.string().min(1),
  fullName: z.string().optional(),
});

const refreshBody = z.object({
  refreshToken: z.string().min(1),
});

export async function authRoutes(app: FastifyInstance) {
  // Sign in with Apple — public endpoint
  app.post("/apple", async (req, reply) => {
    const body = appleLoginBody.parse(req.body);
    return ok(reply, await auth.loginWithApple(body.identityToken, body.fullName));
  });

  // Refresh access token — public endpoint
  app.post("/refresh", async (req, reply) => {
    const body = refreshBody.parse(req.body);
    try {
      const payload = verifyToken(body.refreshToken);
      if (payload.type !== "refresh") {
        return reply.code(401).send({ success: false, data: null, error: "invalid_token", message: "Not a refresh token" });
      }

      const { signAccessToken, signRefreshToken } = await import("../lib/jwt.js");
      const accessToken = signAccessToken(payload.sub);
      const refreshToken = signRefreshToken(payload.sub);

      return ok(reply, { accessToken, refreshToken });
    } catch {
      return reply.code(401).send({ success: false, data: null, error: "invalid_token", message: "Invalid or expired refresh token" });
    }
  });
}
