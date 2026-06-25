//
//  TimestampLabel.swift
//  clipmind
//
//  Relative time display for clipboard items
//

import SwiftUI
import Combine

/// Label that displays relative time (e.g., "2m ago", "1h ago")
struct TimestampLabel: View {
    let date: Date
    let style: DisplayStyle

    @State private var displayText: String = ""

    enum DisplayStyle {
        case relative  // "2m ago", "1h ago"
        case absolute  // "3:45 PM"
        case combined  // "2m ago (3:45 PM)"
    }

    init(_ date: Date, style: DisplayStyle = .relative) {
        self.date = date
        self.style = style
    }

    var body: some View {
        Text(displayText)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .onAppear {
                updateDisplayText()
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                updateDisplayText()
            }
    }

    private func updateDisplayText() {
        switch style {
        case .relative:
            displayText = relativeTimeString(from: date)
        case .absolute:
            displayText = absoluteTimeString(from: date)
        case .combined:
            displayText = "\(relativeTimeString(from: date)) (\(absoluteTimeString(from: date)))"
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w ago"
        }
    }

    private func absoluteTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

#Preview("Timestamp Labels") {
    VStack(alignment: .leading, spacing: 12) {
        TimestampLabel(Date(), style: .relative)
        TimestampLabel(Date().addingTimeInterval(-120), style: .relative)  // 2 minutes ago
        TimestampLabel(Date().addingTimeInterval(-3600), style: .relative)  // 1 hour ago
        TimestampLabel(Date().addingTimeInterval(-86400), style: .relative)  // 1 day ago

        Divider()

        TimestampLabel(Date(), style: .absolute)

        Divider()

        TimestampLabel(Date().addingTimeInterval(-120), style: .combined)
    }
    .padding()
}
