import SwiftUI

/// 统计视图
struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @State private var selectedTimeRange: TimeRange = .thisMonth
    
    enum TimeRange: String, CaseIterable {
        case thisMonth = "本月"
        case lastMonth = "上月"
        case thisYear = "今年"
        case all = "全部"
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
                Section("按类型统计") {
                                       ForEach(Array(viewModel.categoryStatistics.keys.sorted()), id: \.self) { categoryName in
                        if let amount = viewModel.categoryStatistics[categoryName] {
                            HStack {
                                Text(categoryName)
                                Spacer()
                                Text("\(amount as NSDecimalNumber)")
                            }
                        }
                    }
                }
            }
            
            if !viewModel.ownerStatistics.isEmpty {
                Section("按归属人统计") {
                                       ForEach(Array(viewModel.ownerStatistics.keys.sorted()), id: \.self) { ownerName in
                        if let amount = viewModel.ownerStatistics[ownerName] {
                            HStack {
                                Text(ownerName)
                                Spacer()
                                Text("\(amount as NSDecimalNumber)")
                            }
                        }
                    }
                }
            }
            
            if !viewModel.paymentMethodStatistics.isEmpty {
                Section("按支付方式统计") {
                                       ForEach(Array(viewModel.paymentMethodStatistics.keys.sorted()), id: \.self) { methodName in
                        if let amount = viewModel.paymentMethodStatistics[methodName] {
                            HStack {
                                Text(methodName)
                                Spacer()
                                Text("\(amount as NSDecimalNumber)")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("统计分析")
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
}
