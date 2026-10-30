import SwiftUI

enum AuthRoute: Hashable {
    case login
    case register
    case forgot(email: String)
}

struct AuthActions {
    var go: (AuthRoute) -> Void = { _ in }
    var replace: (AuthRoute) -> Void = { _ in }
}

struct HeroChip: Identifiable {
    let symbol: String
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let drift: CGFloat

    var id: String { symbol }
}

enum AuthHeroStyle {
    case welcome
    case login
    case register
    case reset

    var mainSymbol: String {
        switch self {
        case .welcome: "doc.text.viewfinder"
        case .login: "lock.shield.fill"
        case .register: "person.crop.circle.badge.plus"
        case .reset: "envelope.fill"
        }
    }

    var chips: [HeroChip] {
        switch self {
        case .welcome:
            [HeroChip(symbol: "chart.pie.fill", color: .orange, x: -92, y: -58, drift: 5),
             HeroChip(symbol: "mappin.circle.fill", color: .red, x: 94, y: -34, drift: -6),
             HeroChip(symbol: "icloud.fill", color: .blue, x: -64, y: 84, drift: -5),
             HeroChip(symbol: "faceid", color: .green, x: 84, y: 76, drift: 6)]
        case .login:
            [HeroChip(symbol: "faceid", color: .green, x: -92, y: -50, drift: 5),
             HeroChip(symbol: "key.fill", color: .orange, x: 94, y: -40, drift: -6),
             HeroChip(symbol: "checkmark.seal.fill", color: .blue, x: 78, y: 82, drift: 5)]
        case .register:
            [HeroChip(symbol: "sparkles", color: .orange, x: -90, y: -54, drift: 5),
             HeroChip(symbol: "envelope.fill", color: .blue, x: 94, y: -36, drift: -6),
             HeroChip(symbol: "lock.fill", color: .green, x: -70, y: 82, drift: -5)]
        case .reset:
            [HeroChip(symbol: "lock.rotation", color: .orange, x: -90, y: -52, drift: 5),
             HeroChip(symbol: "key.fill", color: .blue, x: 92, y: -38, drift: -6),
             HeroChip(symbol: "checkmark.circle.fill", color: .green, x: 80, y: 80, drift: 5)]
        }
    }
}

struct AuthHeroView: View {
    let style: AuthHeroStyle
    var size: CGFloat = 220

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    private var effectiveSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? size * 0.65 : size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 230, height: 230)

            Circle()
                .strokeBorder(Color.accentColor.opacity(0.22),
                              style: StrokeStyle(lineWidth: 1.5, dash: [4, 7]))
                .frame(width: 178, height: 178)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.62)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .rotationEffect(.degrees(-8))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 18, y: 10)

            Image(systemName: style.mainSymbol)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(style.chips) { chip in
                Image(systemName: chip.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(chip.color)
                    .frame(width: 42, height: 42)
                    .background(.background, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .offset(x: chip.x, y: chip.y + (floating ? chip.drift : -chip.drift))
            }
        }
        .frame(width: 240, height: 240)
        .scaleEffect(effectiveSize / 240)
        .frame(width: effectiveSize, height: effectiveSize)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct AuthBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [Color.accentColor.opacity(0.16), Color.clear],
                           startPoint: .top,
                           endPoint: UnitPoint(x: 0.5, y: 0.6))
        }
        .ignoresSafeArea()
    }
}

struct AuthScreen<Content: View>: View {
    let style: AuthHeroStyle
    let title: String
    let subtitle: String
    var heroSize: CGFloat = 200
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AuthBackground()

            ScrollView {
                VStack(spacing: 22) {
                    AuthHeroView(style: style, size: heroSize)

                    VStack(spacing: 8) {
                        Text(title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    content
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct AuthFieldChrome: ViewModifier {
    let isFocused: Bool
    let hasError: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2)
            }
    }

    private var borderColor: Color {
        if hasError { return .red }
        return isFocused ? .accentColor : .clear
    }
}

struct AuthTextField<Field: Hashable>: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var focus: FocusState<Field?>.Binding
    let field: Field

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            TextField(title, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused(focus, equals: field)
        }
        .modifier(AuthFieldChrome(isFocused: focus.wrappedValue == field, hasError: false))
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
    }
}

struct AuthPasswordField<Field: Hashable>: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    var submitLabel: SubmitLabel = .go
    var hasError = false
    var focus: FocusState<Field?>.Binding
    let field: Field

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Group {
                if isRevealed {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .submitLabel(submitLabel)
            .focused(focus, equals: field)

            Button {
                isRevealed.toggle()
                focus.wrappedValue = field
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .modifier(AuthFieldChrome(isFocused: focus.wrappedValue == field, hasError: hasError))
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isWorking: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isWorking ? 0 : 1)
                if isWorking {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .disabled(!isEnabled || isWorking)
        .accessibilityLabel(isWorking ? "\(title), please wait" : title)
    }
}

struct AuthSwitchRow: View {
    let question: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(question)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(minHeight: 44)
    }
}

struct RequirementRow: View {
    let met: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(met ? Color.primary : Color.secondary)
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
        .accessibilityValue(met ? "done" : "not yet")
    }
}

struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
