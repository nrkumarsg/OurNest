// Supabase Edge Function: push-dispatcher
// Called by the database trigger in migration 20261105000007 after every
// `messages` INSERT. Sends a push to every recipient device WITHOUT any
// message content (only sender name, message id/type, family id).
//
// Audit F04: the old version used the legacy `fcm/send` API that Google shut
// down in 2024. This version uses the FCM HTTP v1 API with a service account.
//
// Required function secrets (supabase secrets set ...):
//   FCM_SERVICE_ACCOUNT_JSON  – full JSON of a Firebase service account key
//   PUSH_WEBHOOK_SECRET       – random string; must match the Vault secret
//                               `push_dispatcher_secret` used by the trigger
// Provided automatically by Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Deploy WITHOUT JWT verification (the trigger authenticates with the shared
// secret instead):  supabase functions deploy push-dispatcher --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

interface MessageRecord {
  id: string;
  family_id: string;
  sender_id: string;
  type: string; // 'text' | 'photo' | 'voice' | 'alarm' | 'alarm_event'
  audience: string;
  created_at: string;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

// Constant-time comparison so the secret can't be guessed by timing.
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

// Cached OAuth access token (valid ~1h) between invocations of a warm worker.
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.token;

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const assertion = `${header}.${claims}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`OAuth token request failed: ${res.status}`);
  const body = await res.json();
  cachedToken = { token: body.access_token, expiresAt: now + (body.expires_in ?? 3600) };
  return cachedToken.token;
}

function notificationText(type: string): string {
  switch (type) {
    case "alarm": return "⏰ Set a shared alarm";
    case "alarm_event": return "⏰ Alarm update";
    case "photo": return "📷 Sent a photo";
    case "voice": return "🎤 Sent a voice note";
    default: return "New message";
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Only our database trigger may call this function.
  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
  const givenSecret = req.headers.get("x-webhook-secret") ?? "";
  if (!expectedSecret || !safeEqual(givenSecret, expectedSecret)) {
    return json({ error: "Unauthorized" }, 401);
  }

  let record: MessageRecord | undefined;
  try {
    record = (await req.json())?.record;
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  if (!record?.id || !record.family_id || !record.sender_id) {
    return json({ error: "Invalid payload" }, 400);
  }

  const saJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!saJson) return json({ error: "Push not configured" }, 503);

  try {
    const sa: ServiceAccount = JSON.parse(saJson);
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } },
    );

    // 2. Sender display name (no message content is ever read or sent)
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", record.sender_id)
      .maybeSingle();
    const senderName: string = senderProfile?.display_name ?? "Family Member";

    // 3. Recipients, excluding the sender
    const { data: recipients, error: recErr } = await supabase
      .from("message_recipients")
      .select("user_id")
      .eq("message_id", record.id);
    if (recErr) throw recErr;

    const recipientUserIds = (recipients ?? [])
      .map((r: { user_id: string }) => r.user_id)
      .filter((uid: string) => uid !== record!.sender_id);
    if (recipientUserIds.length === 0) return json({ message: "No recipients" });

    // 4. Active device tokens
    const { data: devices, error: devErr } = await supabase
      .from("user_devices")
      .select("id, fcm_token, platform")
      .in("user_id", recipientUserIds)
      .is("revoked_at", null)
      .not("fcm_token", "is", null);
    if (devErr) throw devErr;
    if (!devices || devices.length === 0) return json({ message: "No active tokens" });

    const isAlarm = record.type === "alarm" || record.type === "alarm_event";
    const accessToken = await getAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    // FCM data values must be strings.
    const data = {
      message_id: record.id,
      family_id: record.family_id,
      sender_name: senderName,
      message_type: record.type,
      is_alarm: isAlarm ? "true" : "false",
    };

    // 5. One request per device (FCM v1 has no multi-token send)
    const results = await Promise.allSettled(devices.map(async (d) => {
      const message: Record<string, unknown> = {
        token: d.fcm_token,
        data,
        // Android: data-only, the app shows its own privacy-safe notification
        // and schedules alarm escalations in the background.
        android: { priority: isAlarm ? "HIGH" : "NORMAL" },
        // iOS: background data pushes are throttled, so also show a generic
        // alert (still no message content).
        apns: {
          headers: { "apns-priority": isAlarm ? "10" : "5" },
          payload: {
            aps: {
              "content-available": 1,
              alert: { title: senderName, body: notificationText(record!.type) },
              sound: "default",
            },
          },
        },
      };
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({ message }),
      });
      if (!res.ok) {
        const errBody = await res.text();
        // Token no longer valid (app uninstalled / token rotated): stop using it.
        if (res.status === 404 || errBody.includes("UNREGISTERED")) {
          await supabase.from("user_devices").update({ fcm_token: null }).eq("id", d.id);
        }
        throw new Error(`FCM ${res.status}`);
      }
    }));

    const sent = results.filter((r) => r.status === "fulfilled").length;
    return json({ success: true, sent, failed: results.length - sent, is_alarm: isAlarm });
  } catch (error) {
    // Log details server-side only; don't leak internals to the caller.
    console.error("push-dispatcher error:", error);
    return json({ error: "Push dispatch failed" }, 500);
  }
});
