# Submission kit

Copy to paste into App Store Connect and the Google Cloud Console. Keep this
in sync with the site at https://bnstrhbn.github.io/driveaudio-site/.

Links used below:

- Homepage / support: https://bnstrhbn.github.io/driveaudio-site/
- Privacy policy: https://bnstrhbn.github.io/driveaudio-site/privacy-policy
- Terms: https://bnstrhbn.github.io/driveaudio-site/terms
- Support email: ben.strohbeen@gmail.com

---

## App Store Connect

### Name (30 chars max)

    Drive Audio

### Subtitle (30 chars max)

    Play audio from Google Drive

### Promotional text (170 chars, editable without a new build)

    Trade mixes and demos through Google Drive and listen anywhere — shared folders, offline downloads, Lock Screen and CarPlay controls.

### Description (4000 chars max)

    Drive Audio turns the audio in your Google Drive into playlists.

    Made for people who trade tracks through Drive — mixes, demos, rehearsal recordings, voice memos — it plays what's in your folders, shared folders and shared drives, and keeps working when you're offline.

    BROWSE WHAT YOU CAN PLAY
    • My Drive, Shared with me, Shared drives and Starred, all in one place
    • Folders with no audio are hidden so you only see what matters
    • Newest files first, folders on top
    • Shared with me shows who shared each item and when
    • Drive shortcuts to audio files just work

    PLAY IT LIKE A PLAYLIST
    • Tap a track, or Play Folder to play everything in it
    • Folders repeat; "previous" restarts or goes back like any music player
    • Total playlist length, track position and remaining time at a glance
    • Full Lock Screen and Control Center controls: scrub, skip, ±15 seconds
    • Works with CarPlay, headphone buttons and Siri
    • Picks up where it left off after a call or another app interrupts

    TAKE IT OFFLINE
    • Download a track, or a whole folder in one tap
    • Tracks you play on Wi‑Fi are cached automatically, so the next listen is instant
    • Knows when a file has a newer version in Drive and offers to update your copy

    PRIVATE BY DESIGN
    • Read‑only access to your Drive — the app never changes, moves or deletes files
    • No accounts, no servers, no ads, no tracking
    • Everything the app stores lives on your device

    Supports MP3, M4A/AAC and WAV. Requires a Google account with Google Drive.

### Keywords (100 chars max, comma separated)

    google drive,audio,player,mp3,wav,mix,demo,music,offline,shared drive,playlist,voice memo

### Support URL

    https://bnstrhbn.github.io/driveaudio-site/

### Marketing URL (optional)

    https://bnstrhbn.github.io/driveaudio-site/

### Privacy Policy URL

    https://bnstrhbn.github.io/driveaudio-site/privacy-policy

### Category

    Primary: Music     Secondary: Utilities

### Age rating

    4+ (no objectionable content; answer "No" to every content question)

### App Privacy (nutrition label)

    Data Not Collected.

    Justification if asked: the app has no analytics, no crash reporting SDK,
    no advertising and no servers. Sign-in tokens and downloaded files stay on
    device and are exchanged only with Google's APIs on the user's behalf,
    which Apple classifies as not "collected" by the developer.

### Export compliance

    Handled by ITSAppUsesNonExemptEncryption = NO in Info.plist (HTTPS only).
    No prompts should appear. If asked: "Uses only exempt encryption (standard
    TLS via Apple frameworks)".

### Content rights

    "Does your app contain, show, or access third-party content?" → Yes.
    The app plays files stored in the user's own Google Drive; the user is
    responsible for their rights to that content. It hosts or distributes
    nothing itself.

### App Review notes (paste into "Notes")

    Drive Audio plays audio files stored in the reviewer's own Google Drive.
    To test, sign in with the demo Google account below; its Drive contains
    sample folders under My Drive plus a folder under "Shared with me".

      Google account: <demo account email>
      Password:       <password>
      (If Google asks for 2-step verification, the backup codes are: <codes>)

    Suggested flow:
    1. Tap "Continue with Google" and sign in with the account above. The
       Google consent screen will show an "unverified app" notice while our
       OAuth verification is pending; tap Advanced → Go to Drive Audio.
    2. My Drive → "Demo Mixes" → tap "Play Folder". Lock the device to test
       Lock Screen controls (scrubber, ±15s, next/previous).
    3. Swipe a track left → Download, or tap "Download All". Enable Airplane
       Mode and confirm downloaded tracks still play.
    4. Tap the title "My Drive" to switch to "Shared with me".

    The app requests only the read-only Drive scope. It never modifies the
    user's Drive. There are no in-app purchases, accounts of our own, or
    server components.

    Contact for review questions: ben.strohbeen@gmail.com

### Screenshots to capture (6.9" required; 6.5" recommended)

    1. Folder view with Play Folder, track list with dates/sizes, mini player
    2. Lock Screen with Now Playing controls
    3. Shared with me with "shared by" lines
    4. Folder download in progress ("3 of 10", Cancel)
    5. Sign-in screen
    Use a folder of real-sounding mix names; avoid other people's names/emails
    in "Shared with me" (use the demo account).

---

## Google Cloud Console — OAuth consent screen

### App information

    App name:            Drive Audio
    User support email:  ben.strohbeen@gmail.com
    App logo:            DriveAudioPlayer/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
                         (resize to 120×120 PNG for upload)
    App home page:       https://bnstrhbn.github.io/driveaudio-site/
    Privacy policy:      https://bnstrhbn.github.io/driveaudio-site/privacy-policy
    Terms of service:    https://bnstrhbn.github.io/driveaudio-site/terms
    Authorized domain:   bnstrhbn.github.io
    Developer contact:   ben.strohbeen@gmail.com

Domain verification: bnstrhbn.github.io must be verified in Google Search
Console (HTML-file or meta-tag method works with GitHub Pages — add the
file/tag to the driveaudio-site repo root/_config).

### Scopes

    https://www.googleapis.com/auth/drive.readonly   (restricted)

Do not add any other scope. If the timestamped-notes feature is built later
using Drive comments, that requires the full `drive` scope and this section
plus the demo video must be redone.

### Scope justification (restricted scope review)

    Drive Audio is an iPhone audio player for files the user already stores in
    Google Drive. Users, typically musicians trading mixes and demos, keep audio
    in their own Drive and in folders shared with them by collaborators.

    The app requests https://www.googleapis.com/auth/drive.readonly in order to:
    (1) list the user's folders, shared folders, shared drives and starred items
    so they can navigate to audio; (2) read file metadata (name, size, modified
    time, sharing user and time, shortcut targets) to display listings and to
    hide folders that contain no audio; and (3) stream or download the audio
    files the user selects for playback, including offline playback.

    A narrower scope is not sufficient: drive.file only grants access to files
    created or opened through the app, but the core purpose is browsing and
    playing audio that already exists in Drive and in folders shared by others,
    which the user never "opens" through a picker. drive.metadata.readonly does
    not permit downloading file content for playback.

    All Drive data is used exclusively to provide these user-facing playback
    features on the user's device. Nothing is sent to any server operated by
    the developer; the app has no backend. Data is never used for advertising,
    never sold, never shared with third parties, and is not used to train
    models. Downloaded audio and cached files are stored in the app's private
    sandbox and deleted when the app is removed. Access tokens are stored in
    the iOS Keychain. The app never writes to Drive.

### Demo video script (YouTube, unlisted; 1–3 minutes)

    0:00  Show the app icon and launch. "This is Drive Audio, an iPhone player
          for audio stored in Google Drive."
    0:10  Tap Continue with Google; show the Google consent screen with the
          drive.readonly permission text clearly visible; approve.
    0:30  Browse My Drive → open a folder → point out file names, sizes and
          dates come from Drive metadata.
    0:45  Tap Play Folder; audio plays. Show the mini player.
    1:00  Tap the title → Shared with me; point out "shared by" and date.
    1:15  Swipe → Download a track; show the downloaded indicator. Turn on
          Airplane Mode; play it. "Files are stored only on the device."
    1:35  Open Google Drive in a browser side-by-side to show nothing was
          modified: no new files, no changed sharing.
    1:50  Show Google Account → Security → Third-party access → Drive Audio,
          and the read-only permission listed. End.

### Publishing status

    Move from Testing to In production BEFORE App Store release. In Testing,
    refresh tokens expire after 7 days and only listed test users can sign in.
    Publishing before verification completes is allowed; users see an
    "unverified app" interstitial until the review is approved.

---

## Pre-submission checklist

    [ ] OAuth consent screen published (In production) and verification
        submitted with the justification + video above
    [ ] bnstrhbn.github.io verified in Search Console
    [ ] App Store Connect record created for com.benstrohbeen.DriveAudioPlayer
    [ ] Demo Google account created with sample audio + a shared folder;
        credentials pasted into App Review notes
    [ ] Screenshots captured on a 6.9" device/simulator
    [ ] Bump CURRENT_PROJECT_VERSION in project.yml for each upload
        (xcodegen generate afterwards)
    [ ] TestFlight external test with at least one non-developer device
    [ ] Age rating, privacy label, category, pricing (Free) set
    [ ] Submit
