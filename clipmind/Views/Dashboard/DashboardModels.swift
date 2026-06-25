//
//  DashboardModels.swift
//  clipmind
//
//  Day-grouping for the timeline dashboard
//

import Foundation

struct DaySection: Identifiable {
    let id: String
    let title: String
    let items: [ClipboardItem]
}

func groupByDay(_ items: [ClipboardItem]) -> [DaySection] {
    let calendar = Calendar.current
    let now = Date()

    func bucket(for date: Date) -> (id: String, title: String) {
        if calendar.isDateInToday(date) { return ("today", "Today") }
        if calendar.isDateInYesterday(date) { return ("yesterday", "Yesterday") }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return ("week", "This Week") }
        return ("earlier", "Earlier")
    }

    var order: [String] = []
    var titles: [String: String] = [:]
    var grouped: [String: [ClipboardItem]] = [:]

    for item in items {
        let bucketInfo = bucket(for: item.timestamp)
        if grouped[bucketInfo.id] == nil {
            grouped[bucketInfo.id] = []
            titles[bucketInfo.id] = bucketInfo.title
            order.append(bucketInfo.id)
        }
        grouped[bucketInfo.id]?.append(item)
    }

    return order.compactMap { id in
        guard let sectionItems = grouped[id], let title = titles[id] else { return nil }
        return DaySection(id: id, title: title, items: sectionItems)
    }
}
