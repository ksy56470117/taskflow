import SwiftUI
import SwiftData

// MARK: - Weekly Schedule (시간표)

struct WeeklyScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklySchedule.startHour) private var schedules: [WeeklySchedule]
    @State private var showingAdd = false
    @State private var editingSchedule: WeeklySchedule? = nil

    // 표시할 시간 범위
    private var minHour: Int {
        let earliest = schedules.map(\.startHour).min() ?? 9
        return max(earliest - 1, 0)
    }
    private var maxHour: Int {
        let latest = schedules.map(\.endHour).max() ?? 18
        return min(latest + 1, 24)
    }
    private var displayHours: [Int] { Array(minHour...maxHour) }

    private let hourHeight: CGFloat = 60
    private let dayNames = WeeklySchedule.dayNames

    var body: some View {
        VStack(spacing: 0) {
            // 요일 헤더
            dayHeader

            Divider()

            // 시간표 그리드
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // 시간 라인 + 라벨
                    timeGrid

                    // 스케줄 블록들
                    scheduleBlocks
                }
                .frame(height: CGFloat(displayHours.count) * hourHeight)
            }
        }
        .navigationTitle("시간표")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ScheduleEditSheet(schedule: nil) { title, day, sh, sm, eh, em, color, loc, memo in
                let s = WeeklySchedule(title: title, dayOfWeek: day,
                                        startHour: sh, startMinute: sm,
                                        endHour: eh, endMinute: em,
                                        colorHex: color, location: loc, memo: memo)
                modelContext.insert(s)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingSchedule) { sched in
            ScheduleEditSheet(schedule: sched) { title, day, sh, sm, eh, em, color, loc, memo in
                sched.title = title
                sched.dayOfWeek = day
                sched.startHour = sh
                sched.startMinute = sm
                sched.endHour = eh
                sched.endMinute = em
                sched.colorHex = color
                sched.location = loc
                sched.memo = memo
                try? modelContext.save()
            }
        }
    }

    // MARK: - 요일 헤더

    private var dayHeader: some View {
        HStack(spacing: 0) {
            // 시간 라벨 영역
            Color.clear.frame(width: 44)

            ForEach(0..<7, id: \.self) { day in
                let isToday = Calendar.current.component(.weekday, from: Date()) == (day + 2) % 7 + 1
                // weekday: 일=1, 월=2 ...  / day: 월=0, 화=1 ...

                Text(dayNames[day])
                    .font(.system(size: 13, weight: isToday ? .bold : .medium))
                    .foregroundStyle(day >= 5 ? .red.opacity(0.7) : (isToday ? .blue : .primary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 시간 그리드

    private var timeGrid: some View {
        ForEach(Array(displayHours.enumerated()), id: \.offset) { idx, hour in
            HStack(spacing: 0) {
                Text("\(hour)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, alignment: .trailing)
                    .padding(.trailing, 6)

                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 0.5)
            }
            .offset(y: CGFloat(idx) * hourHeight)
        }
    }

    // MARK: - 스케줄 블록들

    private var scheduleBlocks: some View {
        GeometryReader { geo in
            let dayWidth = (geo.size.width - 44) / 7

            ForEach(schedules) { sched in
                let startOffset = CGFloat(sched.startHour * 60 + sched.startMinute - minHour * 60) / 60.0 * hourHeight
                let duration = CGFloat(sched.durationMinutes) / 60.0 * hourHeight

                ScheduleBlockView(schedule: sched)
                    .frame(width: dayWidth - 4, height: max(duration, 24))
                    .offset(
                        x: 44 + CGFloat(sched.dayOfWeek) * dayWidth + 2,
                        y: startOffset
                    )
                    .onTapGesture { editingSchedule = sched }
                    .contextMenu {
                        Button { editingSchedule = sched } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(sched)
                            try? modelContext.save()
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

// MARK: - Schedule Block View

struct ScheduleBlockView: View {
    let schedule: WeeklySchedule

    private var bgColor: Color {
        Color(hex: schedule.colorHex) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(schedule.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            if schedule.durationMinutes >= 60 {
                if !schedule.location.isEmpty {
                    Text(schedule.location)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Text(schedule.startTimeString)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor.opacity(0.85))
        )
    }
}

// MARK: - Schedule Edit Sheet

struct ScheduleEditSheet: View {
    let schedule: WeeklySchedule?
    let onSave: (String, Int, Int, Int, Int, Int, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var dayOfWeek: Int = 0
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 10
    @State private var endMinute: Int = 0
    @State private var selectedColor: String = "3B82F6"
    @State private var location: String = ""
    @State private var memo: String = ""

    init(schedule: WeeklySchedule?, onSave: @escaping (String, Int, Int, Int, Int, Int, String, String, String) -> Void) {
        self.schedule = schedule
        self.onSave = onSave
        if let s = schedule {
            _title = State(initialValue: s.title)
            _dayOfWeek = State(initialValue: s.dayOfWeek)
            _startHour = State(initialValue: s.startHour)
            _startMinute = State(initialValue: s.startMinute)
            _endHour = State(initialValue: s.endHour)
            _endMinute = State(initialValue: s.endMinute)
            _selectedColor = State(initialValue: s.colorHex)
            _location = State(initialValue: s.location)
            _memo = State(initialValue: s.memo)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("수업/일정 이름", text: $title)
                    TextField("장소 (선택)", text: $location)
                    TextField("메모 (선택)", text: $memo)
                }

                Section("요일") {
                    Picker("요일", selection: $dayOfWeek) {
                        ForEach(0..<7, id: \.self) { d in
                            Text(WeeklySchedule.dayNames[d]).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("시간") {
                    HStack {
                        Text("시작")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("시", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { h in Text("\(h)시").tag(h) }
                        }
                        .pickerStyle(.menu)
                        Picker("분", selection: $startMinute) {
                            ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { m in
                                Text(String(format: "%02d분", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("종료")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("시", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { h in Text("\(h)시").tag(h) }
                        }
                        .pickerStyle(.menu)
                        Picker("분", selection: $endMinute) {
                            ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { m in
                                Text(String(format: "%02d분", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 9), spacing: 10) {
                        ForEach(WeeklySchedule.colorPresets, id: \.hex) { preset in
                            Circle()
                                .fill(Color(hex: preset.hex) ?? .blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(Color.primary, lineWidth: selectedColor == preset.hex ? 2.5 : 0)
                                )
                                .onTapGesture { selectedColor = preset.hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(schedule == nil ? "스케줄 추가" : "스케줄 편집")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard !title.isEmpty else { return }
                        onSave(title, dayOfWeek, startHour, startMinute, endHour, endMinute, selectedColor, location, memo)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }
}

// MARK: - Quick Add (같은 수업 다른 요일에 복사)

extension WeeklyScheduleView {
    func duplicateToDay(_ schedule: WeeklySchedule, day: Int) {
        let s = WeeklySchedule(
            title: schedule.title,
            dayOfWeek: day,
            startHour: schedule.startHour,
            startMinute: schedule.startMinute,
            endHour: schedule.endHour,
            endMinute: schedule.endMinute,
            colorHex: schedule.colorHex,
            location: schedule.location,
            memo: schedule.memo
        )
        modelContext.insert(s)
        try? modelContext.save()
    }
}
