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
            WeeklySchedule.self, ScheduleTask.self,
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

        // 시간표 시드 제거됨 — 사용자가 직접 입력

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
                .tint(Color.ghGreen)
        }
        .modelContainer(container)
    }
}
