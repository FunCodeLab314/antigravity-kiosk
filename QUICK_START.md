# 🚀 Quick Start - Notification System

## What's New ✨
Your app now sends and receives notifications **even when closed**!

## 3-Minute Setup

### 1️⃣ Run the App
```bash
flutter clean
flutter pub get
flutter run
```

### 2️⃣ Get Your FCM Token
- Open the terminal/logcat when app starts
- Look for: `FCM Token: <long-string-here>`
- Copy and save this token

### 3️⃣ Send Test Notification
**Option A: Firebase Console (Easiest)**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Cloud Messaging → Send your first message
4. Title: "💊 Time for Medication!"
5. Body: "Test notification"
6. Target: Device → Paste your FCM token
7. Send & watch it appear even if app is closed!

**Option B: Command Line (Advanced)**
```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "FCM_TOKEN_HERE",
      "notification": {
        "title": "💊 Medication Time!",
        "body": "Take your medication"
      },
      "data": {
        "type": "medication",
        "isCreator": "true"
      }
    }
  }'
```

## How It Works 🔄

| State | How Notifications Work |
|-------|------------------------|
| **App Closed** | 🟢 Works! Background handler + local notification |
| **App Background** | 🟢 Works! FCM + local notification |
| **App Foreground** | 🟢 Works! Shows local notification |

## Notification Types

### Medication Reminder
```json
{
  "type": "medication",
  "patientId": "123",
  "isCreator": true
}
```
→ Shows alarm popup for creators

### Refill Alert
```json
{
  "type": "refill",
  "patientId": "123"
}
```
→ Shows notifications screen

## Key Components ⚙️

1. **Background Handler**: Catches notifications when app is killed
2. **FCM Setup**: Requests permissions & gets device token
3. **Foreground Listener**: Shows notifications while app running
4. **Tap Handler**: Routes user to correct screen
5. **Topic Subscriptions**: Auto-subscribes to `medication_alerts` & `refill_alerts`

## Common Issues & Fixes 🔧

### "Notification doesn't appear when app closed"
- ✅ Have you opened the app at least once? (Required for first startup)
- ✅ Have you granted notification permission?
- ✅ Is your FCM token correct?
- ✅ Check Android battery saver isn't blocking notifications

### "FCM Token not printing"
- ✅ Check that Firebase is initialized
- ✅ Look in Logcat: `flutter logs` 
- ✅ Token appears right after app starts

### "Wrong screen opens when tapping notification"
- ✅ Check `_onNotificationTap()` function
- ✅ Verify payload has correct `type` and `isCreator` values

## Files Modified 📝

- ✅ `lib/main.dart` - Complete rewrite with notification handlers
- ✅ `pubspec.yaml` - Dependencies (already present)
- ✅ `android/AndroidManifest.xml` - Permissions (already present)

## Testing Commands 📲

```bash
# Clean and rebuild
flutter clean && flutter pub get && flutter run

# Check for errors
flutter analyze

# Run on specific device
flutter devices
flutter run -d <device-id>

# View logs
flutter logs

# Send to production
flutter build apk --release
flutter build appbundle --release
```

## Next: Backend Integration 🔗

When you're ready to send notifications from your backend:

```dart
// Your backend sends this payload
{
  "notification": {
    "title": "💊 Take Your Medication",
    "body": "Aspirin - Breakfast time"
  },
  "data": {
    "type": "medication",
    "patientId": "p123",
    "isCreator": "false"
  },
  "token": "USER_FCM_TOKEN"
}

// Your app receives it automatically & shows it!
```

## Video Demo Flow 🎥

1. Close the app completely
2. Send notification from Firebase Console
3. Notification appears on lock screen
4. Tap notification → app opens to correct screen
5. See medication details or refill alert

---

## 🎉 That's it!
Your notification system is production-ready. Just:
1. Send FCM notifications to your users' tokens
2. App receives them automatically
3. Notifications appear even when closed
4. Taps route to correct screen

**Questions?** Check `NOTIFICATION_SETUP.md` for detailed docs.
