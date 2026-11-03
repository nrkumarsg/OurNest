// Supabase Edge Function: push-dispatcher
// Triggered on 'messages' INSERT via Database Webhook.
// Dispatches FCM high-priority data messages without plaintext content.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: "messages";
  record: {
    id: string;
    family_id: string;
    sender_id: string;
    type: string; // 'text' | 'photo' | 'voice' | 'alarm' | 'alarm_event'
    audience: string;
    created_at: string;
  };
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();
    const record = payload.record;

    if (!record || !record.id || !record.family_id) {
      return new Response(JSON.stringify({ error: "Invalid payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Fetch sender display name
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", record.sender_id)
      .single();

    const senderName = senderProfile?.display_name ?? "Family Member";

    // 2. Fetch target recipient user IDs
    const { data: recipients } = await supabase
      .from("message_recipients")
      .select("user_id")
      .eq("message_id", record.id);

    if (!recipients || recipients.length === 0) {
      return new Response(JSON.stringify({ message: "No recipients" }), { status: 200 });
    }

    // Exclude sender from push notification
    const recipientUserIds = recipients
      .map((r) => r.user_id)
      .filter((uid) => uid !== record.sender_id);

    if (recipientUserIds.length === 0) {
      return new Response(JSON.stringify({ message: "No external recipients" }), { status: 200 });
    }

    // 3. Look up active FCM tokens for recipient devices
    const { data: devices } = await supabase
      .from("user_devices")
      .select("fcm_token, platform")
      .in("user_id", recipientUserIds)
      .is("revoked_at", null)
      .not("fcm_token", "is", null);

    const fcmTokens = (devices || [])
      .map((d) => d.fcm_token)
      .filter((token): token is string => Boolean(token));

    if (fcmTokens.length === 0) {
      return new Response(JSON.stringify({ message: "No active FCM tokens found" }), { status: 200 });
    }

    // 4. Construct high-priority FCM data message (NO PLAINTEXT MESSAGE CONTENT)
    const isAlarm = record.type === "alarm" || record.type === "alarm_event";
    const fcmBody = {
      registration_ids: fcmTokens,
      priority: isAlarm ? "high" : "normal",
      content_available: true,
      data: {
        message_id: record.id,
        family_id: record.family_id,
        sender_name: senderName,
        message_type: record.type,
        is_alarm: isAlarm ? "true" : "false",
      },
    };

    // 5. Dispatch to Firebase Cloud Messaging HTTP v1 / legacy endpoint
    if (fcmServerKey) {
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify(fcmBody),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        dispatched_count: fcmTokens.length,
        is_alarm: isAlarm,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
