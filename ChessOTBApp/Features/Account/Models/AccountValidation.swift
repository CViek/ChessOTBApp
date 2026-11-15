import Foundation

nonisolated enum AccountValidation {
    static func email(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !value.contains(where: \.isWhitespace), value.utf8.count <= 254 else { throw AccountError.invalidEmail }
        return value
    }

    static func password(_ value: String) throws {
        guard value.count >= 8, value.utf8.count <= 72 else { throw AccountError.invalidPassword }
    }

    static func code(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (6...10).contains(value.count), value.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw AccountError.invalidCode }
        return value
    }
}
