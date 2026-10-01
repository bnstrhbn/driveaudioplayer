# CASA AL1 security assessment — prepared answers

Google requires an ADA-CASA **AL1** assessment (verified self-assessment) by
**Dec 29, 2026**. At AL1 the developer answers the ADA onboarding
questionnaire with evidence; the lab reviews the evidence and does not test
the app directly. This file pre-fills every question in the official
"CASA AL0 and AL1 Onboarding Questionnaire" for Drive Audio. Copy answers
into the lab's portal verbatim; attach the referenced files as evidence.

Lab: TAC Security (Google-preferred, discounted) — https://casa.tacsecurity.com
Any other ADA-authorized lab works: https://www.appdefensealliance.org/certification/authorized-labs

## Scoping statement (send this first — it shrinks the assessment)

    Drive Audio is a native iOS application only. It has no first-party web
    application, no first-party web API, no backend, no database and no
    cloud infrastructure. The only network endpoints it communicates with
    are Google's (accounts.google.com, oauth2.googleapis.com,
    www.googleapis.com). Authentication is delegated entirely to Google
    OAuth 2.0 (authorization code + PKCE) via Apple's
    ASWebAuthenticationSession; the app has no accounts, passwords, admin
    interfaces or file uploads of its own. It links no third-party
    libraries or SDKs (Apple frameworks only). All user data is stored on
    the device in the iOS sandbox and Keychain.

    Consequently the CASA web-app/API requirements concerning server-side
    authentication, sessions, input handling, DAST targets, TLS server
    configuration, DNS and server secrets are not applicable; the
    applicable profile is the mobile client. Please confirm scope so that
    the DAST/Qualys requirements are recorded as N/A (no first-party
    target) rather than failed.

Source is available for inspection at
https://github.com/bnstrhbn/driveaudioplayer (make the repo public or add
the lab as a collaborator for the duration).

## General

| Field | Answer |
|---|---|
| Gen 1 Application name | Drive Audio |
| Gen 2 Application version | 1.0 (build per `project.yml` CURRENT_PROJECT_VERSION at submission) |
| Gen 3 Link to application | https://www.bstroceramics.com/apps/drive-audio (App Store link once live) |
| Gen 4 Company name | Ben Strohbeen (sole developer) |
| Gen 5 Company address | your address |
| Gen 6 Certification contact name | Ben Strohbeen |
| Gen 7 Version/Date/Author/Changes | 1.0 / submission date / Ben Strohbeen / initial assessment |
| Gen 8 Certification contact email | ben.strohbeen@gmail.com |

## Authentication (Auth 1–12)

**Auth 1 — external user authentication services.**
Google OAuth 2.0 (Google Identity Services) is the sole authentication
service. Flow: authorization code with PKCE (S256), launched in
`ASWebAuthenticationSession`, redirect URI
`com.googleusercontent.apps.<client-id>:/oauth2redirect`, scope
`https://www.googleapis.com/auth/drive.readonly`. Evidence:
`DriveAudioPlayer/Services/GoogleAuthService.swift` (`signIn()`, `exchange()`),
screenshot of the Google consent screen.

**Auth 2–7, 9–12 — proprietary authentication service questions.**
Not applicable. The application has no proprietary authentication service,
no passwords, no account creation, no activation codes and no out-of-band
verifiers. All of these are handled by Google.

**Auth 8 — default accounts on publicly exposed interfaces.**
Not applicable. The application exposes no interfaces; there are no
accounts or default credentials.

## Session management (Session 1–5)

**Session 1 — logout / expiration invalidation.**
Sessions consist solely of Google-issued OAuth tokens held on device.
Logout (`GoogleAuthService.signOut()`) sets the in-memory token to nil and
deletes the Keychain item; the Drive client's token provider is removed
(`AppState.signOut()`). Access tokens expire after 1 hour (Google-enforced);
the app refreshes them proactively 5 minutes before expiry
(`validAccessToken()`), and a refresh rejected by Google (`invalid_grant`)
ends the session and clears stored tokens (`endSession(reason:)`). Users
can also revoke the grant in their Google Account, which invalidates the
refresh token server-side. Evidence: `GoogleAuthService.swift` lines for
`signOut`, `validAccessToken`, `refresh`, `endSession`.

**Session 2 — invalidation after password change.**
Not applicable to the app (no passwords). Google invalidates refresh tokens
for its own password/security events per Google policy; the app treats the
resulting `invalid_grant` as session end (Session 1).

**Session 3 — stateless token validity period.**
Google access tokens: 3600 s (from `expires_in`); stored with `expiresAt`
and never used past expiry. Google refresh tokens: valid until revoked by
the user or Google. The app issues no tokens of its own. Evidence:
`Token` struct and `refreshLeeway` in `GoogleAuthService.swift`.

**Session 4 — dynamically generated session tokens.**
The app generates no session tokens. Per-authorization values that are
generated: PKCE `code_verifier` (32 random bytes via
`UInt8.random(in:)`, SHA-256 challenge) and OAuth `state` (UUID), both
single-use. Evidence: `randomURLSafeString()`, `signIn()` in
`GoogleAuthService.swift`.

**Session 5 — re-authentication before sensitive modifications.**
Not applicable: the app performs no account modifications or transactions.
It is read-only toward Google Drive and has no account of its own.

## Access control (Access 1–7)

**Access 1 — authentication/authorization, roles, enforcement.**
There is a single role: the signed-in Google user acting on their own
Drive. Authorization is enforced entirely by Google Drive on every API call
using the user's bearer token; the app never evaluates permissions itself
and cannot access anything the user cannot. Favorites and notes stored on
device are namespaced by the account's Drive `permissionId`
(`AppState.setAccount`, `FavoritesStore`, `NotesStore`) so two Google
accounts on one device do not see each other's data.

**Access 2 — least privilege.**
The app requests one scope, `drive.readonly` (read-only). It cannot create,
modify, share or delete Drive content. Tokens are used only for
`files.list`, `files.get`, `files.get?alt=media`, `drives.list` and
`about.get`. Evidence: scope string in `signIn()`; endpoint list in
`GoogleDriveService.swift`.

**Access 3 — APIs where user input forms part of URL/parameters.**
The app exposes no APIs. Outbound Google API calls include Drive file and
folder IDs obtained from Drive's own responses (never free text) as path
components and query values, built with `URLComponents`/`URLQueryItem`
(percent-encoded), e.g. `files/{id}` and `q='{id}' in parents`. User-typed
text (note contents) is never sent anywhere.

**Access 4 — IDOR protection.**
Not applicable server-side (no first-party API). Toward Google, any ID the
user could supply is authorized by Google against the user's own
permissions; the app cannot escalate access.

**Access 5 — OAuth 2.0 flow used.**
Authorization Code flow with PKCE (`code_challenge_method=S256`),
`response_type=code`, `access_type=offline`, `prompt=consent`, presented
in `ASWebAuthenticationSession` (system browser context; the app never sees
the user's Google password). The iOS client type has no client secret.
Evidence: `signIn()`/`exchange()` in `GoogleAuthService.swift`; screenshot
of consent screen.

**Access 6 — state and redirect_uri handling.**
`state` is a fresh UUID per attempt and the callback is rejected unless it
matches (`guard parts?.queryItems?.first(where: { $0.name == "state" })?.value == state`).
`redirect_uri` is the fixed reverse-client-ID custom scheme registered in
Info.plist (`CFBundleURLTypes`) and registered with Google for this client;
`ASWebAuthenticationSession` is bound to that scheme so other apps cannot
receive the callback. The authorization code is exchanged with the PKCE
verifier, which never leaves the device until that exchange. Evidence:
`signIn()`; `Info.plist` URL types.

**Access 7 — administrative interfaces with MFA.**
Not applicable: there are no administrative interfaces.

## Communications / cryptography (Comm 1–3)

**Comm 1 — cryptographic operations used.**
1. SHA-256 hash of the PKCE code verifier (CryptoKit `SHA256`).
2. TLS for all network traffic (Apple `URLSession`/`AVFoundation` system
   TLS to Google hosts; HTTPS only).
3. At-rest encryption of OAuth tokens via the iOS Keychain
   (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
4. At-rest encryption of files in the app sandbox via iOS Data Protection
   (system default class).
The app implements no custom encryption, MAC or key management.

**Comm 2 — algorithms, keys, IVs.**
1. SHA-256, no key/IV, output base64url-encoded; input is 32 bytes from the
   system CSPRNG (`UInt8.random`).
2. TLS 1.2+ negotiated by the OS with Google's servers; cipher suites and
   certificates managed by iOS (App Transport Security enforced; no ATS
   exceptions in Info.plist).
3./4. AES-256 managed by iOS/Secure Enclave; keys are never exposed to the
app. Evidence: `Keychain.swift` (accessibility attribute); absence of
`NSAppTransportSecurity` in `Info.plist`.

**Comm 3 — handling cryptographic failures.**
TLS failures surface as `URLError` from `URLSession`; requests fail closed
(no fallback to HTTP) and the user sees an error/paused state
(`AudioPlayerService.fail`, listing error alerts). Keychain write failures
throw `KeychainError` and are handled without data loss (update-in-place,
never delete-then-add; `Keychain.save`). PKCE/state mismatches abort
sign-in (`AuthError.cancelled`). Evidence: `Keychain.swift`,
`GoogleAuthService.swift`, `GoogleDriveService.request` status check.

## Data validation (DVS 1)

**DVS 1 — user file uploads.**
Not applicable. The app accepts no uploads. It downloads audio from Google
Drive to the sandbox and plays it with `AVFoundation`; files are never
executed or interpreted. File names from Drive are sanitized for the local
path (`/` replaced) and stored under a Drive-ID prefix
(`DownloadStore.download`, `PlaybackCache.cache`).

## Configuration (Config 1–4)

**Config 1 — DNS / subdomain takeover.**
Not applicable: the application has no domain of its own and no subdomains.
The marketing/privacy pages are static pages on www.bstroceramics.com
(Vercel) and are not part of the application's runtime.

**Config 2 — logging of credentials.**
The app has no logging framework and writes no logs; it contains no
`print`/`os_log` of tokens or responses. Tokens exist only in memory and in
the Keychain. Evidence: repository search for logging calls (none).

**Config 3 — data left in browser after logout.**
The OAuth flow runs in `ASWebAuthenticationSession`; the app never receives
Google cookies and cannot read browser storage. On logout the app deletes
its Keychain token item and clears account-scoped stores from memory.
Downloaded audio and notes intentionally remain on device (user data,
disclosed in the privacy policy) until the user removes them or deletes the
app.

**Config 4 — secrets management.**
There are no server-side secrets. The Google iOS OAuth client ID is a
public identifier (iOS clients use PKCE and have no client secret). No API
keys are embedded. Per-user OAuth tokens are stored in the iOS Keychain,
device-only, not backed up, not accessible to other apps. Evidence:
`Keychain.swift`, `Info.plist`.

## Lab-executed / tooling items

- **DAST scan (2.1.1, 2.3.x, 3.1.5–6, 5.1.x, 6.2.1, 6.3.1)** — "must be
  provided by Lab". No first-party web application or API exists to scan;
  request the lab record N/A per the scoping statement. Google's APIs are
  out of scope (third party).
- **Qualys SSL Labs scan (4.1.1, 4.1.2)** — no first-party TLS endpoint. If
  the lab insists on an artifact, run https://www.ssllabs.com/ssltest
  against www.bstroceramics.com (the app homepage) and note it is not an
  application endpoint.
- **Dependency scan (6.1.1)** — the app links no third-party libraries
  (no Swift Package Manager, CocoaPods or Carthage manifests; Apple
  frameworks only: SwiftUI, AVFoundation, MediaPlayer, CryptoKit,
  AuthenticationServices, Security, Network). Provide `project.yml` and a
  screenshot of Xcode → Package Dependencies (empty) as evidence.
- **Login log sample (6.5.1)** — the app produces no logs. State this; if a
  sample is required, provide a Console.app capture during sign-in showing
  only system/ASWebAuthenticationSession lines and no credentials.

## Timeline

    Week 1   Register with TAC Security (or another lab), pay, send the
             scoping statement, submit questionnaire + evidence.
    Week 2–4 Answer lab clarifications (typically 1–2 rounds).
    Week 4–6 Lab issues Letter of Validation; it is sent to Google
             automatically or you attach it in the Verification Center.
             Reply to Google's thread confirming completion.
    Annually Recertify before the anniversary (Google emails a reminder).

Deadline: Dec 29, 2026. Start by mid-October to leave slack for a second
clarification round over the holidays.
