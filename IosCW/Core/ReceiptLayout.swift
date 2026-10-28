import CoreGraphics
import Foundation

nonisolated struct RecognizedLine: Equatable, Sendable {
    let text: String
    let confidence: Float
    let box: CGRect
}

struct ReceiptRow: Equatable {
    let text: String
    let confidence: Double
}

enum ReceiptLayout {
    static func rows(from lines: [RecognizedLine]) -> [ReceiptRow] {
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }

        var groups: [[RecognizedLine]] = []
        for line in sorted {
            if let anchor = groups.last?.first,
               abs(line.box.midY - anchor.box.midY) <= max(anchor.box.height, line.box.height) * 0.6 {
                groups[groups.count - 1].append(line)
            } else {
                groups.append([line])
            }
        }

        return groups.map { group in
            let ordered = group.sorted { $0.box.minX < $1.box.minX }
            return ReceiptRow(
                text: ordered.map(\.text).joined(separator: "  "),
                confidence: Double(ordered.map(\.confidence).min() ?? 0))
        }
    }
}
