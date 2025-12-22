import SwiftUI

/// 统计视图
struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @State private var selectedTimeRange: TimeRange = .thisMonth
    @State private var showingChartView = false
    @State private var categoryTab: TransactionTypeTab = .expense
    @State private var ownerTab: TransactionTypeTab = .expense
    @State private var paymentTab: TransactionTypeTab = .expense
    @State private var showingMonthPicker = false
    @State private var selectedMonth = Date()
    
    enum TimeRange: String, CaseIterable {
        case thisMonth = "本月"
        case lastMonth = "上月"
        case customMonth = "选择月份"
        case thisYear = "今年"
        case all = "全部"
    }
    
    enum TransactionTypeTab: String, CaseIterable {
        case income = "收入"
        case expense = "支出"
        case excluded = "不计入"
    }
    
    init(repository: DataRepository) {
        _viewModel = StateObject(wrappedValue: StatisticsViewModel(repository: repository))
    }
    var body: some View {
        List {
            Section {
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                
                // 当选择"选择月份"时显示月份选择器
                if selectedTimeRange == .customMonth {
                    Button(action: {
                        showingMonthPicker = true
                    }) {
                        HStack {
                            Text("选择的月份")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatMonth(selectedMonth))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.clear)
            
            Section {
                VStack(spacing: 12) {
                    // 总收入
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("总收入")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.totalIncome as NSDecimalNumber)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    
                    // 总支出
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("总支出")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.totalExpense as NSDecimalNumber)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                    
                    // 净收入
                    let net = viewModel.totalIncome - viewModel.totalExpense
                    let isPositive = net >= 0
                    
                    HStack(spacing: 12) {
                        Image(systemName: isPositive ? "plus.circle.fill" : "minus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isPositive ? .blue : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("净收入")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(net as NSDecimalNumber)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isPositive ? .blue : .orange)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background((isPositive ? Color.blue : Color.orange).opacity(0.08))
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("总览")
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            
            if !viewModel.categoryStatistics.isEmpty {
                Section {
                    Picker("", selection: $categoryTab) {
                        ForEach(TransactionTypeTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    
                    if filteredCategoryStatistics.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无数据")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(filteredCategoryStatistics, id: \.key) { item in
                            HStack(spacing: 10) {
                                // 类型图标
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.7))
                                
                                Text(item.key)
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Text("\(item.value as NSDecimalNumber)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(colorForTab(categoryTab))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(colorForTab(categoryTab).opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.caption)
                        Text("按类型统计")
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            
            if !viewModel.ownerStatistics.isEmpty {
                Section {
                    Picker("", selection: $ownerTab) {
                        ForEach(TransactionTypeTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    
                    if filteredOwnerStatistics.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无数据")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(filteredOwnerStatistics, id: \.key) { item in
                            HStack(spacing: 10) {
                                // 归属人图标
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                
                                Text(item.key)
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Text("\(item.value as NSDecimalNumber)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(colorForTab(ownerTab))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(colorForTab(ownerTab).opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("按归属人统计")
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            
            if !viewModel.paymentMethodStatistics.isEmpty {
                Section {
                    Picker("", selection: $paymentTab) {
                        ForEach(TransactionTypeTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    
                    if filteredPaymentStatistics.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无数据")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(filteredPaymentStatistics, id: \.key) { item in
                            HStack(spacing: 10) {
                                // 支付方式图标
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.7))
                                
                                Text(item.key)
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Text("\(item.value as NSDecimalNumber)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(colorForTab(paymentTab))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(colorForTab(paymentTab).opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "creditcard.and.123")
                            .font(.caption)
                        Text("按支付方式统计")
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .refreshable {
            await loadStatistics()
        }
        .navigationTitle("统计分析")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingChartView = true }) {
                    Image(systemName: "chart.pie.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingChartView) {
            ChartStatisticsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingMonthPicker) {
            NavigationView {
                VStack {
                    DatePicker("选择月份", selection: $selectedMonth, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("选择月份")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showingMonthPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") {
                            showingMonthPicker = false
                            Task {
                                await loadStatistics()
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            // 延迟一小段时间确保数据库完全初始化
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            await loadStatistics()
        }
        .onChange(of: selectedTimeRange) { newValue in
            Task {
                await loadStatistics()
            }
        }
        .onChange(of: selectedMonth) { newValue in
            if selectedTimeRange == .customMonth {
                Task {
                    await loadStatistics()
                }
            }
        }
    }
    
    private func loadStatistics() async {
        do {
            let (startDate, endDate) = getDateRange(for: selectedTimeRange)
            await viewModel.calculateStatistics(startDate: startDate, endDate: endDate)
        } catch {
            print("❌ 统计数据加载失败: \(error)")
        }
    }
    
    private func getDateRange(for range: TimeRange) -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch range {
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            return (start, nil)
            
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                  let start = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return (nil, nil)
            }
            return (start, end)
            
        case .customMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
            guard let monthStart = start,
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return (nil, nil)
            }
            return (monthStart, monthEnd)
            
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))
            return (start, nil)
            
        case .all:
            return (nil, nil)
        }
    }
    
    // MARK: - Filtered Statistics
    
    private var filteredCategoryStatistics: [(key: String, value: Decimal)] {
        filterStatistics(viewModel.categoryStatistics, by: categoryTab, type: .category)
    }
    
    private var filteredOwnerStatistics: [(key: String, value: Decimal)] {
        filterStatistics(viewModel.ownerStatistics, by: ownerTab, type: .owner)
    }
    
    private var filteredPaymentStatistics: [(key: String, value: Decimal)] {
        filterStatistics(viewModel.paymentMethodStatistics, by: paymentTab, type: .payment)
    }
    
    private func filterStatistics(_ stats: [String: [TransactionType: Decimal]], by tab: TransactionTypeTab, type: StatisticsType) -> [(key: String, value: Decimal)] {
        var result: [(key: String, value: Decimal)] = []
        
        for (name, amounts) in stats {
            let value: Decimal
            switch tab {
            case .income:
                value = amounts[.income] ?? 0
            case .expense:
                value = amounts[.expense] ?? 0
            case .excluded:
                value = amounts[.excluded] ?? 0
            }
            
            if value > 0 {
                result.append((key: name, value: value))
            }
        }
        
        return result.sorted { $0.value > $1.value }
    }
    
    private func colorForTab(_ tab: TransactionTypeTab) -> Color {
        switch tab {
        case .income:
            return .green
        case .expense:
            return .red
        case .excluded:
            return .gray
        }
    }
    
    enum StatisticsType {
        case category
        case owner
        case payment
    }
    
    /// 格式化月份显示
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
}
