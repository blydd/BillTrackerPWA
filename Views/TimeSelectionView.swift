import SwiftUI

struct TimeSelectionView: View {
    @Binding var dateSelectionMode: StatisticsView.DateSelectionMode
    @Binding var selectedMonth: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    private let months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 选择模式切换
                    Picker("选择模式", selection: $dateSelectionMode) {
                        ForEach(StatisticsView.DateSelectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    if dateSelectionMode == .month {
                        monthSelectionView
                    } else {
                        dateRangeSelectionView
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("时间选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { onConfirm() }
                }
            }
        }
        .iOS16PresentationLargeCompat()
        .onAppear {
            selectedYear = Calendar.current.component(.year, from: selectedMonth)
        }
    }

    
    private var monthSelectionView: some View {
        VStack(spacing: 20) {
            // 年份选择
            HStack {
                Button(action: { selectedYear -= 1 }) {
                    Image(systemName: "chevron.left").font(.title2).foregroundColor(.blue)
                }
                Spacer()
                Text(String(format: "%d年", selectedYear))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { selectedYear += 1 }) {
                    Image(systemName: "chevron.right").font(.title2).foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // 九宫格月份选择
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(0..<12, id: \.self) { index in
                    let month = index + 1
                    Button(action: {
                        selectMonth(month)
                    }) {
                        Text(months[index])
                            .font(.system(size: 16, weight: isSelectedMonth(month) ? .bold : .regular))
                            .foregroundColor(isSelectedMonth(month) ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSelectedMonth(month) ? Color.blue : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    
    private var dateRangeSelectionView: some View {
        VStack(spacing: 20) {
            // 开始日期和结束日期放在同一行
            HStack(spacing: 16) {
                // 开始日期
                VStack(alignment: .leading, spacing: 8) {
                    Text("开始日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $customStartDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // 结束日期
                VStack(alignment: .leading, spacing: 8) {
                    Text("结束日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $customEndDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // 统计范围显示
            VStack(spacing: 8) {
                Text("统计范围")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatDateRange())
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    
    // MARK: - Helper Methods
    
    private func selectMonth(_ month: Int) {
        var components = DateComponents()
        components.year = selectedYear
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            selectedMonth = date
        }
    }
    
    private func isSelectedMonth(_ month: Int) -> Bool {
        let calendar = Calendar.current
        let selectedMonthValue = calendar.component(.month, from: selectedMonth)
        let selectedYearValue = calendar.component(.year, from: selectedMonth)
        return month == selectedMonthValue && selectedYear == selectedYearValue
    }
    
    private func formatSelectedMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: selectedMonth)
    }
    
    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日"
        let startStr = formatter.string(from: customStartDate)
        let endStr = formatter.string(from: customEndDate)
        return "\(startStr) - \(endStr)"
    }
}
