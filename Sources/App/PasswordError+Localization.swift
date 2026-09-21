import Foundation

extension PasswordError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidPassword: return L("Enter a password (up to 1,024 UTF-8 bytes).")
        case .mismatch: return L("The new passwords do not match.")
        case .incorrectCurrent: return L("The current password is incorrect.")
        case .damagedSettings: return L("The saved password settings could not be read. Use Forgot Password in Settings to recover.")
        case .hashingFailed: return L("The password could not be processed. Please try again.")
        }
    }
}
