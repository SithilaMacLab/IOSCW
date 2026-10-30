import SwiftUI

struct AuthMessageView: View {
    @ObservedObject var session: AuthViewModel

    var body: some View {
        if let message = session.errorMessage {
            banner(message, symbol: "exclamationmark.triangle.fill", color: .red)
                .accessibilityAddTraits(.updatesFrequently)
        }
        if let message = session.infoMessage {
            banner(message, symbol: "checkmark.circle.fill", color: .green)
        }
    }

    private func banner(_ message: String, symbol: String, color: Color) -> some View {
        Label {
            Text(message)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
