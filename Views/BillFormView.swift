import SwiftUI

/// 账单表单视图
struct BillFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var billViewModel: BillViewModel
    
    let categories: [BillCategory]
    let owners: [Owner]
    let paymentMethods: [PaymentMethodWrapper]
    let editingBill: Bill?
    let onBillAdded: () -> Void
    
    @State private var selectedTransactionType: TransactionType = .expense
    @State private var amount = ""
    @State private var selectedPaymentMethodId: UUID?
    @State private var selectedCategoryIds: Set<UUID> = []
    @State private var selectedOwnerId: UUID?
    @State private var note = ""
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isAmountFocused: Bool
    
    init(repository: DataRepository,
         categories: [BillCategory],
         owners: [Owner],
         paymentMethods: [PaymentMethodWrapper],
         editingBill: Bill? = nil,
         onBillAdded: @escaping () -> Void) {
        _billViewModel = StateObject(wrappedValue: BillViewModel(repository: repository))
        self.categories = categories
        self.owners = owners
        self.paymentMethods = paymentMethods
        self.editingBill = editingBill
        self.onBillAdded = onBillAdded
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab 选择器
                Picker("交易类型", selection: $selectedTransactionType) {
                    Text("支出").tag(TransactionType.expense)
                    Text("收入").tag(TransactionType.income)
                    Text("不计入").tag(TransactionType.excluded)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedTransactionType) { _ in
                    // 切换Tab时清空选择
                    selectedPaymentMethodId = nil
                    selectedCategoryIds.removeAll()
                }
                .onChange(of: selectedOwnerId) { _ in
                    // 切换归属人时，如果当前选择的支付方式不在过滤后的列表中，清空选择
                    if let selectedId = selectedPaymentMethodId,
                       !filteredPaymentMethods.contains(where: { $0.id == selectedId }) {
                        selectedPaymentMethodId = nil
                    }
                }
                
                Form {
                    Section("基本信息") {
                        HStack {
                            TextField("金额", text: $amount)
                                .keyboardType(selectedTransactionType == .excluded ? .numbersAndPunctuation : .decimalPad)
                                .focused($isAmountFocused)
                            
                            if selectedTransactionType == .excluded {
                                Text("(可输入负数)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("日期")
                            Spacer()
                            Text(formattedDate)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingDatePicker = true
                        }
                        
                        DatePicker("时间", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                    }
                    
                    // 归属人标签选择（放在最前面）
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("归属人")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let selectedId = selectedOwnerId,
                               let selected = owners.first(where: { $0.id == selectedId }) {
                                SelectableTagView(
                                    text: selected.name,
                                    isSelected: true,
                                    color: .green
                                ) {
                                    selectedOwnerId = nil
                                }
                            } else {
                                FlowLayout(spacing: 8) {
                                    ForEach(owners) { owner in
                                        SelectableTagView(
                                            text: owner.name,
                                            isSelected: false,
                                            color: .green
                                        ) {
                                            selectedOwnerId = owner.id
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 支付方式标签选择（只有选择了归属人后才显示）
                    if selectedOwnerId != nil {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("支付方式")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if filteredPaymentMethods.isEmpty {
                                    Text("该归属人暂无可用的支付方式")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                } else if let selectedId = selectedPaymentMethodId,
                                          let selected = filteredPaymentMethods.first(where: { $0.id == selectedId }) {
                                    SelectableTagView(
                                        text: displayPaymentMethodName(selected.name),
                                        isSelected: true,
                                        color: .blue
                                    ) {
                                        selectedPaymentMethodId = nil
                                    }
                                } else {
                                    FlowLayout(spacing: 8) {
                                        ForEach(filteredPaymentMethods, id: \.id) { method in
                                            SelectableTagView(
                                                text: displayPaymentMethodName(method.name),
                                                isSelected: false,
                                                color: .blue
                                            ) {
                                                selectedPaymentMethodId = method.id
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // 账单类型标签选择（多选）
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("账单类型")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if filteredCategories.isEmpty {
                                Text("暂无\(transactionTypeText)类型的账单类型")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                // 已选中的标签
                                if !selectedCategoryIds.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(filteredCategories.filter { selectedCategoryIds.contains($0.id) }) { category in
                                            SelectableTagView(
                                                text: category.name,
                                                isSelected: true,
                                                color: .orange
                                            ) {
                                                selectedCategoryIds.remove(category.id)
                                            }
                                        }
                                    }
                                }
                                
                                // 未选中的标签
                                FlowLayout(spacing: 8) {
                                    ForEach(filteredCategories.filter { !selectedCategoryIds.contains($0.id) }) { category in
                                        SelectableTagView(
                                            text: category.name,
                                            isSelected: false,
                                            color: .orange
                                        ) {
                                            selectedCategoryIds.insert(category.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section("备注") {
                        TextEditor(text: $note)
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle(editingBill == nil ? "添加账单" : "编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveBill()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // 如果是编辑模式，填充数据
                if let bill = editingBill {
                    loadBillData(bill)
                } else {
                    // 页面出现时自动聚焦到金额输入框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAmountFocused = true
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    DatePicker("选择日期", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("选择日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("完成") {
                                    showingDatePicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    /// 格式化日期为 yyyy-MM-dd
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
    
    // 根据选中的交易类型和归属人过滤支付方式
    private var filteredPaymentMethods: [PaymentMethodWrapper] {
        var filtered: [PaymentMethodWrapper] = []
        
        switch selectedTransactionType {
        case .expense:
            // 支出：显示所有支出类型的支付方式（信贷和储蓄）
            filtered = paymentMethods.filter { $0.transactionType == .expense }
            
        case .income:
            // 收入：只显示储蓄方式
            filtered = paymentMethods.filter { method in
                if case .savings = method {
                    return true
                }
                return false
            }
            
        case .excluded:
            // 不计入：可以选择支出和收入的所有支付方式
            filtered = paymentMethods.filter { $0.transactionType == .expense || $0.transactionType == .income }
        }
        
        // 如果选择了归属人，进一步过滤支付方式（信贷和储蓄都需要匹配归属人）
        if let ownerId = selectedOwnerId {
            filtered = filtered.filter { method in
                method.ownerId == ownerId
            }
        }
        
        return filtered
    }
    
    // 根据选中的交易类型过滤账单类型
    private var filteredCategories: [BillCategory] {
        categories.filter { $0.transactionType == selectedTransactionType }
    }
    
    private var transactionTypeText: String {
        switch selectedTransactionType {
        case .expense:
            return "支出"
        case .income:
            return "收入"
        case .excluded:
            return "不计入"
        }
    }
    
    /// 处理支付方式名称显示，去掉"归属人-"前缀
    private func displayPaymentMethodName(_ name: String) -> String {
        // 如果名称包含"-"，则去掉第一个"-"之前的部分
        if let dashIndex = name.firstIndex(of: "-") {
            let startIndex = name.index(after: dashIndex)
            return String(name[startIndex...])
        }
        return name
    }
    
    private var isFormValid: Bool {
        // 验证金额
        guard let amountValue = Decimal(string: amount) else {
            return false
        }
        
        // 不计入类型允许负数，其他类型必须大于0
        if selectedTransactionType == .excluded {
            guard amountValue != 0 else {
                return false
            }
        } else {
            guard amountValue > 0 else {
                return false
            }
        }
        
        guard selectedPaymentMethodId != nil else {
            return false
        }
        guard !selectedCategoryIds.isEmpty else {
            return false
        }
        guard selectedOwnerId != nil else {
            return false
        }
        return true
    }
    
    private func saveBill() async {
        guard var amountValue = Decimal(string: amount),
              let paymentMethodId = selectedPaymentMethodId,
              let ownerId = selectedOwnerId else {
            errorMessage = "请填写完整信息"
            showingError = true
            return
        }
        
        // 根据交易类型调整金额符号
        switch selectedTransactionType {
        case .expense:
            // 支出：转为负数
            amountValue = abs(amountValue) * -1
        case .income:
            // 收入：转为正数
            amountValue = abs(amountValue)
        case .excluded:
            // 不计入：保持用户输入的符号
            break
        }
        
        do {
            if let bill = editingBill {
                // 编辑模式
                try await billViewModel.updateBill(
                    bill,
                    amount: amountValue,
                    paymentMethodId: paymentMethodId,
                    categoryIds: Array(selectedCategoryIds),
                    ownerId: ownerId,
                    note: note.isEmpty ? nil : note,
                    createdAt: selectedDate
                )
            } else {
                // 创建模式
                if selectedTransactionType == .excluded {
                    try await billViewModel.createBillWithExcludedType(
                        amount: amountValue,
                        paymentMethodId: paymentMethodId,
                        categoryIds: Array(selectedCategoryIds),
                        ownerId: ownerId,
                        note: note.isEmpty ? nil : note,
                        createdAt: selectedDate
                    )
                } else {
                    try await billViewModel.createBill(
                        amount: amountValue,
                        paymentMethodId: paymentMethodId,
                        categoryIds: Array(selectedCategoryIds),
                        ownerId: ownerId,
                        note: note.isEmpty ? nil : note,
                        createdAt: selectedDate
                    )
                }
            }
            onBillAdded() // 通知列表页刷新
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func loadBillData(_ bill: Bill) {
        // 填充金额
        amount = String(describing: abs(bill.amount))
        
        // 填充支付方式
        selectedPaymentMethodId = bill.paymentMethodId
        
        // 填充账单类型
        selectedCategoryIds = Set(bill.categoryIds)
        
        // 填充归属人
        selectedOwnerId = bill.ownerId
        
        // 填充备注
        note = bill.note ?? ""
        
        // 填充日期
        selectedDate = bill.createdAt
        
        // 判断交易类型
        if let paymentMethod = paymentMethods.first(where: { $0.id == bill.paymentMethodId }) {
            selectedTransactionType = paymentMethod.transactionType
        }
    }
}

// MARK: - 可选择标签视图
struct SelectableTagView: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.subheadline)
                
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.2))
            .foregroundColor(isSelected ? .white : color)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
