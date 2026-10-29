import MapKit
import SwiftUI

struct SpendingMapView: View {
    @StateObject private var viewModel: SpendingMapViewModel
    @State private var position: MapCameraPosition = .automatic

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SpendingMapViewModel(expenses: container.expenses))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $viewModel.period) {
                ForEach(MapPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if viewModel.areas.isEmpty {
                ContentUnavailableView {
                    Label("No places yet", systemImage: "mappin.slash")
                } description: {
                    Text("Scan a receipt and allow location, and the areas where you spend will show up here.")
                }
            } else {
                map
                areaList
            }
        }
        .navigationTitle("Where you spend")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.areas) { _, _ in
            position = .automatic
        }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(Array(viewModel.areas.enumerated()), id: \.element.id) { index, area in
                Annotation(area.name, coordinate: area.coordinate) {
                    marker(rank: index + 1, area: area)
                }
            }
        }
        .frame(height: 280)
        .accessibilityLabel("Map of the areas where you spend")
    }

    private func marker(rank: Int, area: AreaTotal) -> some View {
        let share = viewModel.share(of: area)
        let size = 30 + 30 * share

        return ZStack {
            Circle()
                .fill(Color.red.opacity(0.3 + 0.5 * share))
            Circle()
                .stroke(Color.red, lineWidth: 2)
            Text("\(rank)")
                .font(.footnote.bold())
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank), \(area.name), \(CurrencyFormatter.lkr(area.total))")
    }

    private var areaList: some View {
        List {
            Section {
                ForEach(Array(viewModel.areas.enumerated()), id: \.element.id) { index, area in
                    Button {
                        withAnimation {
                            position = .region(MKCoordinateRegion(
                                center: area.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                        }
                    } label: {
                        AreaRow(rank: index + 1, area: area, share: viewModel.share(of: area))
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Ranked by total spent")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.unplacedCount > 0 {
                        Text("\(viewModel.unplacedCount) expenses in this period have no place saved.")
                    }
                    Text("The map background needs internet. This list works offline.")
                }
            }
        }
    }
}

private struct AreaRow: View {
    let rank: Int
    let area: AreaTotal
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.subheadline.bold())
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.2), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(area.name)
                        .font(.body)
                    Text("\(area.count) \(area.count == 1 ? "expense" : "expenses")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(CurrencyFormatter.lkr(area.total))
                    .font(.body.monospacedDigit())
            }
            ProgressView(value: share)
                .tint(.red)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(area.name), \(area.count) expenses, \(CurrencyFormatter.lkr(area.total))")
    }
}

#Preview {
    NavigationStack {
        SpendingMapView(container: .preview())
    }
}
