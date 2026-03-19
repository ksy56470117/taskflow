import Foundation
import SwiftData
import Combine

@Observable
class TimerManager {

    // 현재 실행 중인 TimeEntry
    var activeEntry: TimeEntry?

    // UI에 표시할 경과 시간 (초)
    var displaySeconds: Int = 0

    private var timer: AnyCancellable?
    private var modelContext: ModelContext?

    func setup(context: ModelContext) {
        self.modelContext = context

        // 앱 재시작 시 미완료 타이머 복원
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        if let running = try? context.fetch(descriptor).first {
            activeEntry = running
            displaySeconds = running.seconds
            startTicking()
        }
    }

    // MARK: - 타이머 시작
    func start(task: Task) {
        // 이미 다른 태스크 돌고 있으면 먼저 정지
        if activeEntry != nil { stop() }

        let entry = TimeEntry(task: task)
        task.timeEntries.append(entry)
        modelContext?.insert(entry)
        try? modelContext?.save()

        activeEntry = entry
        displaySeconds = 0
        startTicking()
    }

    // MARK: - 타이머 정지
    func stop() {
        activeEntry?.endedAt = Date()
        try? modelContext?.save()
        activeEntry = nil
        displaySeconds = 0
        timer?.cancel()
        timer = nil
    }

    // MARK: - 해당 태스크가 지금 실행 중인지
    func isRunning(task: Task) -> Bool {
        activeEntry?.task?.id == task.id
    }

    // MARK: - 표시용 문자열 "00:00"
    var clockString: String {
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTicking() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let entry = self.activeEntry else { return }
                self.displaySeconds = entry.seconds
            }
    }
}
