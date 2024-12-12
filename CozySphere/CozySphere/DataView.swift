//
//  DataView.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/12/1.
//
import SwiftUI
import Charts // 引入 Charts 框架

struct DataView: View {
    // 模拟每天的温湿度数据
    let dailyData: [DayData] = [
        DayData(date: "12-07", temperature: 19, humidity: 58),
        DayData(date: "12-08", temperature: 20, humidity: 60),
        DayData(date: "12-09", temperature: 18, humidity: 50),
        DayData(date: "12-10", temperature: 21, humidity: 52),
        DayData(date: "12-11", temperature: 22, humidity: 55)
    ]

    // 模拟例假周期数据
    @State private var cycles: [PeriodCycle] = [
        PeriodCycle(startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60), endDate: Date().addingTimeInterval(-27 * 24 * 60 * 60)),
        PeriodCycle(startDate: Date().addingTimeInterval(-60 * 24 * 60 * 60), endDate: Date().addingTimeInterval(-57 * 24 * 60 * 60))
    ]
    @State private var showingAddCycle = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 温度折线图
                    Section(header: Text("Temperature (°C)").font(.headline)) {
                        Chart {
                            ForEach(dailyData) { data in
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Temperature", data.temperature)
                                )
                                .foregroundStyle(.blue)
                                .symbol(Circle())
                            }
                        }
                        .frame(height: 200)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // 湿度折线图
                    Section(header: Text("Humidity (%)").font(.headline)) {
                        Chart {
                            ForEach(dailyData) { data in
                                LineMark(
                                    x: .value("Date", data.date),
                                    y: .value("Humidity", data.humidity)
                                )
                                .foregroundStyle(.green)
                                .symbol(Circle())
                            }
                        }
                        .frame(height: 200)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // 例假追踪模块
                    Section(header: Text("Period Tracker").font(.headline)) {
                        if let nextCycle = predictNextCycle() {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Predicted Next Period:")
                                Text("From \(formatDate(nextCycle.startDate)) to \(formatDate(nextCycle.endDate))")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Past Cycles:")
                            List {
                                ForEach(cycles) { cycle in
                                    HStack {
                                        Text("From \(formatDate(cycle.startDate))")
                                        Spacer()
                                        Text("To \(formatDate(cycle.endDate))")
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .onDelete(perform: deleteCycle)
                            }
                            .frame(maxHeight: 300) // 限制列表高度
                        }

                        Button(action: { showingAddCycle.toggle() }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Period Cycle")
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .sheet(isPresented: $showingAddCycle) {
                            AddCycleView { newCycle in
                                cycles.append(newCycle)
                                showingAddCycle = false
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Data")
        }
    }

    // 删除周期
    private func deleteCycle(at offsets: IndexSet) {
        cycles.remove(atOffsets: offsets)
    }

    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // 预测下一个周期
    private func predictNextCycle() -> PeriodCycle? {
        guard let lastCycle = cycles.last else { return nil }
        let averageCycleLength: TimeInterval = 30 * 24 * 60 * 60 // 假设平均周期为 30 天
        let nextStartDate = lastCycle.endDate.addingTimeInterval(averageCycleLength)
        let nextEndDate = nextStartDate.addingTimeInterval(3 * 24 * 60 * 60) // 假设周期持续 3 天
        return PeriodCycle(startDate: nextStartDate, endDate: nextEndDate)
    }
}

// 数据模型
struct DayData: Identifiable {
    let id = UUID()
    let date: String
    let temperature: Double
    let humidity: Double
}

struct PeriodCycle: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
}

// 添加周期界面
struct AddCycleView: View {
    @State private var startDate = Date()
    @State private var endDate = Date()
    var onAddCycle: (PeriodCycle) -> Void

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)

                Button("Add Cycle") {
                    let newCycle = PeriodCycle(startDate: startDate, endDate: endDate)
                    onAddCycle(newCycle)
                }
                .disabled(startDate >= endDate) // 确保开始日期早于结束日期
            }
            .navigationTitle("Add Period Cycle")
        }
    }
}

// 预览
struct DataView_Previews: PreviewProvider {
    static var previews: some View {
        DataView()
    }
}
