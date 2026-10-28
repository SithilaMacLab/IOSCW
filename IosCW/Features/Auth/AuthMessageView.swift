import SwiftUI

struct AuthMessageView: View {
    @ObservedObject var session: AuthViewModel

    var body: some View {
        if let message = session.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .accessibilityAddTraits(.updatesFrequently)
        }
        if let message = session.infoMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }
}

struct AuthSubmitButton: View {
    let title: String
    let isWorking: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isWorking {
                    ProgressView()
                } else {
                    Text(title)
                        .bold()
                }
                Spacer()
            }
            .frame(minHeight: 44)
        }
        .disabled(!isEnabled || isWorking)
    }
}
