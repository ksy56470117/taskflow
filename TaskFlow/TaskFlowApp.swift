import SwiftUI
import SwiftData

@main
struct TaskFlowApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Area.self, Project.self, Task.self, TimeEntry.self,
            StudyPlan.self, StudySession.self, SchoolEvent.self,
            WishItem.self, Transaction.self, MonthlyBudget.self,
            SavingsAccount.self, SavingsPayment.self,
            ScheduledTransaction.self,
            NoteDocument.self, NoteFolder.self, NoteBlock.self,
            SpreadsheetCell.self, MindMapNode.self,
            WeeklySchedule.self,
            Tag.self
        ])
        let storeURL = Self.resolveStoreURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }

        // 첫 실행 시 "학교" Area 기본 생성
        if !UserDefaults.standard.bool(forKey: "didSeedSchoolArea") {
            let ctx = ModelContext(container)
            let school = Area(name: "학교", order: 0)
            ctx.insert(school)
            try? ctx.save()
            UserDefaults.standard.set(true, forKey: "didSeedSchoolArea")
        }

        // 시간표 시드
        if !UserDefaults.standard.bool(forKey: "didSeedScheduleV3") {
            let ctx = ModelContext(container)
            // 기존 시드 데이터 삭제
            let old = (try? ctx.fetch(FetchDescriptor<WeeklySchedule>())) ?? []
            for o in old { ctx.delete(o) }
            // (제목, 요일(월0~일6), 시작시, 시작분, 종료시, 종료분, 색상hex, 장소)
            let data: [(String, Int, Int, Int, Int, Int, String, String)] = [
                // ── 월요일 ──
                ("Network Security",        0,  9, 0, 11, 0, "93C5FD", "공학b151"),
                ("신화·상상력·문화",           0, 11, 0, 12, 0, "86EFAC", "캠b146"),
                // ── 화요일 ──
                ("국가안보론",                1, 11, 0, 12, 0, "C4B5FD", "학754"),
                ("북한학",                   1, 12, 0, 14, 0, "FDBA74", "학754"),
                ("4차산업혁명과창의적인재",     1, 14, 0, 15, 0, "67E8F9", "학109"),
                ("SW리더십과기업가정신",       1, 17, 0, 18, 0, "F9A8D4", "공학b153"),
                // ── 목요일 ──
                ("Network Security",        3, 11, 0, 12, 0, "93C5FD", "공학b151"),
                ("신화·상상력·문화",           3, 12, 0, 14, 0, "86EFAC", "캠b146"),
                // ── 금요일 ──
                ("국가안보론",                4, 11, 0, 12, 0, "C4B5FD", "학754"),
                ("북한학",                   4, 14, 0, 15, 0, "FDBA74", "학754"),
                ("4차산업혁명과창의적인재",     4, 15, 0, 17, 0, "67E8F9", "학109"),
            ]
            for d in data {
                ctx.insert(WeeklySchedule(
                    title: d.0, dayOfWeek: d.1,
                    startHour: d.2, startMinute: d.3,
                    endHour: d.4, endMinute: d.5,
                    colorHex: d.6, location: d.7
                ))
            }
            try? ctx.save()
            UserDefaults.standard.set(true, forKey: "didSeedScheduleV2")
        }

    }

    static func resolveStoreURL() -> URL {
        let fm = FileManager.default
        // iCloud Drive 안 TaskFlow 폴더에 데이터 저장
        let iCloudData = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/AppData")
        do {
            try fm.createDirectory(at: iCloudData, withIntermediateDirectories: true)
            return iCloudData.appendingPathComponent("taskflow.sqlite")
        } catch {
            // iCloud Drive 접근 실패 시 로컬로 fallback
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("taskflow.sqlite")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
