import Foundation
import CryptoKit
import CoreServices

enum ReleaseDownloader {
    enum DownloadError: Error { case invalidResponse, invalidChecksum }

    static func download(_ release: AppRelease, to directory: URL,
                         session: URLSession = .shared) async throws -> URL {
        func validate(_ response: URLResponse) throws {
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let finalURL = http.url, finalURL.scheme == "https",
                  ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(finalURL.host)
            else { throw DownloadError.invalidResponse }
        }

        let checksumRequest = URLRequest(url: release.checksumsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        let (bytes, checksumResponse) = try await session.bytes(for: checksumRequest)
        try validate(checksumResponse)
        var checksums = Data()
        for try await byte in bytes {
            guard checksums.count < 65_536 else { throw DownloadError.invalidResponse }
            checksums.append(byte)
        }
        guard let text = String(data: checksums, encoding: .utf8) else { throw DownloadError.invalidChecksum }
        let entries = text.split(whereSeparator: \.isNewline).map { $0.split(whereSeparator: \.isWhitespace) }
            .filter { $0.count == 2 && $0[1] == release.installerName }
        guard entries.count == 1 else { throw DownloadError.invalidChecksum }
        let expected = String(entries[0][0]).lowercased()
        guard expected.count == 64, expected.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw DownloadError.invalidChecksum
        }
        let request = URLRequest(url: release.installerURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try validate(response)
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard size == release.installerSize, let size, (1...64 * 1_024 * 1_024).contains(size) else {
            throw DownloadError.invalidResponse
        }
        let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == release.installerSize, actual == expected else { throw DownloadError.invalidChecksum }
        try Task.checkCancellation()

        var destination = directory.appendingPathComponent(release.installerName)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("BlackoutMac-\(release.version.string)-\(UUID().uuidString).dmg")
        }
        // Keep the same Gatekeeper checks as a browser download before exposing the file in Downloads.
        let quarantine: [String: Any] = [
            kLSQuarantineAgentNameKey as String: "Blackout",
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
            kLSQuarantineDataURLKey as String: release.installerURL,
            kLSQuarantineOriginURLKey as String: release.url
        ]
        try (temporary as NSURL).setResourceValue(quarantine, forKey: .quarantinePropertiesKey)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }
}
