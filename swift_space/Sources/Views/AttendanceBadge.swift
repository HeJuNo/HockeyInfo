import SwiftUI

struct AttendanceBadge: View {
    let status: String
    let label: String

    private var bgColor: Color {
        switch status {
        case "1": return .green
        case "6": return .orange
        case "9": return .red
        default: return .gray
        }
    }

    private var icon: String {
        switch status {
        case "1": return "checkmark.circle.fill"
        case "6": return "xmark.circle.fill"
        case "9": return "cross.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(label.isEmpty ? statusText : label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bgColor.opacity(0.2))
        .foregroundStyle(bgColor)
        .clipShape(Capsule())
    }

    private var statusText: String {
        switch status {
        case "1": return "Gesund"
        case "6": return "Entschuldigt"
        case "9": return "Verletzt"
        default: return "Unbekannt"
        }
    }
}
