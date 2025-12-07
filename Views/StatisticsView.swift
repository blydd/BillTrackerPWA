import SwiftUI

/// 统计视图
struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @State private var selectedTimeRange: TimeRange = .thisMonth
    @State private var showingChartView = false
    @State private var categoryTab: TransactionTypeTab = .expense
    @State private var ownerTab: TransactionTypeTab = .expense
    @State private var paymentTab: TransactionTypeTab = .expense
    
    enum TimeRange: String, CaseIterable {
        case thisMonth = "本月"
        case lastMonth = "上月"
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
            }
            .listRowBackground(Color.clear)
            
            Section("总览") {
                HStack {
                    Text("总收入")
                    Spacer()
                    Text("\(viewModel.totalIncome as NSDecimalNumber)")
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("总支出")
                    Spacer()
                    Text("\(viewModel.totalExpense as NSDecimalNumber)")
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("净收入")
                    Spacer()
                    let net = viewModel.totalIncome - viewModel.totalExpense
                    Text("\(net as NSDecimalNumber)")
                        .foregroundColor(net >= 0 ? .green : .red)
                }
            }
            
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
                            HStack {
                                Text(item.key)
                                Spacer()
                                Text("\(item.value as NSDecimalNumber)")
                                    .foregroundColor(colorForTab(categoryTab))
                            }
                        }
                    }
                } header: {
                    Text("按类型统计")
                }
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
                            HStack {
                                Text(item.key)
                                Spacer()
                                Text("\(item.value as NSDecimalNumber)")
                                    .foregroundColor(colorForTab(ownerTab))
                            }
                        }
                    }
                } header: {
                    Text("按归属人统计")
                }
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
                            HStack {
                                Text(item.key)
                                Spacer()
                                Text("\(item.value as NSDecimalNumber)")
                                    .foregroundColor(colorForTab(paymentTab))
                            }
                        }
                    }
                } header: {
                    Text("按支付方式统计")
                }
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
        .task {
            await loadStatistics()
        }
        .onChange(of: selectedTimeRange) { oldValue, newValue in
            Task {
                await loadStatistics()
            }
        }
    }
    
    private func loadStatistics() async {
        let (startDate, endDate) = getDateRange(for: selectedTimeRange)
        await viewModel.calculateStatistics(startDate: startDate, endDate: endDate)
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
}
