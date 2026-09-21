import Foundation
import CommonCrypto
import Security

enum PasswordError: Error {
    case invalidPassword, mismatch, incorrectCurrent, damagedSettings, hashingFailed


}

struct UnlockPassword: Codable {
    let salt: Data
    let digest: Data

    static func create(_ password: String) throws -> UnlockPassword {
        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
        }
        guard result == errSecSuccess else { throw PasswordError.hashingFailed }
        return UnlockPassword(salt: salt, digest: try derive(password, salt: salt))
    }

    func matches(_ password: String) -> Bool {
        guard salt.count == 16, digest.count == 32,
              let candidate = try? Self.derive(password, salt: salt) else { return false }
        // Compare every byte, including for incorrect passwords.
        return zip(candidate, digest).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    private static func derive(_ password: String, salt: Data) throws -> Data {
        let normalized = password.precomposedStringWithCanonicalMapping
        guard !normalized.isEmpty, normalized.utf8.count <= 1_024 else {
            throw PasswordError.invalidPassword
        }
        var digest = Data(count: 32)
        let result = normalized.withCString { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                digest.withUnsafeMutableBytes { output in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes, normalized.utf8.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                        output.bindMemory(to: UInt8.self).baseAddress!, output.count
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw PasswordError.hashingFailed }
        return digest
    }
}

final class PasswordSettings {
    static let key = "unlockPassword.v1"
    private let defaults: UserDefaults
    private(set) var revision = 0

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool { defaults.object(forKey: Self.key) != nil }

    func load() throws -> UnlockPassword? {
        guard isEnabled else { return nil }
        guard let data = defaults.data(forKey: Self.key),
              let password = try? JSONDecoder().decode(UnlockPassword.self, from: data),
              password.salt.count == 16, password.digest.count == 32 else {
            throw PasswordError.damagedSettings
        }
        return password
    }

    func update(enabled: Bool, current: String, new: String, confirmation: String) throws {
        let existing = try load()
        if let existing, !existing.matches(current) { throw PasswordError.incorrectCurrent }
        if !enabled {
            defaults.removeObject(forKey: Self.key)
            revision += 1
            return
        }
        guard new == confirmation else { throw PasswordError.mismatch }
        let password = try UnlockPassword.create(new)
        defaults.set(try JSONEncoder().encode(password), forKey: Self.key)
        revision += 1
    }

    // Call only after macOS owner authentication succeeds for this settings revision.
    func resetAfterOwnerAuthentication(ifUnchanged expectedRevision: Int) -> Bool {
        guard revision == expectedRevision else { return false }
        defaults.removeObject(forKey: Self.key)
        revision += 1
        return true
    }
}
