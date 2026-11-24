import Foundation

struct JournalAuthentication {
    struct Session: Decodable {
        struct User: Decodable { let id: UUID }
        let access_token: String
        let refresh_token: String
        let expires_in: TimeInterval
        let user: User
    }

    struct Configuration: Decodable {
        let projectURL: URL
        let publishableKey: String

        static func load() throws -> Configuration {
            guard let file = Bundle.main.url(forResource: "authentication", withExtension: "json", subdirectory: "Configuration"),
                  let config = try? JSONDecoder().decode(Configuration.self, from: Data(contentsOf: file)),
                  config.projectURL.scheme == "https", let host = config.projectURL.host,
                  host.hasSuffix(".supabase.co"), config.projectURL.user == nil, config.projectURL.password == nil,
                  config.publishableKey.hasPrefix("sb_publishable_") else {
                throw roroError("Roro sign-in has not been configured yet.")
            }
            return config
        }
    }

    private struct HostedError: Decodable { let error_code: String? }

    // Never forward a credential-bearing request to another origin.
    private final class Transport: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    static let transport: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration, delegate: Transport(), delegateQueue: nil)
    }()

    static func validEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+([.][A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?([.][A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"#
        guard email.utf8.count <= 254, let separator = email.firstIndex(of: "@"),
              email[..<separator].utf8.count <= 64 else { return false }
        return email.range(of: pattern, options: .regularExpression) == email.startIndex..<email.endIndex
    }

    func signIn(email: String, password: String) async throws -> Session {
        guard Self.validEmail(email), !password.isEmpty else { throw roroError("Enter your email address and password.") }
        return try await token(grant: "password", body: ["email": email, "password": password])
    }

    func refresh(_ session: Session) async throws -> Session {
        let next = try await token(grant: "refresh_token", body: ["refresh_token": session.refresh_token])
        guard next.user.id == session.user.id else { throw roroError("Please log in again.") }
        return next
    }

    func signOut(_ session: Session) async throws {
        _ = try await post(path: "logout", query: URLQueryItem(name: "scope", value: "local"),
                           bearer: session.access_token, body: [:])
    }

    private func token(grant: String, body: [String: String]) async throws -> Session {
        let data = try await post(path: "token", query: URLQueryItem(name: "grant_type", value: grant), body: body)
        guard let session = try? JSONDecoder().decode(Session.self, from: data),
              !session.access_token.isEmpty, !session.refresh_token.isEmpty,
              session.expires_in.isFinite, (0...86400 * 7).contains(session.expires_in),
              session.expires_in > 0 else { throw roroError("The sign-in service returned an invalid session.") }
        return session
    }

    private func post(path: String, query: URLQueryItem, bearer: String? = nil,
                      body: [String: String]) async throws -> Data {
        let config = try Configuration.load()
        let endpoint = config.projectURL.appendingPathComponent("auth/v1").appendingPathComponent(path)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [query]
        guard let url = components?.url else { throw roroError("Roro sign-in is unavailable.") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        if let bearer { request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await Self.transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw roroError("Roro sign-in is unavailable.") }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(HostedError.self, from: data))?.error_code
            if code == "email_not_confirmed" { throw roroError("Confirm your email address before logging in.") }
            if code == "invalid_credentials" { throw roroError("Check your email address and password.") }
            if http.statusCode == 429 { throw roroError("Too many attempts. Please try again later.") }
            throw roroError("Roro could not verify your session. Please try again.")
        }
        return data
    }
}
