import Foundation

struct ReleaseVersion: Comparable, Sendable {
    let string: String
    private let numbers: [String]
    private let prerelease: [String]

    init?(_ string: String) {
        let pattern = #"\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z"#
        guard string.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let parts = string.split(separator: "+", maxSplits: 1)[0].split(separator: "-", maxSplits: 1)
        numbers = parts[0].split(separator: ".").map(String.init)
        prerelease = parts.count == 2 ? parts[1].split(separator: ".").map(String.init) : []
        guard !prerelease.contains(where: {
            $0.allSatisfy(\.isNumber) && $0.count > 1 && $0.first == "0"
        }) else { return nil }
        self.string = string
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.numbers == rhs.numbers && lhs.prerelease == rhs.prerelease
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        // Compare digit strings without overflowing Int on a remote version tag.
        func numericLess(_ left: String, _ right: String) -> Bool {
            left.count == right.count ? left < right : left.count < right.count
        }
        for (left, right) in zip(lhs.numbers, rhs.numbers) where left != right {
            return numericLess(left, right)
        }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let leftNumeric = left.allSatisfy(\.isNumber)
            let rightNumeric = right.allSatisfy(\.isNumber)
            if leftNumeric && rightNumeric { return numericLess(left, right) }
            if leftNumeric != rightNumeric { return leftNumeric }
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}
