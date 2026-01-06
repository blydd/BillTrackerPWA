import SwiftUI

// MARK: - iOS 16 兼容性扩展

extension View {
    /// 应用 iOS 16 兼容的弹窗展示修饰符
    func iOS16PresentationCompat() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self.presentationDetents([.medium]))
        } else {
            return AnyView(self)
        }
    }
    
    /// 应用 iOS 16 兼容的大尺寸弹窗展示修饰符
    func iOS16PresentationLargeCompat() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden))
        } else {
            return AnyView(self)
        }
    }
    
    /// 应用 iOS 16 兼容的带拖拽指示器隐藏的弹窗展示修饰符
    func iOS16PresentationWithDragCompat() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden))
        } else {
            return AnyView(self)
        }
    }
    
    /// iOS 17 兼容的 listSectionSpacing
    func listSectionSpacingCompat(_ spacing: CGFloat) -> some View {
        if #available(iOS 17.0, *) {
            return AnyView(self.listSectionSpacing(spacing))
        } else {
            return AnyView(self)
        }
    }
}

/// 账单表单视图
struct BillFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var billViewModel: BillViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
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
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingUpgradePrompt = false
    @State private var showingDatePicker = false
    @State private var recentNotes: [String] = []
    @State private var isLoadingBillData = false  // 标志位：是否正在加载账单数据
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
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
                Picker("交易类型", selection: Binding(
                    get: { selectedTransactionType },
                    set: { newValue in
                        // 只有在非加载数据时才清空选择
                        if !isLoadingBillData && selectedTransactionType != newValue {
                            hideKeyboard()
                            selectedPaymentMethodId = nil
                            selectedCategoryIds.removeAll()
                        }
                        selectedTransactionType = newValue
                    }
                )) {
                    Text("支出").tag(TransactionType.expense)
                    Text("收入").tag(TransactionType.income)
                    Text("不计入").tag(TransactionType.excluded)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedOwnerId) { newOwnerId in
                    // 切换归属人时，自动切换到新归属人的支付方式（仅在非加载数据时）
                    guard !isLoadingBillData else { return }
                    guard let newOwnerId = newOwnerId else { return }
                    
                    // 获取当前选中的支付方式名称（去掉归属人前缀）
                    var currentPaymentMethodBaseName: String? = nil
                    if let selectedId = selectedPaymentMethodId,
                       let currentMethod = paymentMethods.first(where: { $0.id == selectedId }) {
                        currentPaymentMethodBaseName = displayPaymentMethodName(currentMethod.name)
                    }
                    
                    // 获取新归属人下的可用支付方式
                    let newOwnerPaymentMethods = getFilteredPaymentMethods(for: newOwnerId)
                    
                    if newOwnerPaymentMethods.isEmpty {
                        // 新归属人没有可用的支付方式，清空选择
                        selectedPaymentMethodId = nil
                    } else if let baseName = currentPaymentMethodBaseName,
                              let matchingMethod = newOwnerPaymentMethods.first(where: { displayPaymentMethodName($0.name) == baseName }) {
                        // 找到新归属人下的同名支付方式，自动切换
                        selectedPaymentMethodId = matchingMethod.id
                    } else {
                        // 没有同名支付方式，选择第一个可用的
                        selectedPaymentMethodId = newOwnerPaymentMethods.first?.id
                    }
                }
                
                List {
                    Section("基本信息") {
                        HStack {
                            TextField("金额", text: $amount)
                                .keyboardType(selectedTransactionType == .excluded ? .numbersAndPunctuation : .decimalPad)
                                .focused($isAmountFocused)
                                .onSubmit {
                                    // 输入完成后隐藏键盘
                                    isAmountFocused = false
                                }
                            
                            if selectedTransactionType == .excluded {
                                Text("(可输入负数)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 自定义日期时间选择
                        Button(action: {
                            hideKeyboard()
                            showingDatePicker = true
                        }) {
                            HStack {
                                Text("日期时间")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(formatDate(selectedDate))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // 归属人标签选择（放在最前面）
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("归属人")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                            
                            // 始终显示所有归属人选项，支持直接切换
                            FlowLayoutView(spacing: 8) {
                                ForEach(owners) { owner in
                                    SelectableTagView(
                                        text: owner.name,
                                        isSelected: selectedOwnerId == owner.id,
                                        color: .green
                                    ) {
                                        hideKeyboard()
                                        if selectedOwnerId == owner.id {
                                            // 点击已选中的归属人，取消选择
                                            selectedOwnerId = nil
                                        } else {
                                            // 点击其他归属人，直接切换
                                            selectedOwnerId = owner.id
                                        }
                                    }
                                }
                            }
                            .allowsHitTesting(true)
                        }
                        .padding(.bottom, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // 支付方式标签选择（只有选择了归属人后才显示）
                    if selectedOwnerId != nil {
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("支付方式")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                if filteredPaymentMethods.isEmpty {
                                    Text("该归属人暂无可用的支付方式")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                } else {
                                    // 始终显示所有支付方式选项，支持直接切换
                                    FlowLayoutView(spacing: 8) {
                                        ForEach(filteredPaymentMethods, id: \.id) { method in
                                            SelectableTagView(
                                                text: displayPaymentMethodName(method.name),
                                                isSelected: selectedPaymentMethodId == method.id,
                                                color: .blue
                                            ) {
                                                hideKeyboard()
                                                if selectedPaymentMethodId == method.id {
                                                    selectedPaymentMethodId = nil
                                                } else {
                                                    selectedPaymentMethodId = method.id
                                                }
                                            }
                                        }
                                    }
                                    .allowsHitTesting(true)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    
                    // 账单类型标签选择（多选）
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("账单类型")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.top, 8)
                            
                            if filteredCategories.isEmpty {
                                Text("暂无\(transactionTypeText)类型的账单类型")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            } else {
                                // 始终显示所有账单类型选项（多选）
                                FlowLayoutView(spacing: 8) {
                                    ForEach(filteredCategories) { category in
                                        SelectableTagView(
                                            text: category.name,
                                            isSelected: selectedCategoryIds.contains(category.id),
                                            color: .orange
                                        ) {
                                            hideKeyboard()
                                            if selectedCategoryIds.contains(category.id) {
                                                selectedCategoryIds.remove(category.id)
                                            } else {
                                                selectedCategoryIds.insert(category.id)
                                            }
                                        }
                                    }
                                }
                                .allowsHitTesting(true)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    Section("备注") {
                        TextField("输入备注", text: $note)
                            .focused($isNoteFocused)
                        
                        // 最近备注快速选择
                        if !recentNotes.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentNotes, id: \.self) { recentNote in
                                        Text(recentNote)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.gray.opacity(0.15))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                note = recentNote
                                                hideKeyboard()
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.insetGrouped)
                .environment(\.defaultMinListHeaderHeight, 0)
                .listSectionSpacingCompat(12)
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
                
                // 键盘工具栏
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        hideKeyboard()
                    }
                }
            }
            .onTapGesture {
                // 点击空白区域隐藏键盘
                hideKeyboard()
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // 如果是编辑模式，填充数据（延迟执行以确保 onChange 不会干扰）
                if let bill = editingBill {
                    isLoadingBillData = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        loadBillData(bill)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isLoadingBillData = false
                        }
                    }
                } else {
                    // 页面出现时自动聚焦到金额输入框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAmountFocused = true
                    }
                }
                // 加载最近备注
                loadRecentNotes()
            }
            .upgradePrompt(
                isPresented: $showingUpgradePrompt,
                title: "已达到账单上限",
                message: "免费版最多支持 500 条账单记录\n升级到 Pro 版解锁无限账单",
                feature: "unlimited_bills"
            )
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    VStack {
                        DatePicker("选择日期时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("选择日期时间")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("确定") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .iOS16PresentationCompat()
            }
        }
    }
    
    // 根据选中的交易类型和归属人过滤支付方式
    private var filteredPaymentMethods: [PaymentMethodWrapper] {
        guard let ownerId = selectedOwnerId else {
            return getFilteredPaymentMethods(for: nil)
        }
        return getFilteredPaymentMethods(for: ownerId)
    }
    
    // 根据交易类型和指定归属人过滤支付方式
    private func getFilteredPaymentMethods(for ownerId: UUID?) -> [PaymentMethodWrapper] {
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
        
        // 如果指定了归属人，进一步过滤支付方式（信贷和储蓄都需要匹配归属人）
        if let ownerId = ownerId {
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
        // 检查账单数量限制（仅在创建新账单时检查）
        if editingBill == nil {
            let currentCount = billViewModel.bills.count
            if !subscriptionManager.canCreateBill(currentBillCount: currentCount) {
                showingUpgradePrompt = true
                return
            }
        }
        
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
        // 先判断交易类型（需要在填充其他数据之前设置，因为filteredCategories依赖它）
        // 根据账单的类型来判断交易类型
        let billCategories = bill.categoryIds.compactMap { categoryId in
            categories.first(where: { $0.id == categoryId })
        }
        
        if !billCategories.isEmpty {
            // 如果所有类型都是不计入，则为不计入
            if billCategories.allSatisfy({ $0.transactionType == .excluded }) {
                selectedTransactionType = .excluded
            } else if billCategories.allSatisfy({ $0.transactionType == .income }) {
                selectedTransactionType = .income
            } else if billCategories.allSatisfy({ $0.transactionType == .expense }) {
                selectedTransactionType = .expense
            } else {
                // 混合类型，根据金额判断
                if bill.amount > 0 {
                    selectedTransactionType = .income
                } else {
                    selectedTransactionType = .expense
                }
            }
        } else {
            // 没有类型信息，根据金额判断
            if bill.amount > 0 {
                selectedTransactionType = .income
            } else {
                selectedTransactionType = .expense
            }
        }
        
        // 填充金额
        amount = String(describing: abs(bill.amount))
        
        // 填充归属人（需要在支付方式之前设置）
        selectedOwnerId = bill.ownerId
        
        // 填充支付方式
        selectedPaymentMethodId = bill.paymentMethodId
        
        // 填充账单类型
        selectedCategoryIds = Set(bill.categoryIds)
        
        // 填充备注
        note = bill.note ?? ""
        
        // 填充日期
        selectedDate = bill.createdAt
    }
    
    /// 加载最近备注
    private func loadRecentNotes() {
        Task {
            await billViewModel.loadBills()
            // 获取最近有备注的账单，去重，最多显示5条
            let notes = billViewModel.bills
                .compactMap { $0.note }
                .filter { !$0.isEmpty }
            
            // 去重并保持顺序
            var seen = Set<String>()
            var uniqueNotes: [String] = []
            for n in notes {
                if !seen.contains(n) {
                    seen.insert(n)
                    uniqueNotes.append(n)
                }
                if uniqueNotes.count >= 5 {
                    break
                }
            }
            
            await MainActor.run {
                recentNotes = uniqueNotes
            }
        }
    }
    
    /// 隐藏键盘
    private func hideKeyboard() {
        isAmountFocused = false
        isNoteFocused = false
        
        // 强制隐藏键盘的备用方法
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 格式化日期显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 可选择标签视图
struct SelectableTagView: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            Text(text)
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.2))
                .foregroundColor(isSelected ? .white : color)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: isSelected ? 0 : 1)
                )
                .overlay(alignment: .trailing) {
                    if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(.trailing, 4)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - iOS 15 兼容的紧凑布局
struct FlowLayoutView<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        // 使用更紧凑的 LazyVGrid 配置
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 50, maximum: 150), spacing: spacing)
            ],
            spacing: spacing
        ) {
            content
        }
    }
}


