import SwiftUI

/// 饼图统计视图
struct ChartStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StatisticsViewModel
    
    @State private var chartType: ChartType = .category
    @State private var transactionTab: TransactionTypeTab = .expense
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingFilterSheet = false
    
    enum ChartType: String, CaseIterable {
        case owner = "按归属人"
        case category = "按账单类型"
        case paymentMethod = "按支付方式"
    }
    
    enum TransactionTypeTab: String, CaseIterable {
        case income = "收入"
        case expense = "支出"
        case excluded = "不计入"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计维度选择
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
                    
                    // 交易类型选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("交易类型")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("", selection: $transactionTab) {
                            ForEach(TransactionTypeTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
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
                ChartDateRangeFilterView(
                    startDate: $startDate,
                    endDate: $endDate
                )
                .iOS16PresentationWithDragCompat()
            }
        }
    }
    
    // 根据选择的类型获取图表数据
    private var chartData: [(String, Decimal, Color)] {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan, .indigo, .mint]
        
        let allStats: [String: [TransactionType: Decimal]]
        switch chartType {
        case .owner:
            allStats = viewModel.ownerStatistics
        case .category:
            allStats = viewModel.categoryStatistics
        case .paymentMethod:
            allStats = viewModel.paymentMethodStatistics
        }
        
        // 根据选择的交易类型筛选
        var stats: [String: Decimal] = [:]
        for (name, amounts) in allStats {
            let value: Decimal
            switch transactionTab {
            case .income:
                value = amounts[.income] ?? 0
            case .expense:
                value = amounts[.expense] ?? 0
            case .excluded:
                value = amounts[.excluded] ?? 0
            }
            
            if value > 0 {
                stats[name] = value
            }
        }
        
        return stats
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { ($0.element.key, $0.element.value, colors[$0.offset % colors.count]) }
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

/// 图表日期范围筛选视图
struct ChartDateRangeFilterView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示器
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // 标题栏
            HStack {
                Button("取消") {
                    dismiss()
                }
                Spacer()
                Text("日期筛选")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            Divider()
            
            VStack(spacing: 16) {
                // 开始日期
                Button(action: { showingStartDatePicker = true }) {
                    HStack {
                        Text("开始日期")
                            .foregroundColor(.primary)
                        Spacer()
                        if let date = startDate {
                            Text(formatDate(date))
                                .foregroundColor(.blue)
                        } else {
                            Text("请选择")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // 结束日期
                Button(action: { showingEndDatePicker = true }) {
                    HStack {
                        Text("结束日期")
                            .foregroundColor(.primary)
                        Spacer()
                        if let date = endDate {
                            Text(formatDate(date))
                                .foregroundColor(.blue)
                        } else {
                            Text("请选择")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // 清除日期按钮
                if startDate != nil || endDate != nil {
                    Button(action: {
                        startDate = nil
                        endDate = nil
                    }) {
                        HStack {
                            Spacer()
                            Text("清除日期范围")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .sheet(isPresented: $showingStartDatePicker) {
            ChartDatePickerSheet(
                title: "选择开始日期",
                selectedDate: Binding(
                    get: { startDate ?? Date() },
                    set: { newDate in
                        let calendar = Calendar.current
                        startDate = calendar.startOfDay(for: newDate)
                    }
                )
            )
        }
        .sheet(isPresented: $showingEndDatePicker) {
            ChartDatePickerSheet(
                title: "选择结束日期",
                selectedDate: Binding(
                    get: { endDate ?? Date() },
                    set: { newDate in
                        let calendar = Calendar.current
                        endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: newDate) ?? newDate
                    }
                )
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// 图表日期选择器弹窗
struct ChartDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var selectedDate: Date
    
    @State private var initialDate: Date
    
    init(title: String, selectedDate: Binding<Date>) {
        self.title = title
        self._selectedDate = selectedDate
        self._initialDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { newValue in
                    // 只有当日期真正改变时才关闭
                    let calendar = Calendar.current
                    let initialDay = calendar.startOfDay(for: initialDate)
                    let newDay = calendar.startOfDay(for: newValue)
                    
                    if initialDay != newDay {
                        // 延迟一点关闭，让用户看到选中效果
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

