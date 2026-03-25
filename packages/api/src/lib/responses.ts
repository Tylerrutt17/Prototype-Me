import type { FastifyReply } from "fastify";

// ── Unified response envelope ───────────────
//
// Every response from the API uses this shape:
// {
//   "success": true | false,
//   "data":    T | null,
//   "error":   string | null,
//   "message": string | null
// }

interface ApiResponse<T = unknown> {
  success: boolean;
  data: T | null;
  error: string | null;
  message: string | null;
}

function send<T>(reply: FastifyReply, code: number, success: boolean, data: T | null, error: string | null, message: string | null): FastifyReply {
  return reply.code(code).send({
    success,
    data,
    error,
    message,
  } satisfies ApiResponse<T>);
}

// ── Success ─────────────────────────────────

export function ok<T>(reply: FastifyReply, data: T) {
  return send(reply, 200, true, data, null, null);
}

export function created<T>(reply: FastifyReply, data: T) {
  return send(reply, 201, true, data, null, null);
}

export function noContent(reply: FastifyReply) {
  return send(reply, 204, true, null, null, null);
}

// ── Errors ──────────────────────────────────

export function badRequest(reply: FastifyReply, message: string) {
  return send(reply, 400, false, null, "bad_request", message);
}

export function unauthorized(reply: FastifyReply, message = "Authentication required") {
  return send(reply, 401, false, null, "unauthorized", message);
}

export function forbidden(reply: FastifyReply, message = "Access denied") {
  return send(reply, 403, false, null, "forbidden", message);
}

export function notFound(reply: FastifyReply, resource = "Resource") {
  return send(reply, 404, false, null, "not_found", `${resource} not found`);
}

export function conflict(reply: FastifyReply, message = "Version conflict") {
  return send(reply, 409, false, null, "conflict", message);
}

export function serverError(reply: FastifyReply, message = "Something went wrong") {
  return send(reply, 500, false, null, "internal_error", message);
}
