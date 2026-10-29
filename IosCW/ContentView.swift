import SwiftUI

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.pie") {
                DashboardView(container: container)
            }

            Tab("Activity", systemImage: "list.bullet") {
                ActivityView(container: container)
            }

            Tab("Budgets", systemImage: "target") {
                BudgetsView(container: container)
            }

            Tab("Forecast", systemImage: "chart.line.uptrend.xyaxis") {
                ForecastView(container: container)
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(container: container)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .safeAreaInset(edge: .top, spacing: 0) {
            SyncBannerView()
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    return ContentView(container: container)
        .environmentObject(AuthViewModel(service: DevAuthService()))
        .environmentObject(AppLockViewModel())
        .environmentObject(container.sync)
}
