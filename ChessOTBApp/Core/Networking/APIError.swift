import Foundation

nonisolated enum APIError: LocalizedError, Equatable {
    case invalidConfiguration, invalidResponse, unauthorized, sessionExpired
    case invalidCredentials, emailNotConfirmed, rateLimited, rejected, unavailable, network

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration, .unavailable: String(localized: "The account service is unavailable. Please try again later.")
        case .invalidResponse: String(localized: "The server returned an unexpected response. Please try again.")
        case .unauthorized, .sessionExpired: String(localized: "Your session has expired. Please sign in again.")
        case .invalidCredentials: String(localized: "The email or password is incorrect.")
        case .emailNotConfirmed: String(localized: "Confirm your email before signing in.")
        case .rateLimited: String(localized: "Too many attempts. Please wait and try again.")
        case .rejected: String(localized: "This request could not be completed. Check your details and try again.")
        case .network: String(localized: "Could not connect. Check your connection and try again.")
        }
    }
}

nonisolated enum AccountError: LocalizedError, Equatable {
    case invalidEmail, invalidPassword, invalidName, invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidEmail: String(localized: "Enter a valid email address.")
        case .invalidPassword: String(localized: "Use at least 8 characters. If your password is very long, shorten it.")
        case .invalidName: String(localized: "Enter a display name of 1–60 characters, without control characters.")
        case .invalidCode: String(localized: "Enter the verification code from your email.")
        }
    }
}
