import { CognitoJwtVerifier } from "aws-jwt-verify";
import type { FastifyRequest, FastifyReply } from "fastify";
import { config } from "../config.js";

// Only create the verifier if auth is enabled and Cognito is configured
const verifier = !config.skipAuth && config.cognito.userPoolId
  ? CognitoJwtVerifier.create({
      userPoolId: config.cognito.userPoolId,
      tokenUse: "access",
      clientId: config.cognito.clientId,
    })
  : null;

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

  if (!verifier) {
    return reply.code(500).send({ error: "auth_not_configured", message: "Auth is not configured" });
  }

  const token = header.slice(7);
  try {
    const payload = await verifier.verify(token);
    request.userId = payload.sub;
  } catch {
    return reply.code(401).send({ error: "unauthorized", message: "Invalid or expired token" });
  }
}
