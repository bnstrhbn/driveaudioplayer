# Submission kit

Copy to paste into App Store Connect and the Google Cloud Console. Keep this
in sync with the site at https://www.bstroceramics.com/apps/drive-audio.

Links used below:

- Homepage / support: https://www.bstroceramics.com/apps/drive-audio
- Privacy policy: https://www.bstroceramics.com/apps/drive-audio/privacy
- Terms: https://www.bstroceramics.com/apps/drive-audio/terms
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

    https://www.bstroceramics.com/apps/drive-audio

### Marketing URL (optional)

    https://www.bstroceramics.com/apps/drive-audio

### Privacy Policy URL

    https://www.bstroceramics.com/apps/drive-audio/privacy

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

### Screenshots (6.9" required; 6.5" recommended)

    Capture on an iPhone 16 Pro Max (or that simulator) at full resolution,
    save as Marketing/raw/NN-name.png using these slots, then run
    `python3 Scripts/make_screenshots.py Marketing/raw Marketing/screenshots`.
    Output: Marketing/screenshots/6.9/*.png (1320x2868) and 6.5/*.png.

    01-folder      Folder view: Play Folder, tracks with dates/sizes, mini player
    02-note-here   Note Here editor open with the timestamp visible
    03-notes-list  Notes sheet for a track (a few notes, Export button)
    04-lock-screen Lock Screen Now Playing with the scrubber
    05-offline     Folder download in progress ("3 of 10", Cancel)
    06-shared      Shared with me with "shared by" lines (use the demo account)

    Captions live in Scripts/make_screenshots.py (CAPTIONS). Use a folder of
    real-sounding mix names; avoid other people's names/emails.

---

## Google Cloud Console — OAuth consent screen

### App information

    App name:            Drive Audio
    User support email:  ben.strohbeen@gmail.com
    App logo:            DriveAudioPlayer/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
                         (resize to 120×120 PNG for upload)
    App home page:       https://www.bstroceramics.com/apps/drive-audio
    Privacy policy:      https://www.bstroceramics.com/apps/drive-audio/privacy
    Terms of service:    https://www.bstroceramics.com/apps/drive-audio/terms
    Authorized domain:   bstroceramics.com
    Developer contact:   ben.strohbeen@gmail.com

Domain verification: bstroceramics.com must be verified in Google Search
Console (DNS TXT record at your registrar is simplest for an apex domain; you
may already have it verified if Search Console is set up for the shop).

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

### Demo video v2 (YouTube, unlisted; 4–6 minutes)

Google rejected v1 as not showing "the maximum extent of the user-facing
features using the scope" and not showing the consent screen fully
expanded. v2 must prove, on camera, every capability that needs
drive.readonly and why drive.file / drive.metadata.readonly cannot do it.

Before recording:

    - Cloud Console → OAuth consent screen → Scopes: confirm the ONLY scope
      listed is https://www.googleapis.com/auth/drive.readonly. Remove any
      others (e.g. openid/email/profile if present) — "scope matching" means
      the console list must equal what the app requests, and the app requests
      exactly drive.readonly.
    - Sign the demo account out of the app first so the consent screen appears.
    - Demo account Drive should contain: My Drive → "Spring mixes" (5+ tracks,
      one subfolder, one shortcut to an audio file); a folder in "Shared with
      me" owned by ANOTHER account; a Shared drive with audio; one starred
      folder; one empty folder (to show it's hidden).
    - Record with iPhone screen recording, then narrate (or add captions).
      Speak the scope name aloud when it's on screen.

Shot list:

    0:00  Launch. "Drive Audio is an iPhone player for audio the user already
          keeps in Google Drive. It requests one scope, drive.readonly. This
          video shows every feature that uses it."

    0:15  CONSENT SCREEN. Tap Continue with Google, pick the demo account.
          On the permissions screen tap "Show all services"/"See all" if
          present, so the full text "See and download all your Google Drive
          files" is on screen and readable. Pause 3 seconds. Say: "The app
          requests only drive.readonly. There is no write, share or delete
          permission." Tap Continue.

    0:45  MY DRIVE LISTING. Land in My Drive. "This list is Drive's
          files.list, filtered to audio and folders. The empty folder
          'Old sessions' is hidden because the app checks every folder's
          subtree for audio — that requires listing files across the whole
          Drive, which drive.file cannot do because the user has never
          'opened' these files through this app."

    1:15  METADATA. Open "Spring mixes". Point to name, size, modified date
          on each row. "Sizes and dates are file metadata from the same
          listing. Newest first."

    1:30  STREAMING. Tap a track — audio plays. Show the mini player time
          advancing. "Playback streams the file content with files.get
          alt=media. drive.metadata.readonly does not allow this."

    1:50  FOLDER PLAYLIST + LOCK SCREEN. Tap Play Folder. Lock the phone,
          show Now Playing with the track name, scrub, unlock.

    2:10  SHORTCUT. Tap the shortcut item (arrow badge in Drive). It plays.
          "Shortcuts are separate files; the app reads shortcutDetails to
          find the target and streams that. This also needs read access to
          a file the user never opened in-app."

    2:30  SHARED WITH ME. Tap the title → Shared with me. Open the folder
          owned by the other account; show "Shared by <name> · <date>" on
          rows; play a track. "This folder belongs to another user. The app
          reads sharingUser and sharedWithMeTime and streams their file.
          drive.file cannot see files shared by others unless opened through
          a Google Picker, which is not available natively on iOS and would
          not allow browsing a shared folder as a playlist."

    3:05  SHARED DRIVES + STARRED. Title → Shared drives, open one, play a
          track. Title → Starred, show starred folder. "Same read-only
          listing across every corpus the user can access."

    3:30  OFFLINE. Swipe a track → Download. Then tap Download All. Show
          progress. Enable Airplane Mode; play a downloaded track. "Content
          is downloaded with the same read-only endpoint and stored only in
          the app sandbox."

    3:55  NOTES (no Drive write). Tap Note Here, type a note, save. "Notes
          are stored on the device only. The app has no write scope and
          never modifies Drive."

    4:15  SOURCE ACCOUNT UNCHANGED. Open drive.google.com for the demo
          account in a browser (or the Drive app), show "Spring mixes":
          same files, no new files, no changed sharing, Activity panel
          shows no edits by Drive Audio. "Read-only: nothing changed."

    4:45  GOOGLE ACCOUNT PERMISSIONS. myaccount.google.com → Security →
          Third-party apps → Drive Audio. Show the single permission listed.
          Tap Remove access. Return to the app; it shows the "signed out"
          screen. "Revoking access ends the session immediately."

    5:10  Close on the app icon. "One scope, read-only, used only for
          listing and playing the user's own and shared audio."

Upload unlisted; paste the link in the verification form AND in the email
reply. Reply text is in "Review round 1 responses" below.

### Publishing status

    Move from Testing to In production BEFORE App Store release. In Testing,
    refresh tokens expire after 7 days and only listed test users can sign in.
    Publishing before verification completes is allowed; users see an
    "unverified app" interstitial until the review is approved.

---

## Review round 1 responses

### Google — reply to the verification email

Reply in the same thread after (1) the privacy policy is live with the
"How your data is protected" section and (2) the v2 video is uploaded and
its link is updated in Cloud Console → OAuth consent screen → verification.

    Hello,

    Both items have been addressed.

    1. Privacy policy — data protection mechanisms
    The privacy policy at
    https://www.bstroceramics.com/apps/drive-audio/privacy
    now includes a section "How your data is protected" describing, for all
    Google user data handled by the app: encryption in transit (HTTPS/TLS to
    Google only), encryption at rest (OAuth tokens in the iOS Keychain,
    device-only, Secure Enclave-backed; downloaded/cached files in the iOS
    Data Protection-encrypted app sandbox), OS-level isolation, the absence of
    any server-side copy (the app has no backend), least-privilege scope use,
    retention limits and deletion (cache eviction, sign-out erasing tokens,
    app deletion removing all data, Google-side revocation), human access
    (none), and incident handling. The Limited Use disclosure remains in the
    "Google account and Drive access" section.

    2. Demonstration video
    A new video is available at: <YOUTUBE_URL>
    It shows the OAuth consent screen with the single requested scope
    (https://www.googleapis.com/auth/drive.readonly) fully expanded and
    readable, followed by the full extent of the features that use it:
    listing My Drive, folders shared by other users, Shared drives and
    Starred items; hiding folders that contain no audio (which requires
    listing across the user's Drive); displaying file metadata (name, size,
    modified time, sharing user and time); resolving Drive shortcuts to
    their targets; streaming file content for playback; and downloading
    files for offline playback. The video then shows the source Google
    account unchanged (no files created, modified or shared) and access
    being revoked from Google Account permissions.

    Why narrower scopes are insufficient (also shown in the video):
    - drive.file grants access only to files created by the app or opened
      through a Google Picker. The app's core purpose is browsing and playing
      audio that already exists in the user's Drive and in folders shared by
      collaborators, as folder playlists. The Google Picker is a web
      component not available natively on iOS, and would not permit browsing
      a folder's contents or scanning a Drive for folders containing audio.
    - drive.metadata.readonly does not permit downloading file content, so
      it cannot stream or download audio.

    Scope configuration: the app requests exactly one scope,
    https://www.googleapis.com/auth/drive.readonly, and the Cloud Console
    scope list for project driveaudioplayer-509318 contains only that scope.
    The app is in production status; no additional scopes are deployed.

    Thank you,
    Ben Strohbeen

### Apple — reply in App Store Connect (and paste into App Review Notes)

Record the screen recording first (script below), upload it to App Store
Connect via the attachment option in the reply, or host it unlisted and
link it. Then send:

    Thank you for the review. Responses to each item:

    1. SCREEN RECORDING
    Attached / available at: <RECORDING_URL>. Recorded on an iPhone running
    the current iOS release. It begins at app launch and shows: Google sign-in
    (the app has no account system of its own; see note below), browsing
    Google Drive folders, playing a folder as a playlist, Lock Screen
    controls, taking a timestamped note and exporting notes as text,
    downloading a folder for offline playback with Airplane Mode enabled, and
    Sign Out.

    Account registration / deletion: Drive Audio does not create accounts.
    Users sign in with their existing Google account via Google's OAuth
    (Sign in with Google), and the app stores nothing about the user on any
    server — there is no server. "Sign Out" (top-right account menu) erases
    the stored Google tokens from the device. Users can additionally revoke
    the app from their Google Account permissions, which is shown in the
    recording. Because no account is created, there is no account-deletion
    flow to provide.

    User-generated content: the only content users create is private,
    timestamped text notes stored solely on their own device. Notes are
    never uploaded, shared, or visible to any other user of the app, so
    content reporting and blocking mechanisms do not apply. Audio files come
    from the user's own Google Drive.

    Paid content: none. The app is free with no in-app purchases.

    2. PURPOSE AND AUDIENCE
    Drive Audio plays audio files that users already store in Google Drive —
    music mixes, demos, rehearsal recordings, voice memos — as folder
    playlists, online or offline, with Lock Screen and CarPlay controls. Its
    audience is musicians and producers who trade works-in-progress through
    shared Drive folders and need to (a) listen to them conveniently on the
    go, and (b) capture feedback tied to exact timestamps ("kick too loud at
    0:52") and send it back to collaborators as text. Google Drive's own app
    plays one file at a time with no playlist, background queue, offline
    folder download, or timestamped notes.

    3. SETUP AND ACCESS
    Sign in with this Google account, which contains sample audio:
      Email:    <demo account email>
      Password: <password>
      2-Step Verification backup codes (if prompted): <codes>
    Google may show an "unverified app" notice while our Google OAuth
    verification is in progress; tap "Advanced" → "Go to Drive Audio
    (unsafe)" to continue. (Google's verification of this app is under way
    concurrently; it does not affect functionality.)
    Suggested flow: My Drive → "Spring mixes" → Play Folder. Lock the device
    to see Now Playing controls. Tap "Note Here" to add a note; tap the note
    count in the player to view/export notes. Swipe a track or tap
    "Download All", then enable Airplane Mode and play. Tap the title
    ("Spring mixes ▾") to switch to Shared with me / Shared drives / Starred.

    4. EXTERNAL SERVICES
    - Google Sign-In (OAuth 2.0 with PKCE, via ASWebAuthenticationSession)
      for authentication.
    - Google Drive API v3 for listing folders/files and streaming or
      downloading audio, with the read-only scope drive.readonly.
    That is the complete list. No analytics, crash reporting, advertising,
    payment, AI, or backend services are used. The developer operates no
    servers; all app data is stored on the device.

    5. REGIONAL DIFFERENCES
    None. The app functions identically in all regions. It requires a Google
    account with Google Drive; availability of Google services is governed
    by Google.

    6. REGULATED INDUSTRY / PROTECTED MATERIAL
    Not applicable. The app does not operate in a regulated industry and
    contains no third-party content of its own. It plays only files the
    signed-in user has stored in, or been granted access to in, their own
    Google Drive, in the same way a file manager or media player app does.
    The sample audio in the demo account is original material owned by the
    developer.

### Apple — screen recording script (3–4 minutes, physical iPhone)

    Settings → Control Center → add Screen Recording. Charge to 100%, clear
    notifications, Do Not Disturb on. Start recording from the Home Screen.

    0:00  Tap the Drive Audio icon. Sign-in screen appears.
    0:05  Tap Continue with Google → choose demo account → (Advanced → Go to
          Drive Audio if the unverified notice appears) → Continue on the
          consent screen. App opens on My Drive.
    0:35  Open "Spring mixes". Scroll the list. Tap Play Folder — audio plays.
    0:50  Lock the phone (side button). Wake it: show Now Playing on the
          Lock Screen; tap pause/play, drag the scrubber. Unlock.
    1:10  In the app: tap Note Here. Type "kick a touch loud in the intro".
          Save. Show the note count increment and the marker on the scrubber.
    1:30  Tap the note count → notes sheet. Tap the timestamp chip (jumps
          there). Tap Export → Copy Notes. Open Notes app, paste, show the
          formatted text. Return to Drive Audio.
    2:00  Swipe a track → Download. Then tap Download All; let it finish.
    2:20  Control Center → Airplane Mode on. Play a downloaded track. Airplane
          Mode off.
    2:35  Tap the title → Shared with me. Open the shared folder, show
          "Shared by" lines, play a track.
    2:55  Account menu (top-right) → show Clear Cache option → Sign Out.
          Sign-in screen returns.
    3:05  Stop recording. (Optional: show Settings → Drive Audio has no
          special permissions.)

---

## Pre-submission checklist

    [ ] OAuth consent screen published (In production) and verification
        submitted with the justification + video above
    [ ] bstroceramics.com verified in Search Console
    [ ] App Store Connect record created for com.benstrohbeen.DriveAudioPlayer
    [ ] Demo Google account created with sample audio + a shared folder;
        credentials pasted into App Review notes
    [ ] Screenshots captured on a 6.9" device/simulator
    [ ] Bump CURRENT_PROJECT_VERSION in project.yml for each upload
        (xcodegen generate afterwards)
    [ ] TestFlight external test with at least one non-developer device
    [ ] Age rating, privacy label, category, pricing (Free) set
    [ ] Submit
