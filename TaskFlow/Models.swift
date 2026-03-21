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

    var midtermDate: Date?
    var finalDate: Date?

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

// MARK: - SchoolEvent (주요 행사)
@Model
class SchoolEvent {
    var id: UUID
    var title: String
    var date: Date
    var type: String   // "midterm" | "final" | "custom"
    var area: Area?

    init(title: String, date: Date, type: String = "custom", area: Area? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.type = type
        self.area = area
    }

    var icon: String {
        switch type {
        case "midterm": return "doc.text.fill"
        case "final":   return "checkmark.seal.fill"
        default:        return "star.fill"
        }
    }

    var dDay: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "D-Day" }
        if days > 0  { return "D-\(days)" }
        return "D+\(-days)"
    }
}

// MARK: - Transaction (가계부 거래)
@Model
class Transaction {
    var id: UUID
    var amount: Int
    var type: String          // "income" | "expense"
    var category: String
    var paymentMethod: String // "카드" | "현금" | "계좌이체"
    var memo: String
    var date: Date
    var isPlanned: Bool

    init(amount: Int, type: String, category: String, paymentMethod: String = "카드", memo: String = "", date: Date = Date(), isPlanned: Bool = false) {
        self.id = UUID()
        self.amount = amount
        self.type = type
        self.category = category
        self.paymentMethod = paymentMethod
        self.memo = memo
        self.date = date
        self.isPlanned = isPlanned
    }

    var formattedAmount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let str = f.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return (type == "income" ? "+" : "-") + str + "원"
    }

    static let expenseCategories = ["식비", "교통", "쇼핑", "문화/여가", "의료", "통신", "주거", "교육", "기타"]
    static let incomeCategories  = ["급여", "용돈", "부업", "기타"]
    static let paymentMethods    = ["카드", "현금", "계좌이체"]

    static let categoryIcon: [String: String] = [
        "식비": "fork.knife", "교통": "car", "쇼핑": "bag",
        "문화/여가": "ticket", "의료": "cross.case", "통신": "wifi",
        "주거": "house", "교육": "graduationcap", "기타": "ellipsis.circle",
        "급여": "banknote", "용돈": "gift", "부업": "briefcase"
    ]

    static let categoryColor: [String: String] = [
        "식비": "FF6B6B", "교통": "4ECDC4", "쇼핑": "A78BFA",
        "문화/여가": "F59E0B", "의료": "EF4444", "통신": "3B82F6",
        "주거": "10B981", "교육": "6366F1", "기타": "9CA3AF",
        "급여": "22C55E", "용돈": "84CC16", "부업": "F97316"
    ]
}

// MARK: - MonthlyBudget (월 예산)
@Model
class MonthlyBudget {
    var id: UUID
    var category: String
    var limitAmount: Int
    var yearMonth: Int   // yyyyMM 형식 (예: 202603)

    init(category: String, limitAmount: Int, yearMonth: Int) {
        self.id = UUID()
        self.category = category
        self.limitAmount = limitAmount
        self.yearMonth = yearMonth
    }
}

// MARK: - SavingsAccount (적금 계좌)
@Model
class SavingsAccount {
    var id: UUID
    var name: String          // 예: "청년희망적금"
    var bank: String          // 예: "국민은행"
    var monthlyAmount: Int    // 월 납입액
    var targetAmount: Int     // 목표 금액
    var startDate: Date
    var endDate: Date         // 만기일
    var interestRate: Double  // 금리 (연, %)
    var memo: String
    var payments: [SavingsPayment]

    init(name: String, bank: String = "", monthlyAmount: Int = 0,
         targetAmount: Int = 0, startDate: Date = Date(),
         endDate: Date = Date(), interestRate: Double = 0, memo: String = "") {
        self.id = UUID()
        self.name = name
        self.bank = bank
        self.monthlyAmount = monthlyAmount
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.endDate = endDate
        self.interestRate = interestRate
        self.memo = memo
        self.payments = []
    }

    /// 지금까지 납입한 총액
    var totalPaid: Int { payments.reduce(0) { $0 + $1.amount } }

    /// 목표 대비 진행률 (0.0 ~ 1.0)
    var progressRatio: Double {
        guard targetAmount > 0 else { return 0 }
        return min(Double(totalPaid) / Double(targetAmount), 1.0)
    }

    /// 만기까지 남은 달 수
    var remainingMonths: Int {
        let cal = Calendar.current
        let diff = cal.dateComponents([.month], from: Date(), to: endDate)
        return max(diff.month ?? 0, 0)
    }

    /// 이번 달 납입 여부
    var isPaidThisMonth: Bool {
        let cal = Calendar.current
        return payments.contains { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    /// 전체 납입 기간 (월 수)
    var totalMonths: Int {
        let cal = Calendar.current
        let diff = cal.dateComponents([.month], from: startDate, to: endDate)
        return max((diff.month ?? 0) + 1, 1)
    }
}

// MARK: - SavingsPayment (적금 납입 기록)
@Model
class SavingsPayment {
    var id: UUID
    var amount: Int
    var date: Date
    var memo: String
    var account: SavingsAccount?

    init(amount: Int, date: Date = Date(), memo: String = "", account: SavingsAccount? = nil) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.memo = memo
        self.account = account
    }
}

// MARK: - WishItem (위시리스트)
@Model
class WishItem {
    var id: UUID
    var name: String
    var category: String     // "전자기기" | "패션" | "도서" | "뷰티" | "인테리어" | "식품" | "기타"
    var store: String
    var price: Int
    var url: String
    var notes: String
    var isPurchased: Bool
    var createdAt: Date

    init(name: String, category: String = "기타", store: String = "", price: Int = 0, url: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.store = store
        self.price = price
        self.url = url
        self.notes = notes
        self.isPurchased = false
        self.createdAt = Date()
    }

    var formattedPrice: String {
        if price == 0 { return "가격 미정" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return (f.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }

    static let categories = ["전자기기", "패션", "도서", "뷰티", "인테리어", "식품", "기타"]

    static let categoryIcon: [String: String] = [
        "전자기기": "desktopcomputer",
        "패션":    "tshirt",
        "도서":    "book.closed",
        "뷰티":    "sparkles",
        "인테리어": "house",
        "식품":    "fork.knife",
        "기타":    "tag"
    ]
}

// MARK: - ScheduledTransaction (정기 거래)
@Model
class ScheduledTransaction {
    var id: UUID
    var title: String
    var amount: Int
    var type: String           // "income" | "expense"
    var category: String
    var paymentMethod: String
    var dayOfMonth: Int        // 매달 몇 일 (1-31)
    var isActive: Bool
    var memo: String
    var createdAt: Date

    init(title: String, amount: Int = 0, type: String = "expense",
         category: String = "기타", paymentMethod: String = "카드",
         dayOfMonth: Int = 1, memo: String = "") {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.type = type
        self.category = category
        self.paymentMethod = paymentMethod
        self.dayOfMonth = dayOfMonth
        self.isActive = true
        self.memo = memo
        self.createdAt = Date()
    }
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
