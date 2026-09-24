import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

actor GoogleAuthService {
    private struct Token: Codable { let accessToken: String; let refreshToken: String?; let expiresAt: Date }
    private var token: Token?
    private var refreshTask: Task<RefreshResult, Never>?
    /// Google access tokens expire after an hour regardless of settings, so
    /// tokens are refreshed a little ahead of expiry rather than at launch only.
    private let refreshLeeway: TimeInterval = 5 * 60

    /// `expired` means Google rejected the refresh token itself (revoked, or a
    /// 7-day test-mode token that lapsed) and the user must sign in again.
    /// `unavailable` is a transient failure such as being offline.
    private enum RefreshResult { case refreshed, expired(reason: String), unavailable }

    /// Why the last session ended, kept so the sign-in screen can say so. Past
    /// sign-outs were silent, which made "why am I signed out again?" unanswerable.
    static var lastSessionEndReason: String? {
        get { UserDefaults.standard.string(forKey: "lastSessionEndReason") }
        set { UserDefaults.standard.set(newValue, forKey: "lastSessionEndReason") }
    }

    /// Restores a saved session. Stays signed in through transient failures so
    /// offline downloads remain reachable; only a dead refresh token ends it.
    func restoreSession() async -> Bool {
        guard let data = Keychain.read(account: "google-token") else {
            if Self.lastSessionEndReason == nil { Self.lastSessionEndReason = "No saved session was found on this device." }
            return false
        }
        guard let saved = try? JSONDecoder().decode(Token.self, from: data) else {
            endSession(reason: "The saved session couldn't be read."); return false
        }
        token = saved
        if saved.expiresAt > Date().addingTimeInterval(refreshLeeway) { return true }
        switch await refreshIfNeeded() {
        case .refreshed, .unavailable: return true
        case .expired(let reason): endSession(reason: reason); return false
        }
    }

    /// Returns an access token that is good for at least `refreshLeeway`,
    /// refreshing (once, even under concurrent callers) when necessary.
    func validAccessToken() async throws -> String {
        guard let token else { throw AuthError.sessionExpired }
        if token.expiresAt > Date().addingTimeInterval(refreshLeeway) { return token.accessToken }
        switch await refreshIfNeeded() {
        case .refreshed: return self.token?.accessToken ?? token.accessToken
        case .expired(let reason): endSession(reason: reason); throw AuthError.sessionExpired
        case .unavailable:
            if token.expiresAt > Date() { return token.accessToken }
            throw AuthError.offline
        }
    }

    private func endSession(reason: String) { signOut(); Self.lastSessionEndReason = reason }

    private func refreshIfNeeded() async -> RefreshResult {
        if let refreshTask { return await refreshTask.value }
        guard let current = token else { return .expired(reason: "No session to refresh.") }
        let task = Task { await refresh(current) }
        refreshTask = task
        defer { refreshTask = nil }
        return await task.value
    }

    func signIn() async throws {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String, !clientID.hasPrefix("YOUR_") else { throw AuthError.missingClientID }
        let verifier = randomURLSafeString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        let redirect = "com.googleusercontent.apps.\(clientID.split(separator: ".").first ?? Substring("")):/oauth2redirect"
        let state = UUID().uuidString
        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [URLQueryItem(name: "client_id", value: clientID), URLQueryItem(name: "redirect_uri", value: redirect), URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/drive.readonly"), URLQueryItem(name: "code_challenge", value: challenge), URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "state", value: state), URLQueryItem(name: "access_type", value: "offline"),
                        // Google only issues a refresh token on first consent unless asked to
                        // re-prompt. Without one the session would die after a single hour.
                        URLQueryItem(name: "prompt", value: "consent")]
        // ASWebAuthenticationSession must be strongly retained for the whole
        // authorization interaction.  A temporary instance can be cancelled
        // while the Google sheet is still presented.
        let webAuthSession = await WebAuthSession(url: c.url!, callbackScheme: URL(string: redirect)!.scheme!)
        let callback = try await webAuthSession.start()
        let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        guard parts?.queryItems?.first(where: { $0.name == "state" })?.value == state, let code = parts?.queryItems?.first(where: { $0.name == "code" })?.value else { throw AuthError.cancelled }
        try await exchange(code: code, verifier: verifier, clientID: clientID, redirect: redirect)
    }

    func signOut() { token = nil; Keychain.delete(account: "google-token"); Self.lastSessionEndReason = nil }

    private func exchange(code: String, verifier: String, clientID: String, redirect: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!); request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form(["code": code, "client_id": clientID, "redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": verifier])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.exchangeFailed(details(from: data))
        }
        struct Response: Decodable { let access_token: String; let refresh_token: String?; let expires_in: TimeInterval }
        let r = try JSONDecoder().decode(Response.self, from: data)
        // A sign-in without a refresh token would expire in an hour; fail loudly
        // now rather than mysteriously later.
        guard let refreshToken = r.refresh_token ?? token?.refreshToken else { throw AuthError.exchangeFailed("Google didn't return a refresh token") }
        token = Token(accessToken: r.access_token, refreshToken: refreshToken, expiresAt: Date().addingTimeInterval(r.expires_in))
        try persist()
        Self.lastSessionEndReason = nil
    }
    private func refresh(_ old: Token) async -> RefreshResult {
        guard let refresh = old.refreshToken else { return .expired(reason: "The saved session had no refresh token.") }
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String else { return .expired(reason: "Google client ID is missing from the app.") }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!); request.httpMethod = "POST"; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type"); request.httpBody = form(["refresh_token": refresh, "client_id": clientID, "grant_type": "refresh_token"])
        guard let (data, response) = try? await URLSession.shared.data(for: request), let status = (response as? HTTPURLResponse)?.statusCode else { return .unavailable }
        guard status == 200 else {
            // Google answers a revoked or lapsed refresh token with 400/401
            // `invalid_grant`; anything else (5xx, rate limits) is transient.
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            guard (status == 400 || status == 401), body["error"] as? String == "invalid_grant" else { return .unavailable }
            let description = body["error_description"] as? String ?? "invalid_grant"
            return .expired(reason: "Google rejected the refresh token (\(description)). This happens if access was revoked, or after 7 days while the app is in Testing mode.")
        }
        struct Response: Decodable { let access_token: String; let expires_in: TimeInterval; let refresh_token: String? }; guard let r = try? JSONDecoder().decode(Response.self, from: data) else { return .unavailable }
        token = Token(accessToken: r.access_token, refreshToken: r.refresh_token ?? refresh, expiresAt: Date().addingTimeInterval(r.expires_in))
        do { try persist() } catch { Self.lastSessionEndReason = "Warning: couldn't save the refreshed session (\(error))." }
        return .refreshed
    }
    private func persist() throws { try Keychain.save(JSONEncoder().encode(token), account: "google-token") }
    private func form(_ items: [String: String]) -> Data? { items.map { "\($0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8) }
    private func randomURLSafeString() -> String { Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }).base64URLEncodedString() }
    private func details(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? String else { return nil }
        let description = object["error_description"] as? String
        return [error, description].compactMap { $0 }.joined(separator: ": ")
    }

    enum AuthError: LocalizedError {
        case missingClientID, cancelled, sessionExpired, offline, exchangeFailed(String?)
        var errorDescription: String? {
            switch self {
            case .missingClientID: "Google OAuth isn’t configured yet."
            case .cancelled: "Sign in was cancelled."
            case .sessionExpired: "Your Google session expired. Please sign in again."
            case .offline: "Couldn’t reach Google. Check your connection and try again."
            case .exchangeFailed(let details): "Google sign-in failed\(details.map { ": \($0)" } ?? ". Try again.")"
            }
        }
    }
}

private extension Data { func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") } }

@MainActor private final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    let url: URL
    let callbackScheme: String
    init(url: URL, callbackScheme: String) { self.url = url; self.callbackScheme = callbackScheme }
    func start() async throws -> URL { try await withCheckedThrowingContinuation { continuation in
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
            if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? GoogleAuthService.AuthError.cancelled) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    } }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor() }
}
