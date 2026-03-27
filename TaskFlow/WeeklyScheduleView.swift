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
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(NSColor.windowBackgroundColor))
        #endif
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

    private var previewColor: Color {
        Color(hex: selectedColor) ?? .blue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 미리보기 카드
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(previewColor)
                            .frame(width: 5)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title.isEmpty ? "수업 이름" : title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(title.isEmpty ? .tertiary : .primary)
                            HStack(spacing: 12) {
                                if !location.isEmpty {
                                    Label(location, systemImage: "mappin")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(String(format: "%d:%02d", startHour, startMinute)) ~ \(String(format: "%d:%02d", endHour, endMinute))")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 12)
                        Spacer()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(previewColor.opacity(0.08)))
                    .padding(.horizontal, 20)

                    // 입력 필드
                    VStack(spacing: 16) {
                        // 이름 & 장소
                        VStack(spacing: 0) {
                            fieldRow {
                                Image(systemName: "textformat")
                                    .frame(width: 24)
                                    .foregroundStyle(.secondary)
                                TextField("수업/일정 이름", text: $title)
                                    .font(.system(size: 15))
                            }
                            Divider().padding(.leading, 44)
                            fieldRow {
                                Image(systemName: "mappin")
                                    .frame(width: 24)
                                    .foregroundStyle(.secondary)
                                TextField("장소 (선택)", text: $location)
                                    .font(.system(size: 15))
                            }
                            Divider().padding(.leading, 44)
                            fieldRow {
                                Image(systemName: "pencil")
                                    .frame(width: 24)
                                    .foregroundStyle(.secondary)
                                TextField("메모 (선택)", text: $memo)
                                    .font(.system(size: 15))
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
                        .padding(.horizontal, 20)

                        // 요일
                        VStack(alignment: .leading, spacing: 10) {
                            Text("요일")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)

                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { d in
                                    Button {
                                        dayOfWeek = d
                                    } label: {
                                        Text(WeeklySchedule.dayNames[d])
                                            .font(.system(size: 14, weight: dayOfWeek == d ? .bold : .medium))
                                            .foregroundStyle(dayOfWeek == d ? .white : (d >= 5 ? .red.opacity(0.6) : .primary))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(dayOfWeek == d ? previewColor : Color.secondary.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // 시간
                        VStack(alignment: .leading, spacing: 10) {
                            Text("시간")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)

                            VStack(spacing: 0) {
                                // 시작
                                timeRow(label: "시작", hour: $startHour, minute: $startMinute)
                                Divider().padding(.horizontal, 16)
                                // 종료
                                timeRow(label: "종료", hour: $endHour, minute: $endMinute)
                            }
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.06)))
                            .padding(.horizontal, 20)
                        }

                        // 색상
                        VStack(alignment: .leading, spacing: 10) {
                            Text("색상")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)

                            HStack(spacing: 12) {
                                ForEach(WeeklySchedule.colorPresets, id: \.hex) { preset in
                                    Circle()
                                        .fill(Color(hex: preset.hex) ?? .blue)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == preset.hex ? 2.5 : 0)
                                                .padding(-3)
                                        )
                                        .onTapGesture { selectedColor = preset.hex }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
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
                    .bold()
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func fieldRow<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func timeRow(label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Spacer()
            #if os(iOS)
            Picker("", selection: hour) {
                ForEach(6..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 80)
            .clipped()
            Text(":")
                .font(.system(size: 18, weight: .medium))
            Picker("", selection: minute) {
                ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 80)
            .clipped()
            #else
            Picker("", selection: hour) {
                ForEach(6..<24, id: \.self) { h in
                    Text("\(h)시").tag(h)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            Text(":")
                .font(.system(size: 16, weight: .medium))
            Picker("", selection: minute) {
                ForEach([0, 10, 15, 20, 30, 40, 45, 50], id: \.self) { m in
                    Text(String(format: "%02d분", m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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
