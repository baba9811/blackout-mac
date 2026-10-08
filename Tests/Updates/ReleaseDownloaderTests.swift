import Foundation

private final class DownloadProtocol: URLProtocol {
    static var replies: [(Int, Data, URL?)] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        assert(request.url?.host == "github.com" && request.timeoutInterval == 60)
        let reply = Self.replies.removeFirst()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: reply.2 ?? request.url!, statusCode: reply.0,
                                                            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.1)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct ReleaseDownloaderTests {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DownloadProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let release = AppRelease(version: ReleaseVersion("1.0.0")!,
                                 url: URL(string: "https://github.com/baba9811/blackout-mac/releases/tag/v1.0.0")!, installerSize: 3)
        let payload = Data("abc".utf8)
        let hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let checksum = Data("\(hash)  \(release.installerName)\n".utf8)
        DownloadProtocol.replies = [(200, checksum, nil), (200, payload, nil)]
        let first = try await ReleaseDownloader.download(release, to: directory, session: session)
        let saved = try Data(contentsOf: first)
        assert(saved == payload)
        let properties = try (first as NSURL).resourceValues(forKeys: [.quarantinePropertiesKey])
        assert(properties[.quarantinePropertiesKey] != nil, "Downloads must retain Gatekeeper quarantine")
        DownloadProtocol.replies = [(200, checksum, nil), (200, payload, nil)]
        let second = try await ReleaseDownloader.download(release, to: directory, session: session)
        let preserved = try Data(contentsOf: first)
        assert(first != second && preserved == payload, "Never overwrite an existing download")
        let existing = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        let cases: [[(Int, Data, URL?)]] = [
            [(404, checksum, nil)],
            [(200, checksum, URL(string: "https://evil.example/SHA256SUMS"))],
            [(200, checksum, URL(string: "http://github.com/SHA256SUMS"))],
            [(200, Data("\(hash)  wrong.dmg\n".utf8), nil)],
            [(200, checksum + checksum, nil)],
            [(200, Data("invalid  \(release.installerName)\n".utf8), nil)],
            [(200, checksum, nil), (200, Data("bad".utf8), nil)],
            [(200, checksum, nil), (200, payload + payload, nil)],
            [(200, checksum, nil), (500, payload, nil)],
            [(200, checksum, nil), (200, payload, URL(string: "https://evil.example/update.dmg"))]
        ]
        for replies in cases {
            DownloadProtocol.replies = replies
            do {
                _ = try await ReleaseDownloader.download(release, to: directory, session: session)
                fatalError("Expected invalid download to fail")
            } catch {}
            let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
            assert(remaining == existing)
        }
        print("Download checks passed: checksums, sizes, HTTPS/hosts, failures, quarantine and existing-file preservation.")
    }
}
