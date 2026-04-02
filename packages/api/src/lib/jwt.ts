import jwt from "jsonwebtoken";
import { config } from "../config.js";

const JWT_SECRET = config.jwtSecret;
const JWT_EXPIRY = "30d"; // 30 days
const JWT_REFRESH_EXPIRY = "90d";

export interface TokenPayload {
  sub: string; // user ID (Apple's sub)
  email?: string;
  type: "access" | "refresh";
}

export function signAccessToken(userId: string, email?: string): string {
  return jwt.sign(
    { sub: userId, email, type: "access" } satisfies TokenPayload,
    JWT_SECRET,
    { expiresIn: JWT_EXPIRY },
  );
}

export function signRefreshToken(userId: string): string {
  return jwt.sign(
    { sub: userId, type: "refresh" } satisfies TokenPayload,
    JWT_SECRET,
    { expiresIn: JWT_REFRESH_EXPIRY },
  );
}

export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, JWT_SECRET) as TokenPayload;
}
