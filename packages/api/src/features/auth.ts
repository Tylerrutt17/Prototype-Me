import * as jose from "jose";
import { db } from "../db/client.js";
import { users } from "../db/schema.js";
import { eq } from "drizzle-orm";
import { signAccessToken, signRefreshToken } from "../lib/jwt.js";

// Apple's JWKS endpoint for verifying identity tokens
const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";

/**
 * Verify an Apple identity token and create/find the user.
 * Returns access + refresh tokens for the app.
 */
export async function loginWithApple(identityToken: string, fullName?: string) {
  // 1. Verify the Apple identity token
  const jwks = jose.createRemoteJWKSet(new URL(APPLE_JWKS_URL));

  let payload: jose.JWTPayload;
  try {
    const result = await jose.jwtVerify(identityToken, jwks, {
      issuer: APPLE_ISSUER,
      // audience is your app's bundle ID — Apple sets this as the `aud` claim
    });
    payload = result.payload;
  } catch (err) {
    throw { status: 401, error: "invalid_token", message: "Apple identity token is invalid or expired" };
  }

  const appleId = payload.sub;
  if (!appleId) {
    throw { status: 401, error: "invalid_token", message: "Token missing sub claim" };
  }

  const email = payload.email as string | undefined;

  // 2. Find or create user by Apple ID
  let user = await db.select().from(users).where(eq(users.appleId, appleId)).then((r) => r[0]);
  let isNewUser = false;

  if (!user) {
    isNewUser = true;
    const displayName = fullName || email?.split("@")[0] || "User";
    const result = await db
      .insert(users)
      .values({
        appleId,
        email: email ?? "",
        displayName,
        plan: "free",
      })
      .returning();

    user = result[0]!;
  }

  // 3. Issue tokens using the UUID primary key
  const accessToken = signAccessToken(user.id, email);
  const refreshToken = signRefreshToken(user.id);

  return {
    accessToken,
    refreshToken,
    isNewUser,
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      plan: user.plan,
    },
  };
}
