//
//  ActivityContext.swift
//  clipmind
//
//  Context metadata for memory-like search - captures when, where, and how content was copied
//

import Foundation

enum TimeCategory: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    static func from(date: Date) -> TimeCategory {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night
        }
    }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
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

    var hourRange: String {
        switch self {
        case .morning: return "6am - 12pm"
        case .afternoon: return "12pm - 6pm"
        case .evening: return "6pm - 10pm"
        case .night: return "10pm - 6am"
        }
    }
}

enum DayCategory: String, Codable, CaseIterable {
    case weekday
    case weekend

    static func from(date: Date) -> DayCategory {
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday == 1 || weekday == 7) ? .weekend : .weekday
    }

    var displayName: String {
        switch self {
        case .weekday: return "Weekday"
        case .weekend: return "Weekend"
        }
    }
}

struct ActivityContext: Codable, Equatable {
    var timeCategory: TimeCategory
    var dayCategory: DayCategory
    var gitBranch: String?
    var projectPath: String?
    var browserTabUrl: String?
    var browserTabTitle: String?
    var activitySessionId: UUID?

    init(
        timeCategory: TimeCategory = .morning,
        dayCategory: DayCategory = .weekday,
        gitBranch: String? = nil,
        projectPath: String? = nil,
        browserTabUrl: String? = nil,
        browserTabTitle: String? = nil,
        activitySessionId: UUID? = nil
    ) {
        self.timeCategory = timeCategory
        self.dayCategory = dayCategory
        self.gitBranch = gitBranch
        self.projectPath = projectPath
        self.browserTabUrl = browserTabUrl
        self.browserTabTitle = browserTabTitle
        self.activitySessionId = activitySessionId
    }

    static func current() -> ActivityContext {
        ActivityContext(
            timeCategory: TimeCategory.from(date: Date()),
            dayCategory: DayCategory.from(date: Date()),
            activitySessionId: UUID()
        )
    }

    var isFromBrowser: Bool {
        browserTabUrl != nil || browserTabTitle != nil
    }

    var isFromCodeEditor: Bool {
        gitBranch != nil || projectPath != nil
    }

    var contextDescription: String {
        var parts: [String] = []

        if let branch = gitBranch {
            parts.append("on \(branch) branch")
        }

        if let project = projectPath {
            let projectName = (project as NSString).lastPathComponent
            parts.append("in \(projectName)")
        }

        if let url = browserTabUrl {
            if let host = URL(string: url)?.host {
                parts.append("from \(host)")
            }
        }

        if parts.isEmpty {
            return "\(timeCategory.displayName), \(dayCategory.displayName)"
        }

        return parts.joined(separator: " ")
    }
}

struct ActivitySession {
    let id: UUID
    let startTime: Date
    var lastActivityTime: Date
    var sourceApp: String
    var itemCount: Int

    static let sessionTimeout: TimeInterval = 300

    var isExpired: Bool {
        Date().timeIntervalSince(lastActivityTime) > Self.sessionTimeout
    }
}

class ActivitySessionManager {
    static let shared = ActivitySessionManager()

    private var currentSession: ActivitySession?
    private let queue = DispatchQueue(label: "com.clipmind.activitysession")

    private init() {}

    func getOrCreateSession(for sourceApp: String) -> UUID {
        queue.sync {
            if let session = currentSession,
               !session.isExpired,
               session.sourceApp == sourceApp {
                currentSession?.lastActivityTime = Date()
                currentSession?.itemCount += 1
                return session.id
            }

            let newSession = ActivitySession(
                id: UUID(),
                startTime: Date(),
                lastActivityTime: Date(),
                sourceApp: sourceApp,
                itemCount: 1
            )
            currentSession = newSession
            return newSession.id
        }
    }

    func currentSessionId(for sourceApp: String) -> UUID? {
        queue.sync {
            guard let session = currentSession,
                  !session.isExpired,
                  session.sourceApp == sourceApp else {
                return nil
            }
            return session.id
        }
    }
}
