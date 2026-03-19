import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var projects: [Project]

    var allEntries: [TimeEntry] { projects.flatMap { $0.tasks }.flatMap { $0.timeEntries } }

    var weekDays: [Date] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -(weekday - 2), to: today)!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    func secondsOn(_ date: Date) -> Int {
        let cal = Calendar.current
        return allEntries.filter { cal.isDate($0.startedAt, inSameDayAs: date) }.reduce(0) { $0 + $1.seconds }
    }

    var totalSecondsThisWeek: Int { weekDays.reduce(0) { $0 + secondsOn($1) } }

    var completedThisWeek: Int {
        let cal = Calendar.current
        return projects.flatMap { $0.tasks }.filter { task in
            task.isCompleted && task.timeEntries.contains { cal.isDateInThisWeek($0.startedAt) }
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    SummaryCard(value: formatSeconds(totalSecondsThisWeek), label: "이번 주 총 시간", color: .blue)
                    SummaryCard(value: "\(completedThisWeek)", label: "완료 태스크", color: .green)
                    SummaryCard(value: "\(projects.count)", label: "프로젝트", color: .orange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("일별 집중 시간")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 16)

                    Chart {
                        ForEach(weekDays, id: \.self) { day in
                            BarMark(
                                x: .value("요일", dayLabel(day)),
                                y: .value("분", secondsOn(day) / 60)
                            )
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.blue : Color.blue.opacity(0.4))
                            .cornerRadius(5)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic) { val in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = val.as(Int.self) {
                                    Text(v >= 60 ? "\(v/60)h" : "\(v)m").font(.system(size: 11))
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text("프로젝트별 시간")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                    if projects.isEmpty {
                        Text("프로젝트 없음")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        ForEach(projects.sorted { $0.totalSeconds > $1.totalSeconds }) { project in
                            ProjectStatRow(project: project, maxSeconds: projects.map(\.totalSeconds).max() ?? 1)
                        }
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color.secondary.opacity(0.1))
    }

    func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: date)
    }
}

struct ProjectStatRow: View {
    var project: Project
    var maxSeconds: Int

    var color: Color { Color(hex: project.colorHex) ?? .purple }
    var ratio: Double { maxSeconds > 0 ? Double(project.totalSeconds) / Double(maxSeconds) : 0 }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(project.name).font(.system(size: 15))
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * ratio, height: 6)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 80, height: 20)
            Text(formatSeconds(project.totalSeconds))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
    }
}
