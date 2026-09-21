import Foundation

struct AppRelease: Sendable {
    let version: ReleaseVersion
    let url: URL
}

enum ReleaseChecker {
    enum CheckError: Error { case invalidResponse, http(Int) }

    private struct APIRelease: Decodable {
        let tagName: String
        let draft: Bool
        let htmlUrl: String

        var release: AppRelease? {
            guard !draft, tagName.hasPrefix("v"),
                  let version = ReleaseVersion(String(tagName.dropFirst())) else { return nil }
            let expected = "https://github.com/baba9811/blackout-mac/releases/tag/\(tagName)"
            guard htmlUrl == expected, let url = URL(string: expected) else { return nil }
            return AppRelease(version: version, url: url)
        }
    }

    static func latestRelease(session: URLSession = .shared) async throws -> AppRelease? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var latest: AppRelease?
        // ponytail: cap checks at 1,000 releases; extend pagination if the release history outgrows this.
        for page in 1...10 {
            try Task.checkCancellation()
            let url = URL(string: "https://api.github.com/repos/baba9811/blackout-mac/releases?per_page=100&page=\(page)")!
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("Blackout", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, response.url == url else {
                throw CheckError.invalidResponse
            }
            guard response.statusCode == 200 else { throw CheckError.http(response.statusCode) }
            let releases = try decoder.decode([APIRelease].self, from: data)
            for release in releases.compactMap(\.release) {
                if latest == nil || release.version > latest!.version { latest = release }
            }
            // Construct subsequent URLs ourselves; never follow a server-provided arbitrary link.
            if response.value(forHTTPHeaderField: "Link")?.contains("rel=\"next\"") != true { return latest }
        }
        throw CheckError.invalidResponse
    }
}
