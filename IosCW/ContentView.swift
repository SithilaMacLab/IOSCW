import SwiftUI

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            DashboardView(container: container)
                .tabItem { Label("Dashboard", systemImage: "chart.pie") }

            ActivityView(container: container)
                .tabItem { Label("Activity", systemImage: "list.bullet") }

            BudgetsView(container: container)
                .tabItem { Label("Budgets", systemImage: "target") }

            ForecastView(container: container)
                .tabItem { Label("Forecast", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView(container: container)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
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
