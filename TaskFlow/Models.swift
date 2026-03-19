import Foundation
import SwiftData

// MARK: - Area (영역) — 학교, 회사, 개인 등
@Model
class Area {
    var id: UUID
    var name: String
    var order: Int
    var projects: [Project]

    init(name: String, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.order = order
        self.projects = []
    }

    var totalSeconds: Int {
        projects.flatMap { $0.tasks }.flatMap { $0.timeEntries }.reduce(0) { $0 + $1.seconds }
    }
}

// MARK: - Project (프로젝트) — 과목, 업무 등
@Model
class Project {
    var id: UUID
    var name: String
    var notes: String = ""
    var colorHex: String
    var order: Int
    var area: Area?
    var tasks: [Task]

    init(name: String, colorHex: String = "007AFF", area: Area? = nil, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.notes = ""
        self.colorHex = colorHex
        self.order = order
        self.area = area
        self.tasks = []
    }

    var totalSeconds: Int {
        tasks.flatMap { $0.timeEntries }.reduce(0) { $0 + $1.seconds }
    }

    var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    var pendingCount: Int { tasks.filter { !$0.isCompleted }.count }
}

// MARK: - Task
@Model
class Task {
    var id: UUID
    var title: String
    var notes: String = ""
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var project: Project?
    var timeEntries: [TimeEntry]

    init(title: String, notes: String = "", project: Project? = nil, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.isCompleted = false
        self.createdAt = Date()
        self.dueDate = dueDate
        self.project = project
        self.timeEntries = []
    }

    var totalSeconds: Int {
        timeEntries.reduce(0) { $0 + $1.seconds }
    }

    var formattedTime: String {
        let s = totalSeconds
        let m = s / 60
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }
}

// MARK: - TimeEntry
@Model
class TimeEntry {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var task: Task?

    init(task: Task? = nil) {
        self.id = UUID()
        self.startedAt = Date()
        self.endedAt = nil
        self.task = task
    }

    var seconds: Int {
        let end = endedAt ?? Date()
        return Int(end.timeIntervalSince(startedAt))
    }

    var isRunning: Bool { endedAt == nil }
}

// MARK: - StudyPlan (학습 계획)
@Model
class StudyPlan {
    var id: UUID
    var title: String          // 과목명
    var totalUnits: Int        // 총 강의/챕터 수
    var unitType: String       // "강의" or "시간" or "챕터"
    var startDate: Date
    var endDate: Date
    var project: Project?
    var sessions: [StudySession]
    var createdAt: Date

    init(title: String, totalUnits: Int, unitType: String = "강의",
         startDate: Date, endDate: Date, project: Project? = nil) {
        self.id = UUID()
        self.title = title
        self.totalUnits = totalUnits
        self.unitType = unitType
        self.startDate = startDate
        self.endDate = endDate
        self.project = project
        self.sessions = []
        self.createdAt = Date()
    }

    var completedUnits: Int { sessions.filter { $0.isCompleted }.reduce(0) { $0 + $1.units } }
    var progressRatio: Double { totalUnits > 0 ? Double(completedUnits) / Double(totalUnits) : 0 }
}

// MARK: - StudySession (요일별 학습 세션)
@Model
class StudySession {
    var id: UUID
    var date: Date
    var units: Int             // 이날 할 강의수
    var unitType: String
    var isCompleted: Bool
    var notes: String = ""
    var plan: StudyPlan?

    init(date: Date, units: Int, unitType: String = "강의", plan: StudyPlan? = nil) {
        self.id = UUID()
        self.date = date
        self.units = units
        self.unitType = unitType
        self.isCompleted = false
        self.plan = plan
    }

    var label: String { "\(units)\(unitType)" }
}
