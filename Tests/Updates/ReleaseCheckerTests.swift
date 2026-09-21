import Foundation

private final class ReleaseProtocol: URLProtocol {
    static var replies: [(Int, String, Bool)] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard request.url?.host == "api.github.com",
              request.url?.path == "/repos/baba9811/blackout-mac/releases",
              request.timeoutInterval == 15 else { fatalError("Unexpected release request") }
        let reply = Self.replies.removeFirst()
        if reply.0 == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let headers = reply.2 ? ["Link": "<https://api.github.com/repos/baba9811/blackout-mac/releases?page=2>; rel=\"next\""] : [:]
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: reply.0, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.1.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct ReleaseCheckerTests {
    static func main() async throws {
        // Numeric, prerelease and build precedence must follow SemVer, not string sorting.
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.2.0", "1.10.0", "2.0.0"]
        assert(ReleaseVersion("0.1.0") != nil)
        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            assert(ReleaseVersion(lower)! < ReleaseVersion(higher)!)
        }
        assert(ReleaseVersion("1.0.0+build.1") == ReleaseVersion("1.0.0+build.2"))
        assert(ReleaseVersion("1.0.0-9999999999999999999999")! < ReleaseVersion("1.0.0-10000000000000000000000")!)
        for invalid in ["", "v1.0.0", "1.0", "01.0.0", "1.0.0-01", "1.0.0-", "1.0.0+", "1.0.0-a..b", "1.0.0\n", "1.0.0/path"] {
            assert(ReleaseVersion(invalid) == nil, invalid)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        func release(_ tag: String, draft: Bool = false, preview: Bool = false, url: String? = nil) -> String {
            let page = url ?? "https://github.com/baba9811/blackout-mac/releases/tag/\(tag)"
            return "{\"tag_name\":\"\(tag)\",\"draft\":\(draft),\"prerelease\":\(preview),\"html_url\":\"\(page)\"}"
        }
        // Preview releases are included, drafts and invalid/untrusted release URLs are excluded.
        ReleaseProtocol.replies = [(200, "[\(release("v0.1.0", preview: true)),\(release("v9.0.0", draft: true)),\(release("v5.0.0", url: "https://evil.example/releases/tag/v5.0.0")),\(release("v01.0.0"))]", false)]
        let preview = try await ReleaseChecker.latestRelease(session: session)
        assert(preview?.version.string == "0.1.0")
        assert(preview?.url.absoluteString == "https://github.com/baba9811/blackout-mac/releases/tag/v0.1.0")
        // A later API page can contain the highest semantic version.
        ReleaseProtocol.replies = [(200, "[\(release("v1.2.0"))]", true), (200, "[\(release("v1.10.0")),\(release("v1.9.0"))]", false)]
        let latest = try await ReleaseChecker.latestRelease(session: session)
        assert(latest?.version.string == "1.10.0")
        ReleaseProtocol.replies = [(200, "[]", false)]
        let empty = try await ReleaseChecker.latestRelease(session: session)
        assert(empty == nil)
        for reply in [(403, "[]", false), (500, "[]", false), (200, "{}", false), (0, "", false)] {
            ReleaseProtocol.replies = [reply]
            do {
                _ = try await ReleaseChecker.latestRelease(session: session)
                fatalError("Expected HTTP, payload or timeout failure")
            } catch {}
        }
        print("Update checks passed: SemVer, preview/draft filtering, trusted URLs, pagination, empty releases and request failures.")
    }
}
