import SwiftUI
import SwiftData

// MARK: - StudyPlan List View (사이드바에서 진입)
struct StudyPlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [StudyPlan]
    @State private var showAddPlan = false
    @State private var selectedPlan: StudyPlan? = nil

    var body: some View {
        HSplitView {
            // 왼쪽: 플랜 목록
            VStack(spacing: 0) {
                List(selection: $selectedPlan) {
                    ForEach(plans) { plan in
                        StudyPlanRow(plan: plan)
                            .tag(plan)
                    }
                }
                .listStyle(.sidebar)

                Divider()
                Button {
                    showAddPlan = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        Text("새 학습 계획").font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 200, maxWidth: 260)

            // 오른쪽: 플랜 상세
            if let plan = selectedPlan {
                StudyPlanDetailView(plan: plan)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("학습 계획을 선택하세요")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddPlan) {
            AddStudyPlanSheet()
        }
        .navigationTitle("학습 계획")
    }
}

// MARK: - Plan Row
struct StudyPlanRow: View {
    var plan: StudyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.title)
                .font(.system(size: 14, weight: .medium))
            HStack(spacing: 6) {
                ProgressView(value: plan.progressRatio)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                    .tint(.blue)
                Text("\(plan.completedUnits)/\(plan.totalUnits)\(plan.unitType)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plan Detail View
struct StudyPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: StudyPlan
    @State private var isGenerating = false
    @State private var errorMsg = ""

    var sortedSessions: [StudySession] {
        plan.sessions.sorted { $0.date < $1.date }
    }

    // 주차별 그룹
    var weeklyGroups: [[StudySession]] {
        var groups: [[StudySession]] = []
        var current: [StudySession] = []
        var currentWeek = -1

        for session in sortedSessions {
            let week = Calendar.current.component(.weekOfYear, from: session.date)
            if week != currentWeek {
                if !current.isEmpty { groups.append(current) }
                current = [session]
                currentWeek = week
            } else {
                current.append(session)
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // 헤더
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                        Text(plan.title)
                            .font(.system(size: 26, weight: .bold))
                    }

                    // 진도 바
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(plan.completedUnits)/\(plan.totalUnits)\(plan.unitType) 완료")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(plan.progressRatio * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        ProgressView(value: plan.progressRatio)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                    }

                    // 기간
                    HStack(spacing: 8) {
                        Image(systemName: "calendar").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("\(formatDate(plan.startDate)) ~ \(formatDate(plan.endDate))")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider().padding(.horizontal, 32)

                // AI 분배 버튼
                if plan.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 36))
                            .foregroundStyle(.blue)
                        Text("AI가 최적의 학습 스케줄을 만들어드릴게요")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            _Concurrency.Task { await generateSchedule() }
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(isGenerating ? "AI 분배 중..." : "AI 자동 분배")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(isGenerating ? Color.secondary : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(isGenerating)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // 위클리 그룹
                    ForEach(Array(weeklyGroups.enumerated()), id: \.offset) { weekIdx, sessions in
                        WeekSection(
                            weekIdx: weekIdx,
                            sessions: sessions,
                            plan: plan
                        )
                    }

                    // 재분배 버튼
                    Button {
                        _Concurrency.Task { await regenerateSchedule() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("AI 재분배")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - AI 분배
    func generateSchedule() async {
        isGenerating = true
        errorMsg = ""

        let prompt = """
        학습 계획 자동 분배 요청:
        - 과목: \(plan.title)
        - 총 \(plan.unitType) 수: \(plan.totalUnits)
        - 시작일: \(formatDate(plan.startDate))
        - 마감일: \(formatDate(plan.endDate))

        위 기간 동안 총 \(plan.totalUnits)\(plan.unitType)을 균형있게 분배해주세요.
        규칙:
        1. 주말(토,일)에는 평일보다 조금 더 배분
        2. 마지막 날은 여유있게 적게 배분
        3. 각 날짜와 \(plan.unitType) 수를 JSON 배열로만 응답
        4. 형식: [{"date": "2025-03-20", "units": 2}, ...]
        5. JSON만 응답하고 다른 텍스트 없이

        오늘부터 마감일까지 날짜를 계산해서 분배해주세요.
        """

        do {
            let response = try await fetchClaude(prompt: prompt)
            let sessions = parseSchedule(from: response, unitType: plan.unitType)
            await MainActor.run {
                for session in sessions {
                    session.plan = plan
                    plan.sessions.append(session)
                    modelContext.insert(session)
                }
                try? modelContext.save()
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                errorMsg = "분배 실패: \(error.localizedDescription)"
                isGenerating = false
            }
        }
    }

    func regenerateSchedule() async {
        // 기존 세션 삭제
        for session in plan.sessions {
            modelContext.delete(session)
        }
        plan.sessions = []
        try? modelContext.save()
        await generateSchedule()
    }

    // MARK: - Claude API 호출
    func fetchClaude(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? [[String: Any]])?.first
        return content?["text"] as? String ?? ""
    }

    // MARK: - JSON 파싱
    func parseSchedule(from text: String, unitType: String) -> [StudySession] {
        let clean = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = clean.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return arr.compactMap { dict in
            guard let dateStr = dict["date"] as? String,
                  let date = formatter.date(from: dateStr),
                  let units = dict["units"] as? Int, units > 0 else { return nil }
            return StudySession(date: date, units: units, unitType: unitType, plan: plan)
        }
    }

    func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - Week Section
struct WeekSection: View {
    var weekIdx: Int
    var sessions: [StudySession]
    var plan: StudyPlan

    var totalUnits: Int { sessions.reduce(0) { $0 + $1.units } }
    var completedUnits: Int { sessions.filter { $0.isCompleted }.reduce(0) { $0 + $1.units } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 주차 헤더
            HStack {
                Text("\(weekIdx + 1)주차")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedUnits)/\(totalUnits)\(plan.unitType)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // 요일별 세션
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Session Row
struct SessionRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: StudySession

    var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d (E)"
        return f.string(from: session.date)
    }

    var isToday: Bool { Calendar.current.isDateInToday(session.date) }
    var isPast: Bool { session.date < Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        HStack(spacing: 14) {
            // 체크박스
            Button {
                session.isCompleted.toggle()
                try? modelContext.save()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(session.isCompleted ? Color.blue : Color.secondary.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if session.isCompleted {
                        Circle().fill(Color.blue).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // 날짜
            Text(dayLabel)
                .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.blue : (isPast && !session.isCompleted ? Color.red.opacity(0.7) : Color.primary))
                .frame(width: 90, alignment: .leading)

            // 학습량
            Text(session.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(session.isCompleted ? Color.secondary : Color.primary)

            Spacer()

            // 오늘 표시
            if isToday {
                Text("오늘")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .clipShape(Capsule())
            } else if isPast && !session.isCompleted {
                Text("미완료")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .opacity(session.isCompleted ? 0.5 : 1.0)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 54) }
    }
}

// MARK: - Add Study Plan Sheet
struct AddStudyPlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @FocusState private var focused: Bool

    @State private var title = ""
    @State private var totalUnits = 10
    @State private var unitType = "강의"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!
    @State private var selectedProject: Project? = nil

    let unitTypes = ["강의", "시간", "챕터", "페이지"]

    var body: some View {
        VStack(spacing: 0) {
            // 타이틀 바
            ZStack {
                Text("새 학습 계획")
                    .font(.system(size: 15, weight: .semibold))
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 과목명
                    VStack(alignment: .leading, spacing: 6) {
                        Text("과목명").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        ZStack(alignment: .leading) {
                            if title.isEmpty {
                                Text("예: 한국문화, 네트워크보안")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.primary.opacity(0.25))
                            }
                            TextField("", text: $title)
                                .font(.system(size: 15))
                                .textFieldStyle(.plain)
                                .focused($focused)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 총 단위 수 + 단위 타입
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("총 수량").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                            HStack {
                                Button { if totalUnits > 1 { totalUnits -= 1 } } label: {
                                    Image(systemName: "minus").frame(width: 28, height: 28)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                Text("\(totalUnits)").font(.system(size: 17, weight: .semibold)).frame(width: 36, alignment: .center)
                                Button { totalUnits += 1 } label: {
                                    Image(systemName: "plus").frame(width: 28, height: 28)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("단위").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                            Picker("", selection: $unitType) {
                                ForEach(unitTypes, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }

                    // 기간
                    VStack(alignment: .leading, spacing: 6) {
                        Text("기간").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("시작").font(.system(size: 11)).foregroundStyle(.secondary)
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "ko_KR"))
                            }
                            Text("~").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("마감").font(.system(size: 11)).foregroundStyle(.secondary)
                                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "ko_KR"))
                            }
                        }
                    }

                    // 프로젝트 연결
                    if !projects.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("프로젝트 연결 (선택)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        selectedProject = nil
                                    } label: {
                                        Text("없음")
                                            .font(.system(size: 13))
                                            .foregroundStyle(selectedProject == nil ? Color.white : Color.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedProject == nil ? Color.blue : Color.secondary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(projects) { project in
                                        Button {
                                            selectedProject = project
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle().fill(Color(hex: project.colorHex) ?? .blue).frame(width: 7, height: 7)
                                                Text(project.name).font(.system(size: 13))
                                            }
                                            .foregroundStyle(selectedProject?.id == project.id ? Color.white : Color.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedProject?.id == project.id ? Color.blue : Color.secondary.opacity(0.1))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // 추가 버튼
            Button {
                submit()
            } label: {
                Text("계획 만들기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(title.isEmpty ? Color.secondary.opacity(0.3) : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(title.isEmpty)
            .padding(16)
        }
        .frame(width: 420, height: 520)
        .onAppear { focused = true }
    }

    func submit() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let plan = StudyPlan(
            title: title, totalUnits: totalUnits, unitType: unitType,
            startDate: startDate, endDate: endDate, project: selectedProject
        )
        modelContext.insert(plan)
        try? modelContext.save()
        dismiss()
    }
}
