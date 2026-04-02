import type { FastifyRequest, FastifyReply } from "fastify";
import { verifyToken } from "../lib/jwt.js";

declare module "fastify" {
  interface FastifyRequest {
    userId: string;
  }
}

export async function requireAuth(
  request: FastifyRequest,
  reply: FastifyReply,
) {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return reply.code(401).send({ error: "unauthorized", message: "Missing or invalid Authorization header" });
  }

  const token = header.slice(7);
  try {
    const payload = verifyToken(token);
    if (payload.type !== "access") {
      return reply.code(401).send({ error: "unauthorized", message: "Not an access token" });
    }
    request.userId = payload.sub;
  } catch {
    return reply.code(401).send({ error: "unauthorized", message: "Invalid or expired token" });
  }
}
