import Foundation

enum AuthValidator {
    static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$"#
        return normalized(email).range(of: pattern, options: .regularExpression) != nil
    }

    static func passwordProblem(_ password: String) -> String? {
        if password.count < 8 {
            return "Use at least 8 characters."
        }
        if !password.contains(where: \.isLetter) || !password.contains(where: \.isNumber) {
            return "Include at least one letter and one number."
        }
        return nil
    }

    static func registrationProblem(email: String, password: String, confirmPassword: String) -> String? {
        if !isValidEmail(email) {
            return AuthError.invalidEmail.errorDescription
        }
        if let problem = passwordProblem(password) {
            return problem
        }
        if password != confirmPassword {
            return "The two passwords don't match."
        }
        return nil
    }
}
