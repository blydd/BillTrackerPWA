import SwiftUI

/// 筛选面板视图
struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let owners: [Owner]
    let categories: [BillCategory]
    let paymentMethods: [PaymentMethodWrapper]
    
    @Binding var selectedOwnerIds: Set<UUID>
    @Binding var selectedCategoryIds: Set<UUID>
    @Binding var selectedPaymentMethodIds: Set<UUID>
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    @State private var tempStartDate: Date = Date()
    @State private var tempEndDate: Date = Date()
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                // 归属人筛选
                Section("归属人") {
                    ForEach(owners) { owner in
                        Button(action: {
                            if selectedOwnerIds.contains(owner.id) {
                                selectedOwnerIds.remove(owner.id)
                                // 清空支付方式筛选
                                selectedPaymentMethodIds.removeAll()
                            } else {
                                selectedOwnerIds.insert(owner.id)
                            }
                        }) {
                            HStack {
                                Text(owner.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedOwnerIds.contains(owner.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 账单类型筛选
                Section("账单类型") {
                    ForEach(categories) { category in
                        Button(action: {
                            if selectedCategoryIds.contains(category.id) {
                                selectedCategoryIds.remove(category.id)
                            } else {
                                selectedCategoryIds.insert(category.id)
                            }
                        }) {
                            HStack {
                                Text(category.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedCategoryIds.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 支付方式筛选（只有选择了归属人后才显示）
                if !selectedOwnerIds.isEmpty {
                    Section("支付方式") {
                        ForEach(filteredPaymentMethods) { method in
                            Button(action: {
                                if selectedPaymentMethodIds.contains(method.id) {
                                    selectedPaymentMethodIds.remove(method.id)
                                } else {
                                    selectedPaymentMethodIds.insert(method.id)
                                }
                            }) {
                                HStack {
                                    Text(displayPaymentMethodName(method.name))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedPaymentMethodIds.contains(method.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 日期范围筛选
                Section("日期范围") {
                    Toggle("开始日期", isOn: Binding(
                        get: { startDate != nil },
                        set: { enabled in
                            if enabled {
                                startDate = tempStartDate
                            } else {
                                startDate = nil
                            }
                        }
                    ))
                    
                    if startDate != nil {
                        DatePicker("", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ), displayedComponents: [.date])
                        .labelsHidden()
                    }
                    
                    Toggle("结束日期", isOn: Binding(
                        get: { endDate != nil },
                        set: { enabled in
                            if enabled {
                                endDate = tempEndDate
                            } else {
                                endDate = nil
                            }
                        }
                    ))
                    
                    if endDate != nil {
                        DatePicker("", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: [.date])
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("筛选条件")
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
    
    // 根据选择的归属人过滤支付方式
    private var filteredPaymentMethods: [PaymentMethodWrapper] {
        paymentMethods.filter { method in
            selectedOwnerIds.contains(method.ownerId)
        }
    }
    
    /// 处理支付方式名称显示，去掉"归属人-"前缀
    private func displayPaymentMethodName(_ name: String) -> String {
        if let dashIndex = name.firstIndex(of: "-") {
            let startIndex = name.index(after: dashIndex)
            return String(name[startIndex...])
        }
        return name
    }
}
