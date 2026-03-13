import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \PracticeRecord.date) private var allRecords: [PracticeRecord]
    @State private var goal = GoalManager()
    @State private var goalInput = ""
    @FocusState private var isGoalFieldFocused: Bool

    private var recentRecords: [PracticeRecord] {
        Array(allRecords.suffix(20))
    }

    private var bestCount: Int {
        allRecords.map(\.count).max() ?? 0
    }

    private var totalSessions: Int {
        allRecords.count
    }

    private var averageCount: Double {
        guard !allRecords.isEmpty else { return 0 }
        return Double(allRecords.map(\.count).reduce(0, +)) / Double(allRecords.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if allRecords.isEmpty {
                    VStack(spacing: 32) {
                        goalSettingSection
                        ContentUnavailableView("データがありません", systemImage: "chart.bar", description: Text("練習を保存するとここに\n統計が表示されます"))
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            goalSettingSection
                            summaryCards
                            countChart
                            durationChart
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("統計")
            .onAppear {
                goalInput = goal.dailyGoal > 0 ? "\(goal.dailyGoal)" : ""
            }
        }
    }

    // MARK: - Goal Setting

    private var goalSettingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("今日の目標")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                TextField("例: 30", text: $goalInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .focused($isGoalFieldFocused)

                Text("回")
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if let value = Int(goalInput), value > 0 {
                        goal.dailyGoal = value
                    }
                    isGoalFieldFocused = false
                } label: {
                    Text("設定")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if goal.hasGoal {
                    Button {
                        goal.dailyGoal = 0
                        goalInput = ""
                        isGoalFieldFocused = false
                    } label: {
                        Text("解除")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if goal.hasGoal {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                    Text("現在の目標: \(goal.dailyGoal) 回")
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "合計練習", value: "\(totalSessions)", unit: "回", color: .blue)
            summaryCard(title: "最高記録", value: "\(bestCount)", unit: "回", color: .orange)
            summaryCard(title: "平均", value: String(format: "%.1f", averageCount), unit: "回", color: .green)
        }
    }

    private func summaryCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Charts

    private var countChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リフティング回数の推移")
                .font(.headline)

            Chart {
                ForEach(recentRecords) { record in
                    BarMark(
                        x: .value("日時", record.date, unit: .day),
                        y: .value("回数", record.count)
                    )
                    .foregroundStyle(.blue.gradient)
                }

                if goal.hasGoal {
                    RuleMark(y: .value("目標", goal.dailyGoal))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("目標 \(goal.dailyGoal)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                }
            }
            .chartYAxisLabel("回")
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("練習時間の推移")
                .font(.headline)

            Chart(recentRecords) { record in
                LineMark(
                    x: .value("日時", record.date, unit: .day),
                    y: .value("秒", record.durationSeconds)
                )
                .foregroundStyle(.orange)
                .symbol(.circle)

                AreaMark(
                    x: .value("日時", record.date, unit: .day),
                    y: .value("秒", record.durationSeconds)
                )
                .foregroundStyle(.orange.opacity(0.1))
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let seconds = value.as(Int.self) {
                            Text(formatDuration(seconds))
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    StatsView()
        .modelContainer(for: PracticeRecord.self, inMemory: true)
}
