# Push notifications – one-time setup (owner)

The app code and database are ready. Push stays **off** until these steps are done; nothing breaks without them.

## 1. Firebase project
1. Go to <https://console.firebase.google.com>, create (or open) a project and add an **Android app** with package `com.ournest.app`. Add an **iOS app** with bundle `com.ournest.app` if you'll ship native iOS.
2. Project settings → General: note the **API key**, **Project ID**, **Sender ID**, and the **App ID** of each app.
3. Project settings → Service accounts → **Generate new private key**. This downloads a JSON file. Keep it secret and **never commit it**.

## 2. Build the app with the Firebase values
The values go in at build time, so no `google-services.json` is committed:

```bash
flutter build apk --release \
  --dart-define=FIREBASE_API_KEY=xxx \
  --dart-define=FIREBASE_PROJECT_ID=xxx \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=xxx \
  --dart-define=FIREBASE_ANDROID_APP_ID=xxx \
  --dart-define=FIREBASE_IOS_APP_ID=xxx
```

## 3. Edge Function secrets and deploy
```bash
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"
supabase secrets set PUSH_WEBHOOK_SECRET="<long random string>"
supabase functions deploy push-dispatcher --no-verify-jwt
```
`--no-verify-jwt` is needed because the database trigger authenticates with `PUSH_WEBHOOK_SECRET` instead of a user login.

## 4. Database trigger
Apply migration `20261105000007_push_webhook.sql`, then in the SQL Editor:
```sql
select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/push-dispatcher', 'push_dispatcher_url');
select vault.create_secret('<same string as PUSH_WEBHOOK_SECRET>', 'push_dispatcher_secret');
```

## 5. Test
- Phone A: close the app. Phone B: send a message. A should get **"B – New message"**. It shows no message text, by design.
- Shared alarm: A sets "wake me 7:00, escalate after 5 min" with B as participant. B's phone should ring at 7:05 unless A taps **I'm awake**.
- If nothing arrives, check Supabase → Edge Functions → push-dispatcher → Logs, and `select * from net._http_response order by created desc limit 5;`.

## Not covered
- **Web / PWA and the Windows launcher** get no push yet. That needs web push (VAPID) and a service worker.
