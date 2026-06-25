//
//  AdvancedDateFilterView.swift
//  clipmind
//
//  Advanced date and time filtering with custom ranges and patterns
//

import Foundation

/// Time of day filter
enum TimeOfDay: String, CaseIterable {
    case morning = "Morning"      // 6am - 12pm
    case afternoon = "Afternoon"  // 12pm - 6pm
    case evening = "Evening"      // 6pm - 12am
    case night = "Night"          // 12am - 6am

    var timeRange: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...23
        case .night: return 0...5
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

/// Day of week pattern
enum DayOfWeekPattern: String, CaseIterable {
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case mondays = "Mondays"
    case tuesdays = "Tuesdays"
    case wednesdays = "Wednesdays"
    case thursdays = "Thursdays"
    case fridays = "Fridays"
    case saturdays = "Saturdays"
    case sundays = "Sundays"

    var weekdays: Set<Int> {
        switch self {
        case .weekdays: return [2, 3, 4, 5, 6]  // Mon-Fri
        case .weekends: return [1, 7]            // Sat-Sun
        case .mondays: return [2]
        case .tuesdays: return [3]
        case .wednesdays: return [4]
        case .thursdays: return [5]
        case .fridays: return [6]
        case .saturdays: return [7]
        case .sundays: return [1]
        }
    }
}

/// Relative time filter
enum RelativeTime: String, CaseIterable {
    case lastHour = "Last Hour"
    case last3Hours = "Last 3 Hours"
    case last6Hours = "Last 6 Hours"
    case last12Hours = "Last 12 Hours"
    case last24Hours = "Last 24 Hours"
    case last48Hours = "Last 48 Hours"

    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last3Hours: return 3600 * 3
        case .last6Hours: return 3600 * 6
        case .last12Hours: return 3600 * 12
        case .last24Hours: return 3600 * 24
        case .last48Hours: return 3600 * 48
        }
    }

    var dateRange: DateRange {
        DateRange(
            start: Date().addingTimeInterval(-timeInterval),
            end: Date()
        )
    }
}

/// Advanced date filter configuration
struct AdvancedDateFilter: Equatable {
    var customRange: DateRange?
    var timeOfDay: TimeOfDay?
    var dayOfWeekPattern: DayOfWeekPattern?
    var relativeTime: RelativeTime?

    var hasFilters: Bool {
        customRange != nil || timeOfDay != nil || dayOfWeekPattern != nil || relativeTime != nil
    }

    func matches(date: Date) -> Bool {
        let calendar = Calendar.current

        // Check custom range
        if let range = customRange {
            if let start = range.start, date < start { return false }
            if let end = range.end, date > end { return false }
        }

        // Check relative time
        if let relative = relativeTime {
            let range = relative.dateRange
            if let start = range.start, date < start { return false }
            if let end = range.end, date > end { return false }
        }

        // Check time of day
        if let timeOfDay = timeOfDay {
            let hour = calendar.component(.hour, from: date)
            if !timeOfDay.timeRange.contains(hour) { return false }
        }

        // Check day of week
        if let pattern = dayOfWeekPattern {
            let weekday = calendar.component(.weekday, from: date)
            if !pattern.weekdays.contains(weekday) { return false }
        }

        return true
    }
}

