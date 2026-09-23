# Drive Audio Player

An iPhone SwiftUI app for browsing Google Drive folders as audio playlists. It streams or explicitly downloads MP3, M4A/AAC, and WAV files, persists resume position, and exposes native Now Playing controls for the Lock Screen and CarPlay.

## Run it

1. Create an iOS OAuth client in Google Cloud with the app bundle identifier `com.benstrohbeen.DriveAudioPlayer`.
2. In the target Build Settings, replace `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID` with values from Google. The latter is usually `com.googleusercontent.apps.<numeric client ID prefix>`. The URL scheme is already wired into `Info.plist`.
3. `xcodegen generate`
4. Open `DriveAudioPlayer.xcodeproj`, select a signing team, then build/run.

The OAuth scope is exactly `drive.readonly`. Downloads are stored privately in Application Support and are user-triggered. This project intentionally defers search, favorites, queue editing, and automatic offline sync.
