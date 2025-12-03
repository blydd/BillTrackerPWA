import SwiftUI

/// 饼图统计视图
struct ChartStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StatisticsViewModel
    
    @State private var chartType: ChartType = .category
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingFilterSheet = false
    
    enum ChartType: String, CaseIterable {
        case owner = "按归属人"
        case category = "按账单类型"
        case paymentMethod = "按支付方式"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 筛选条件选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("统计维度")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("", selection: $chartType) {
                            ForEach(ChartType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    
                    // 日期范围显示
                    if startDate != nil || endDate != nil {
                        HStack {
                            Text("日期范围:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(dateRangeText)
                                .font(.subheadline)
                            Spacer()
                            Button("修改") {
                                showingFilterSheet = true
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                    
                    // 饼图
                    if !chartData.isEmpty {
                        VStack(spacing: 16) {
                            PieChartView(
                                data: chartData,
                                total: chartTotal
                            )
                            .frame(height: 300)
                            .padding()
                            
                            // 图例
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(chartData.enumerated()), id: \.offset) { index, item in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(item.2)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(item.0)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("¥\(item.1 as NSDecimalNumber, formatter: numberFormatter)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text("\(percentage(item.1), specifier: "%.1f")%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("暂无数据")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 300)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("图表统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                DateRangeFilterView(
                    startDate: $startDate,
                    endDate: $endDate
                )
            }
        }
    }
    
    // 根据选择的类型获取图表数据
    private var chartData: [(String, Decimal, Color)] {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan, .indigo, .mint]
        
        switch chartType {
        case .owner:
            return viewModel.ownerStatistics
                .sorted { $0.value > $1.value }
                .enumerated()
                .map { ($0.element.key, $0.element.value, colors[$0.offset % colors.count]) }
            
        case .category:
            return viewModel.categoryStatistics
                .sorted { $0.value > $1.value }
                .enumerated()
                .map { ($0.element.key, $0.element.value, colors[$0.offset % colors.count]) }
            
        case .paymentMethod:
            return viewModel.paymentMethodStatistics
                .sorted { $0.value > $1.value }
                .enumerated()
                .map { ($0.element.key, $0.element.value, colors[$0.offset % colors.count]) }
        }
    }
    
    private var chartTotal: Decimal {
        chartData.reduce(0) { $0 + $1.1 }
    }
    
    private func percentage(_ value: Decimal) -> Double {
        guard chartTotal > 0 else { return 0 }
        return Double(truncating: value as NSDecimalNumber) / Double(truncating: chartTotal as NSDecimalNumber) * 100
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let start = startDate, let end = endDate {
            return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
        } else if let start = startDate {
            return "从 \(formatter.string(from: start))"
        } else if let end = endDate {
            return "至 \(formatter.string(from: end))"
        }
        return "全部"
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

/// 日期范围筛选视图
struct DateRangeFilterView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    @State private var tempStartDate: Date = {
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date())
    }()
    @State private var tempEndDate: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
    }()
    
    var body: some View {
        NavigationView {
            Form {
                Section("日期范围") {
                    Toggle("开始日期", isOn: Binding(
                        get: { startDate != nil },
                        set: { enabled in
                            if enabled {
                                let calendar = Calendar.current
                                startDate = calendar.startOfDay(for: tempStartDate)
                            } else {
                                startDate = nil
                            }
                        }
                    ))
                    
                    if startDate != nil {
                        DatePicker("", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { newDate in
                                let calendar = Calendar.current
                                startDate = calendar.startOfDay(for: newDate)
                                tempStartDate = newDate
                            }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                    
                    Toggle("结束日期", isOn: Binding(
                        get: { endDate != nil },
                        set: { enabled in
                            if enabled {
                                let calendar = Calendar.current
                                endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: tempEndDate) ?? tempEndDate
                            } else {
                                endDate = nil
                            }
                        }
                    ))
                    
                    if endDate != nil {
                        DatePicker("", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { newDate in
                                let calendar = Calendar.current
                                endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: newDate) ?? newDate
                                tempEndDate = newDate
                            }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("日期筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

