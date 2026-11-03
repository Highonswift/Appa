# Appa App — Phases 1 to 4

A Tamil-first, voice-first Android app for Appa, built from the
[product roadmap](https://claude.ai/artifact/B9DWTfLX9QfvY3wMPEGWxP). It is a bridge to
people, not a replacement for them: every feature ends with Appa talking to someone.

## What is in this build

| Feature | What it does |
|---|---|
| Story of the day | One Tamil question each morning, read aloud. Appa answers by voice. Family hear it and reply with a voice note. |
| Call someone today | Suggests one person a day: whoever he has gone longest without calling. One tap calls; "இன்று வேண்டாம்" (not today) is accepted with no guilt and no second ask. |
| Payment walkthrough with practice mode | A spoken, step-by-step walkthrough of sending money and checking balance on a mock UPI app with a fake ₹5,000 balance. Moves no money and can be repeated without limit. Never grades him. |
| Medicine and sleep | Three daily reminders (morning sleep check-in, medicine, evening wind-down) and a one-tap "how did you sleep?" with a 7-day view. |

**Phase 2 — learning and daily structure:**

| Feature | What it does |
|---|---|
| Walkthrough library | 10 spoken, step-by-step practice walkthroughs on mock apps: WhatsApp (voice note by press-and-hold, video call, photo), UPI (send, balance, shop QR), OTP safety, bus ticket, food order (+ Tamil dish glossary), Maps directions. After finishing one, he can mark "I did it in the real app myself". |
| Scam alert of the week | A short Tamil story about a real scam pattern (12 in rotation), its giveaway sign and what to do. One tap forwards it to friends, signed by him. |
| Daily plan he owns | He builds today's or tomorrow's checklist from suggestions, by typing, or by speaking (Tamil speech-to-text). It never nags. Family can add one item a day each, shown as "அம்மா கேட்டது" (a request, not an order). |
| Health log | BP and sugar readings with gentle typo checks (no "high/low" verdicts), 8-week line charts, and a 30-day page to show or send to the doctor. |
| Family question board | Family ask by voice or text from their own phones (or on his). He hears the question and answers by voice. |
| What family can see | One screen, in his words, listing everything shared. Health, sleep and plan are off until he turns them on. Turning one off deletes the family's copy. |
| Weekly review | Settings → வாராந்திர ஆய்வு: the numbers for the Sunday review (stories, calls, plan days, walkthroughs, real-world wins, questions, 4 weeks of sleep) and the Phase 2 exit criteria. |

The family phone now has four tabs: stories, questions, Appa's day (only what he shares, plus one
request a day) and settings.

**Phase 3 — connection and companion:**

| Feature | What it does |
|---|---|
| Call someone today, extended | Contacts now have a group (family, relative, depot/work friend, friend, neighbour) and an optional birthday. After a call he is asked once "நன்றாக இருந்ததா?" (good / okay / not good, or skip); good calls lift that person in the daily suggestion, not-good ones lower them. Birthdays and festivals show the day before and on the day, with people to call — on his home screen, not as extra notifications. |
| Story archive | Stories grouped by theme (childhood and village, TNSTC years, repairs, colleagues, family, life lessons) with progress towards 40. Family can ask a follow-up about any story (from their phone, or on his) and it becomes the *next* day's question. Stories can be written out (transcribed) and the whole archive exported as one zip — every recording plus a text file — to give to the grandchildren. |
| Tamil voice companion | "பேசலாம்": he speaks, it listens and reflects in plain Tamil. Enforced by the app, not just asked of the model: an outward suggestion (call a person / tomorrow's story / today's plan) by every third reply; a soft 15-minute limit (he can set 5/10/15) that wraps up and points to a real activity; any affection, friendship or "I miss you" sentence is removed; health, money and family conflict always get "talk to the doctor / Ragul" and a call button, never advice. Conversations are not saved anywhere; only session length, whether it ended outward, and facts he can read and delete on "நீங்கள் சொன்னவை". |
| Pattern surfacing, with his consent | Four bad nights in a row, three companion sessions in a week with "unwanted/angry", or a week without a call: the app tells him first and asks "shall I tell Ragul?". Yes sends one short sentence (never a transcript); no is respected and not asked again that week. He can set "always tell" per pattern himself. |
| Weekly review, extended | Archive count, companion sessions, average length this week vs last, share ending in an outward action, whether he changed a setting himself, and a stop-and-rethink warning if sessions are getting longer. |

**Phase 4 — purpose and the wider world:**

| Feature | What it does |
|---|---|
| Help others | People outside the family (Ragul's team at first, then an invited circle) ask him about vehicles, house repairs, electrical work, offices and pension paperwork, by text or voice, and hear his voice answer. They join with a separate **help code** (Settings → உதவி கேட்பவர்கள்) on a third phone type, "நண்பர்"; the database lets them see only their own questions and his answers to them — never his stories, health, plan, family or codes. On his phone these appear under the question board in their own section, with the topic. |
| Repair diary | "நான் சரிசெய்தவை": what he fixed, for whom, with a photo, a voice note and the date. Stays on his phone. |
| Household ledger | Off until he turns it on himself. He says or types "காய்கறி 200" / "பால் ஐம்பது ரூபாய்"; monthly total, by item, compared with last month. Stays on his phone. |
| Local groups and events | Family add temple events, association meetings, walking or reading groups (from their phone or his). One tap puts one in his plan, one tap invites a friend; afterwards he's asked once "போனீர்களா?". |
| TNSTC retirees circle | A private group on his old colleagues' own phones (circle code, same "நண்பர்" phone type): one voice prompt a week that everyone answers, everyone's answers as a shared archive, and birthdays this week. Members see nothing of his family data. |

The weekly review now also tracks the Phase 4 exit criteria: outside questions answered, events attended,
repair and ledger entries.

Still left out: his own bank's app and pension-portal walkthroughs (need his real details first),
dish photos, and push notifications (family and circle members see new items when they open the app).

## Tech stack (all free)

| Part | Choice | Why |
|---|---|---|
| App | Flutter 3.47 (Dart 3.13), Android first | One codebase, strong accessibility, good Tamil rendering |
| Tamil voice out | `flutter_tts` → the phone's own Google TTS engine | Free, offline, no API key |
| Voice recording | `record` (AAC, about 0.5 MB/min) + `just_audio` | Works offline |
| Reminders | `flutter_local_notifications`, scheduled on the phone | No server or push service |
| Calls | `url_launcher` → the phone's dialer | |
| Storage | `shared_preferences` + audio files on the phone | Offline-first; nothing leaves the phone unless sync is on |
| Family sync (optional) | Supabase free tier: Postgres, private storage bucket, anonymous sign-in, row-level security | Family hear stories on their own phones |
| Tamil voice in | `speech_to_text` → the phone's own Google speech recogniser | Free, no API key (daily plan dictation) |
| Forwarding | `share_plus` → the phone's share sheet | He picks WhatsApp/SMS and the people |
| Charts | Hand-drawn `CustomPainter`, colour-blind-safe palette | No chart library needed |
| Companion + transcripts | Google Gemini API, free tier (`gemini-2.5-flash` by default), plain REST via `http`, behind a swappable `CompanionModel` interface | Free; good Tamil. **Trade-off chosen by the family:** on the free tier Google may use the requests to improve its products. Turning on billing for the same key stops that; Claude or an on-device model can be plugged in by implementing one class. |
| Archive export | `archive` (zip) + the share sheet | |

No analytics SDKs, no ad SDKs, no trackers. The only model calls are the companion and story
transcription, and only after the family enters a Gemini key. Walkthroughs are
scripted (`lib/logic/walkthrough.dart`), so they are deterministic and never confidently wrong.

## Run it on a phone

Prerequisites on the Mac: [Flutter](https://docs.flutter.dev/get-started/install/macos/mobile-android)
and Android Studio (for the Android SDK). Both are free.

```bash
cd /Users/ragulkts/Highonswift/Appa
flutter pub get
flutter test                 # 101 tests
flutter run                  # with Appa's phone plugged in, USB debugging on
flutter build apk --release  # APK at build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the debug key for now. That is fine for installing on
family phones by hand. Create a real signing key before any Play Store upload.

### On Appa's phone, once

1. Open the app and choose **அப்பாவின் போன்** (Appa's phone), then **தொடங்கலாம்**.
2. Allow notifications and the microphone when asked.
3. Tamil voice: **Settings → Accessibility → Text-to-speech → Speech Services by Google →
   Install voice data → தமிழ் (India)**. It's free and works offline. Use the app's
   *குரலைச் சோதி* button to test it.
4. In **குடும்பத்தினருக்கு: அமைப்புகள்** (settings), add his five people from Phase 0
   (name, number, relation) and set the reminder times and medicine name.
5. For the companion and transcripts (optional): get a free key at
   [aistudio.google.com/apikey](https://aistudio.google.com/apikey) and paste it in settings under
   **பேசும் வசதி (Gemini, இலவசம்)**. Without a key the "பேசலாம்" tile stays hidden.
6. Sit with him for the first use, and for his first companion conversation.

### Family sync (optional, free)

Without sync, everything works on Appa's phone alone, and family can record a reply on
his phone during a visit. To let family listen and reply from their own phones:

1. Create a free project at [supabase.com](https://supabase.com).
2. In the dashboard: **SQL Editor → New query →** paste `supabase/schema.sql` **→ Run**, then
   the same for `supabase/migrations/002_phase2.sql`, `003_phase3.sql` and `004_phase4.sql`, in
   order (already set up earlier? run only the ones you haven't).
3. **Authentication → Sign In / Providers →** turn on **Allow anonymous sign-ins**.
4. **Project Settings → API**: copy the Project URL and the publishable (anon) key.
5. On Appa's phone: settings → paste both → **பகிர்தலைத் தொடங்கு** (start sharing). It shows a
   six-character family code.
6. On each family phone, choose **குடும்பத்தினர் போன்** (family phone) at first launch, then
   in settings paste the same URL and key plus the family code, and tap **சேர்** (join).

Always shared once sync is on: his stories, family replies and questions, and his answers.
Health, sleep and the daily plan are shared only while he has switched them on
(**குடும்பம் என்ன பார்க்கிறது** on his home screen). Calls, walkthroughs and reminder times never
leave his phone. Row-level security limits every row and voice file to one household, and
refuses family reads of anything he has not shared.

## Code map

```
lib/
  main.dart                 app start, reminder taps, Appa vs family home
  app_state.dart            all state (ChangeNotifier) + offline-first sync logic
  models/models.dart        Contact, Story, StoryReply, SleepEntry, CallEvent, ReminderSettings
  data/story_prompts.dart   30 Tamil story questions (Appa should review them)
  data/local_store.dart     on-device storage
  logic/daily_picker.dart   question of the day, person of the day, sleep window (pure)
  logic/walkthrough.dart    walkthrough engine: mock screens as data, actions, golden path (pure)
  logic/phase2.dart         scam of the week, plan rules, health checks/summary, weekly review (pure)
  data/walkthroughs.dart    the 10 walkthrough scripts, in display order
  data/scam_stories.dart    12 scam-pattern stories
  data/dish_glossary.dart   18 menu dishes explained in Tamil
  data/festivals.dart       festival dates for greeting nudges (lunar ones: verify yearly)
  logic/phase3.dart         tuned call choice, occasions, follow-ups, patterns, reply filter, stats (pure)
  logic/companion.dart      the companion's agent layer: system prompt + enforced rules
  logic/archive_export.dart story archive zip (audio + transcript text)
  logic/phase4.dart         spoken ledger parsing, month totals, events, ISO weeks, circle prompts (pure)
  services/companion_model.dart  CompanionModel interface, Gemini REST implementation, fake
  services/                 speech, dictation + sharing, audio, reminders, phone, sync (each with a fake)
  widgets/health_chart.dart two-series line chart with legend, end labels, tap-to-read
  screens/                  setup, home, story, questions, call, plan, walkthrough, scam,
                            routine, health, sharing (+ weekly review), settings, family (tabs),
                            companion (+ memory), archive, diary (repairs, ledger),
                            world (events, circle, friend phone)
supabase/schema.sql         Phase 1 tables, RPCs, row-level security, private voice bucket
supabase/migrations/        002_phase2.sql: questions, plan, health, sleep, sharing + consent RLS
                            003_phase3.sql: story follow-ups, transcripts, pattern alerts
                            004_phase4.sql: guest role locked out of all family data, help code,
                            outside questions, events, retirees circle (own tables + bucket)
test/                       unit tests (logic) + widget tests (screens)
```

## Before it reaches Appa

- **Tamil review.** Every script line (story questions, walkthrough narration, buttons) is
  plain spoken Tamil written by the team. Have the Tamil content writer and Appa
  rewrite anything that sounds bookish or patronising.
- **Phase 0 inputs.** Put his three willing TNSTC stories at the top of
  `lib/data/story_prompts.dart`, and his five people in settings.
- **Not yet verified on a device.** The tests run on the Flutter test engine, and the
  Android build has not been run yet. Test recording, playback, Tamil TTS,
  reminders and one-tap calling on his actual phone before handing it over.
- **Walkthrough order.** Reorder `walkthroughLibrary` in `lib/data/walkthroughs.dart` to the
  ranking Appa gives at the week-3 review. Refresh `scam_stories.dart` with what is circulating locally.
- **Ragul and Amma's commitment.** At least two real questions a week on the question board
  before it ships to him, or he will notice it is empty.
- **Companion, before he uses it.** Have Ragul and the team talk to it for a week first, in Tamil,
  trying to make it advise on medicine or money and trying to make it say it misses them. Check
  that transcription accepts the `.m4a` recordings (sent as `audio/mp4`).
- **Festival dates.** Lunar festivals in `lib/data/festivals.dart` are approximate; check them
  against a panchangam and add next year's.
- **Exit criteria (from the roadmap).** Phase 3: 40+ stories in the archive; companion sessions
  average under 15 minutes and at least a third end in a call, story or plan; he has changed a
  companion setting himself. Stop and rethink if sessions lengthen week over week, if he prefers it
  to calling people, or if Amma says it adds friction.
- **Phase 4 setup.** Seed the help board truthfully (roadmap: "we have a real question about a
  truck"); a few real questions a month is enough. Ask two or three old colleagues to install the
  app as "நண்பர்" and join the circle before telling him about it, so it isn't empty.
- **Phase 4 exit criteria.** At least five questions answered from outside the immediate family; at
  least two local events attended through the app; diary or ledger entries he made unprompted.
- **Earlier exit criteria.** Phase 1: used on 10 of 14 days unprompted, at least 5 stories,
  at least 3 calls from the nudge, at least 10 complaints. Phase 2: at least 4 walkthroughs and one
  real thing done without help, 6 family questions answered, a visible sleep trend, and Amma's
  word on whether the daily plan reduces friction. The weekly review screen tracks these.
