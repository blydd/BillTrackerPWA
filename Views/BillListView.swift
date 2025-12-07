import SwiftUI

/// 账单列表视图
struct BillListView: View {
    @StateObject private var billViewModel: BillViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    @StateObject private var ownerViewModel: OwnerViewModel
    @StateObject private var paymentViewModel: PaymentMethodViewModel
    @StateObject private var exportViewModel: ExportViewModel
    
    @State private var showingAddSheet = false
    @State private var showingError = false
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingFilterSheet = false
    @State private var isFilterExpanded = true
    @State private var showScrollToTopButton = false
    @State private var editingBill: Bill?
    
    // 筛选条件
    @State private var selectedOwnerIds: Set<UUID> = []
    @State private var selectedCategoryIds: Set<UUID> = []
    @State private var selectedPaymentMethodIds: Set<UUID> = []
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    
    // 分页和缓存
    @State private var displayedBillsCount = 50 // 初始显示50条
    @State private var isLoadingMore = false
    @State private var cachedFilteredBills: [Bill] = []
    @State private var cacheKey: String = ""
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
        _billViewModel = StateObject(wrappedValue: BillViewModel(repository: repository))
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(repository: repository))
        _ownerViewModel = StateObject(wrappedValue: OwnerViewModel(repository: repository))
        _paymentViewModel = StateObject(wrappedValue: PaymentMethodViewModel(repository: repository))
        _exportViewModel = StateObject(wrappedValue: ExportViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 筛选条件显示区域（可折叠）
            if hasActiveFilters {
                VStack(spacing: 0) {
                    // 折叠/展开按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isFilterExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("筛选条件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    if isFilterExpanded {
                        FlowLayout(spacing: 8) {
                            // 归属人筛选标签
                            ForEach(Array(selectedOwnerIds), id: \.self) { ownerId in
                                if let owner = ownerViewModel.owners.first(where: { $0.id == ownerId }) {
                                    FilterTagView(text: owner.name, color: .green) {
                                        selectedOwnerIds.remove(ownerId)
                                        selectedPaymentMethodIds.removeAll()
                                    }
                                }
                            }
                            
                            // 账单类型筛选标签
                            ForEach(Array(selectedCategoryIds), id: \.self) { categoryId in
                                if let category = categoryViewModel.categories.first(where: { $0.id == categoryId }) {
                                    FilterTagView(text: category.name, color: .orange) {
                                        selectedCategoryIds.remove(categoryId)
                                    }
                                }
                            }
                            
                            // 支付方式筛选标签
                            ForEach(Array(selectedPaymentMethodIds), id: \.self) { methodId in
                                if let method = paymentViewModel.paymentMethods.first(where: { $0.id == methodId }) {
                                    FilterTagView(text: displayPaymentMethodName(method.name), color: .blue) {
                                        selectedPaymentMethodIds.remove(methodId)
                                    }
                                }
                            }
                            
                            // 日期范围标签
                            if startDate != nil || endDate != nil {
                                FilterTagView(text: dateRangeText, color: .purple) {
                                    startDate = nil
                                    endDate = nil
                                }
                            }
                            
                            // 清空所有筛选
                            Button(action: clearAllFilters) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("清空")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            
            // 账单列表
            if filteredBills.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: billViewModel.bills.isEmpty ? "暂无账单" : "无符合条件的账单",
                    message: billViewModel.bills.isEmpty ? "点击右上角的 + 按钮创建第一条账单记录" : "尝试调整筛选条件"
                )
            } else {
                List {
                    ForEach(groupedFilteredBills.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedFilteredBills[date] ?? []) { bill in
                                BillRowView(
                                    bill: bill,
                                    categories: categoryViewModel.categories,
                                    owners: ownerViewModel.owners,
                                    paymentMethods: paymentViewModel.paymentMethods,
                                    onEdit: { bill in
                                        editingBill = bill
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await billViewModel.deleteBill(bill)
                                                await loadData()
                                            } catch {
                                                showingError = true
                                            }
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        } header: {
                            DailySummaryHeader(
                                date: date,
                                bills: getBillsForDate(date),
                                paymentMethods: paymentViewModel.paymentMethods,
                                categories: categoryViewModel.categories
                            )
                        }
                    }
                    
                    // 加载更多指示器
                    if paginatedBills.count < filteredBills.count {
                        Section {
                            HStack {
                                Spacer()
                                if isLoadingMore {
                                    ProgressView()
                                } else {
                                    Button("加载更多") {
                                        loadMoreBills()
                                    }
                                }
                                Spacer()
                            }
                            .onAppear {
                                loadMoreBills()
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 20) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title3)
                            Text("筛选")
                                .font(.headline)
                        }
                        .foregroundColor(hasActiveFilters ? .blue : .primary)
                    }
                    
                    Button {
                        exportBills()
                    } label: {
                        HStack(spacing: 6) {
                            if exportViewModel.isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                Text("导出")
                                    .font(.headline)
                            }
                        }
                    }
                    .disabled(billViewModel.bills.isEmpty || exportViewModel.isExporting)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            BillFormView(
                repository: repository,
                categories: categoryViewModel.categories,
                owners: ownerViewModel.owners,
                paymentMethods: paymentViewModel.paymentMethods
            ) {
                // 添加账单后刷新列表
                Task {
                    await loadData()
                }
            }
        }
        .sheet(item: $editingBill) { bill in
            BillFormView(
                repository: repository,
                categories: categoryViewModel.categories,
                owners: ownerViewModel.owners,
                paymentMethods: paymentViewModel.paymentMethods,
                editingBill: bill
            ) {
                // 编辑账单后刷新列表
                Task {
                    await loadData()
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let fileURL = exportedFileURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = billViewModel.errorMessage {
                Text(error)
            } else if let error = exportViewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(
                owners: ownerViewModel.owners,
                categories: categoryViewModel.categories,
                paymentMethods: paymentViewModel.paymentMethods,
                selectedOwnerIds: $selectedOwnerIds,
                selectedCategoryIds: $selectedCategoryIds,
                selectedPaymentMethodIds: $selectedPaymentMethodIds,
                startDate: $startDate,
                endDate: $endDate
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .task {
            await loadData()
        }
    }
    
    // 筛选后的账单（带缓存）
    private var filteredBills: [Bill] {
        let currentCacheKey = generateCacheKey()
        
        // 如果缓存键相同，返回缓存结果
        if currentCacheKey == cacheKey && !cachedFilteredBills.isEmpty {
            return cachedFilteredBills
        }
        
        var bills = billViewModel.bills
        
        // 按归属人筛选
        if !selectedOwnerIds.isEmpty {
            bills = bills.filter { selectedOwnerIds.contains($0.ownerId) }
        }
        
        // 按账单类型筛选
        if !selectedCategoryIds.isEmpty {
            bills = bills.filter { bill in
                !Set(bill.categoryIds).isDisjoint(with: selectedCategoryIds)
            }
        }
        
        // 按支付方式筛选
        if !selectedPaymentMethodIds.isEmpty {
            bills = bills.filter { selectedPaymentMethodIds.contains($0.paymentMethodId) }
        }
        
        // 按日期范围筛选
        if let start = startDate {
            bills = bills.filter { $0.createdAt >= start }
        }
        if let end = endDate {
            // 结束日期包含当天的23:59:59
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            bills = bills.filter { $0.createdAt <= endOfDay }
        }
        
        // 更新缓存
        DispatchQueue.main.async {
            cachedFilteredBills = bills
            cacheKey = currentCacheKey
        }
        
        return bills
    }
    
    // 生成缓存键
    private func generateCacheKey() -> String {
        let ownerKey = selectedOwnerIds.sorted().map { $0.uuidString }.joined(separator: ",")
        let categoryKey = selectedCategoryIds.sorted().map { $0.uuidString }.joined(separator: ",")
        let paymentKey = selectedPaymentMethodIds.sorted().map { $0.uuidString }.joined(separator: ",")
        let dateKey = "\(startDate?.timeIntervalSince1970 ?? 0)-\(endDate?.timeIntervalSince1970 ?? 0)"
        // 使用账单数量和最后更新时间作为缓存键的一部分
        let billsKey = "\(billViewModel.bills.count)-\(billViewModel.bills.map { $0.updatedAt.timeIntervalSince1970 }.max() ?? 0)"
        return "\(ownerKey)|\(categoryKey)|\(paymentKey)|\(dateKey)|\(billsKey)"
    }
    
    // 分页显示的账单（确保同一天的账单完整显示）
    private var paginatedBills: [Bill] {
        let bills = filteredBills
        
        // 如果账单数量小于等于显示数量，直接返回全部
        if bills.count <= displayedBillsCount {
            return bills
        }
        
        // 获取前 displayedBillsCount 条
        let initialBills = Array(bills.prefix(displayedBillsCount))
        
        // 如果没有账单，直接返回
        guard let lastBill = initialBills.last else {
            return initialBills
        }
        
        // 获取最后一条账单的日期
        let calendar = Calendar.current
        let lastBillDate = calendar.startOfDay(for: lastBill.createdAt)
        
        // 找出所有与最后一条账单同一天的账单
        var result = initialBills
        let remainingBills = bills.dropFirst(displayedBillsCount)
        
        for bill in remainingBills {
            let billDate = calendar.startOfDay(for: bill.createdAt)
            if billDate == lastBillDate {
                result.append(bill)
            } else {
                // 遇到不同日期的账单，停止添加
                break
            }
        }
        
        return result
    }
    
    // 按日期分组筛选后的账单（使用分页数据）
    private var groupedFilteredBills: [String: [Bill]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var grouped: [String: [Bill]] = [:]
        
        for bill in paginatedBills {
            let dateString = dateFormatter.string(from: bill.createdAt)
            if grouped[dateString] == nil {
                grouped[dateString] = []
            }
            grouped[dateString]?.append(bill)
        }
        
        // 每天内的账单按时间倒序排列
        for (date, bills) in grouped {
            grouped[date] = bills.sorted(by: { $0.createdAt > $1.createdAt })
        }
        
        return grouped
    }
    
    // 获取某一天的完整账单列表（用于汇总计算）
    private func getBillsForDate(_ dateString: String) -> [Bill] {
        // 使用完整的筛选结果而不是分页结果，确保汇总准确
        return filteredBills.filter { bill in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: bill.createdAt) == dateString
        }
    }
    
    // 是否有激活的筛选条件
    private var hasActiveFilters: Bool {
        !selectedOwnerIds.isEmpty || !selectedCategoryIds.isEmpty || !selectedPaymentMethodIds.isEmpty || startDate != nil || endDate != nil
    }
    
    // 日期范围文本
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
        return ""
    }
    
    // 清空所有筛选条件
    private func clearAllFilters() {
        selectedOwnerIds.removeAll()
        selectedCategoryIds.removeAll()
        selectedPaymentMethodIds.removeAll()
        startDate = nil
        endDate = nil
        clearCache()
    }
    
    // 加载更多账单
    private func loadMoreBills() {
        guard !isLoadingMore else { return }
        guard paginatedBills.count < filteredBills.count else { return }
        
        isLoadingMore = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            displayedBillsCount += 50
            isLoadingMore = false
        }
    }
    
    // 清除缓存
    private func clearCache() {
        cachedFilteredBills.removeAll()
        cacheKey = ""
        displayedBillsCount = 50
    }
    
    /// 处理支付方式名称显示，去掉"归属人-"前缀
    private func displayPaymentMethodName(_ name: String) -> String {
        if let dashIndex = name.firstIndex(of: "-") {
            let startIndex = name.index(after: dashIndex)
            return String(name[startIndex...])
        }
        return name
    }
    
    // 按日期分组账单
    private var groupedBills: [String: [Bill]] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var grouped: [String: [Bill]] = [:]
        
        for bill in billViewModel.bills {
            let dateString = dateFormatter.string(from: bill.createdAt)
            if grouped[dateString] == nil {
                grouped[dateString] = []
            }
            grouped[dateString]?.append(bill)
        }
        
        // 每天内的账单按时间倒序排列
        for (date, bills) in grouped {
            grouped[date] = bills.sorted(by: { $0.createdAt > $1.createdAt })
        }
        
        return grouped
    }
    
    private func loadData() async {
        await billViewModel.loadBills()
        await categoryViewModel.loadCategories()
        await ownerViewModel.loadOwners()
        await paymentViewModel.loadPaymentMethods()
        
        // 清空缓存，强制重新计算
        cachedFilteredBills = []
        cacheKey = ""
    }
    
    private func exportBills() {
        Task {
            do {
                let fileURL = try await exportViewModel.exportToCSV(
                    bills: billViewModel.bills,
                    categories: categoryViewModel.categories,
                    owners: ownerViewModel.owners,
                    paymentMethods: paymentViewModel.paymentMethods
                )
                exportedFileURL = fileURL
                showingExportSheet = true
            } catch {
                showingError = true
            }
        }
    }
    
    private func deleteBillsInSection(date: String, at offsets: IndexSet) {
        guard let bills = groupedBills[date] else { return }
        
        Task {
            for index in offsets {
                let bill = bills[index]
                do {
                    try await billViewModel.deleteBill(bill)
                } catch {
                    showingError = true
                }
            }
        }
    }
}

/// 每日汇总头部视图
struct DailySummaryHeader: View {
    let date: String
    let bills: [Bill]
    let paymentMethods: [PaymentMethodWrapper]
    let categories: [BillCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date)
                .font(.headline)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("收入:")
                        .font(.caption)
                    Text("¥\(dailyIncome as NSDecimalNumber, formatter: numberFormatter)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack(spacing: 4) {
                    Text("支出:")
                        .font(.caption)
                    Text("¥\(dailyExpense as NSDecimalNumber, formatter: numberFormatter)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .textCase(nil)
    }
    
    private var dailyIncome: Decimal {
        bills.reduce(0) { total, bill in
            // 检查账单是否为不计入类型
            let billCategories = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            
            // 如果账单的所有类型都是不计入，则排除
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            
            if isExcluded {
                return total
            }
            
            // 金额为正数表示收入
            if bill.amount > 0 {
                return total + bill.amount
            }
            return total
        }
    }
    
    private var dailyExpense: Decimal {
        bills.reduce(0) { total, bill in
            // 检查账单是否为不计入类型
            let billCategories = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            
            // 如果账单的所有类型都是不计入，则排除
            let isExcluded = !billCategories.isEmpty && billCategories.allSatisfy { $0.transactionType == .excluded }
            
            if isExcluded {
                return total
            }
            
            // 金额为负数表示支出，取绝对值
            if bill.amount < 0 {
                return total + abs(bill.amount)
            }
            return total
        }
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

/// 账单行视图
struct BillRowView: View {
    let bill: Bill
    let categories: [BillCategory]
    let owners: [Owner]
    let paymentMethods: [PaymentMethodWrapper]
    let onEdit: ((Bill) -> Void)?
    
    init(bill: Bill,
         categories: [BillCategory],
         owners: [Owner],
         paymentMethods: [PaymentMethodWrapper],
         onEdit: ((Bill) -> Void)? = nil) {
        self.bill = bill
        self.categories = categories
        self.owners = owners
        self.paymentMethods = paymentMethods
        self.onEdit = onEdit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：金额、时间和编辑按钮
            HStack(alignment: .center) {
                Text("¥\(bill.amount as NSDecimalNumber, formatter: amountFormatter)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(transactionColor)
                
                Spacer()
                
                Text(formattedDateTime)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if let onEdit = onEdit {
                    Button(action: { onEdit(bill) }) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 第二行：所有标签（归属人、支付方式、账单类型）
            let categoryList = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            
            FlowLayout(spacing: 6) {
                // 归属人标签
                if let owner = owners.first(where: { $0.id == bill.ownerId }) {
                    CompactTagView(text: owner.name, color: .green)
                }
                
                // 支付方式标签
                if let payment = paymentMethods.first(where: { $0.id == bill.paymentMethodId }) {
                    CompactTagView(text: displayPaymentMethodName(payment.name), color: .blue)
                }
                
                // 账单类型标签
                ForEach(categoryList) { category in
                    CompactTagView(text: category.name, color: .orange)
                }
            }
            
            // 备注（如果有）
            if let note = bill.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 格式化日期时间为 yyyy-MM-dd HH:mm:ss
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: bill.createdAt)
    }
    
    // 根据交易类型返回颜色
    private var transactionColor: Color {
        guard let payment = paymentMethods.first(where: { $0.id == bill.paymentMethodId }) else {
            return .primary
        }
        
        switch payment.transactionType {
        case .income:
            return .green
        case .expense:
            return .red
        case .excluded:
            return .gray
        }
    }
    
    private var amountFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
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
}

/// 标签视图组件
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

/// 紧凑标签视图组件（用于账单列表）
struct CompactTagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

/// 分享Sheet包装器
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 筛选标签视图（用于显示已选择的筛选条件）
struct FilterTagView: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(16)
    }
}

/// 可选择的筛选标签（用于筛选面板）
struct SelectableFilterTag: View {
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
                    Image(systemName: "checkmark.circle.fill")
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
                Text("筛选条件")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 归属人筛选
                    VStack(alignment: .leading, spacing: 12) {
                        Text("归属人")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(owners) { owner in
                                SelectableFilterTag(
                                    text: owner.name,
                                    isSelected: selectedOwnerIds.contains(owner.id),
                                    color: .green
                                ) {
                                    if selectedOwnerIds.contains(owner.id) {
                                        selectedOwnerIds.remove(owner.id)
                                        // 清空支付方式筛选
                                        selectedPaymentMethodIds.removeAll()
                                    } else {
                                        selectedOwnerIds.insert(owner.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 支付方式筛选（显示在归属人下面）
                        if !selectedOwnerIds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("支付方式")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(filteredPaymentMethods, id: \.id) { method in
                                        SelectableFilterTag(
                                            text: displayPaymentMethodName(method.name),
                                            isSelected: selectedPaymentMethodIds.contains(method.id),
                                            color: .blue
                                        ) {
                                            if selectedPaymentMethodIds.contains(method.id) {
                                                selectedPaymentMethodIds.remove(method.id)
                                            } else {
                                                selectedPaymentMethodIds.insert(method.id)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 账单类型筛选
                    VStack(alignment: .leading, spacing: 12) {
                        Text("账单类型")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(categories) { category in
                                SelectableFilterTag(
                                    text: category.name,
                                    isSelected: selectedCategoryIds.contains(category.id),
                                    color: .orange
                                ) {
                                    if selectedCategoryIds.contains(category.id) {
                                        selectedCategoryIds.remove(category.id)
                                    } else {
                                        selectedCategoryIds.insert(category.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // 日期范围筛选
                    VStack(alignment: .leading, spacing: 12) {
                        Text("日期范围")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
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
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $showingStartDatePicker) {
            DatePickerSheet(
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
            DatePickerSheet(
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// 日期选择器弹窗
struct DatePickerSheet: View {
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
                .onChange(of: selectedDate) { oldValue, newValue in
                    // 只有当日期真正改变时才关闭（排除初始化时的触发）
                    let calendar = Calendar.current
                    let oldDay = calendar.startOfDay(for: oldValue)
                    let newDay = calendar.startOfDay(for: newValue)
                    
                    if oldDay != newDay {
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
