import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @StateObject private var viewModel: NotificationSettingsViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: NotificationSettingsViewModel(manager: container.notifications))
    }

    private var allowBinding: Binding<Bool> {
        Binding(get: { viewModel.settings.isOn },
                set: { value in Task { await viewModel.setOn(value) } })
    }

    private func binding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
        Binding(get: { viewModel.settings[keyPath: keyPath] },
                set: { value in
                    var updated = viewModel.settings
                    updated[keyPath: keyPath] = value
                    Task { await viewModel.update(updated) }
                })
    }

    var body: some View {
        List {
            Section {
                Toggle("Allow notifications", isOn: allowBinding)
                    .frame(minHeight: 44)
            } footer: {
                Text("Notifications are made on this phone. They never include amounts, so nothing private shows on a locked screen.")
            }

            if let message = viewModel.message {
                Section {
                    Label(message, systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }

            if viewModel.settings.isOn {
                Section("What to tell me") {
                    option("Budget alerts",
                           detail: "When a budget reaches 80% and when it is passed.",
                           isOn: binding(\.budgetAlerts))
                    option("Forecast warning",
                           detail: "When you are on track to spend more than you earn.",
                           isOn: binding(\.forecastWarning))
                    option("New month reminder",
                           detail: "On the 1st at 9:00, to plan the month.",
                           isOn: binding(\.monthlyPlan))
                    option("Reminder if I forget",
                           detail: "At 6 pm if nothing was added for 3 days.",
                           isOn: binding(\.reminder))
                }

                Section {
                    Button {
                        Task { await viewModel.sendTest() }
                    } label: {
                        Label("Send a test notification", systemImage: "bell.badge")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                } footer: {
                    Text("It arrives in a couple of seconds. Lock the phone or go to the Home Screen to see how it looks.")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.load() }
            }
        }
    }

    private func option(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
    }
}
