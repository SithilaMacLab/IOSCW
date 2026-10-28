import SwiftUI

struct ForecastView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Not enough data yet", systemImage: "chart.line.uptrend.xyaxis",
                                   description: Text("The forecast needs 3 months of history."))
                .navigationTitle("Forecast")
        }
    }
}

#Preview {
    ForecastView()
}
