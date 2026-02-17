# Dream Catcher

A lucid dreaming app for iPhone and Apple Watch. It detects REM sleep windows using HealthKit data and delivers subtle audio + haptic cues to trigger lucidity, preceded by a pre-sleep training session that conditions your brain to recognize the cue.

## Requirements

- Xcode 26+
- iOS 26.0+ / watchOS 26.0+
- Apple Developer account (for HealthKit entitlements and device deployment)
- iPhone with Apple Watch paired

## Setup

1. Clone the repo:
   ```
   git clone https://github.com/your-org/Dream-Catcher.git
   cd Dream-Catcher
   ```

2. Create your local config:
   ```
   cp Local.xcconfig.template Local.xcconfig
   ```

3. Edit `Local.xcconfig` with your values:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   BUNDLE_ID_PREFIX = com.yourname.DreamCatcher
   ```
   Your Team ID is in [Apple Developer account settings](https://developer.apple.com/account) or in Xcode under Signing & Capabilities.

4. Open `Dream_Catcher.xcodeproj` in Xcode.

5. Build and run on a physical device (HealthKit and Watch connectivity require real hardware).

## How it works

1. **Nightly update** -- the app fetches your last 45 nights of sleep data from HealthKit, builds a probability curve of when you enter REM, and schedules cue windows for tonight.

2. **Start sleep session** -- when you go to bed, tap "Start Sleep Session":
   - If needed, a volume calibration wizard sets the audio cue to your hearing threshold.
   - A 3-minute pre-sleep training session plays the cue while guiding you through awareness exercises (spoken aloud via text-to-speech). This creates the learned association that makes the cue effective during REM.
   - After training, overnight monitoring begins. The iPhone plays a silent keepalive audio loop; the Watch runs a REM classifier.

3. **During sleep** -- when a REM window is detected, the same audio cue plays at calibrated volume on the iPhone and a haptic tap fires on the Watch.

## Project structure

```
Dream_Catcher/              iPhone app
  Audio/                    Cue generation and playback
  Background/               Background tasks, HealthKit observation, Sleep Focus
  Calibration/              Volume calibration wizard
  Health/                   HealthKit client, sleep data extraction
  Scheduling/               REM cue scheduling (notifications + live)
  Training/                 Pre-sleep TLR conditioning session
  UI/                       SwiftUI views
  WatchSync/                iPhone-to-Watch communication
  Models/                   SwiftData models
  Data/                     Persistence layer
  Analisys/                 REM curve analysis, window selection

Watch_Dream_Catcher Watch App/   watchOS companion
  Audio/                    Haptic cue engine
  Background/               Extended runtime sleep session
  Scheduling/               Watch-side cue scheduling
  UI/                       Watch views
  WatchSync/                Watch-side communication
```

## Permissions

The app requires:
- **HealthKit** -- reads sleep analysis data (no write access)
- **Background Modes** -- audio playback (silent keepalive during sleep)
- **Notifications** -- scheduled cue delivery as fallback
