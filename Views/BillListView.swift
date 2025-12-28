import SwiftUI

/// 账单列表视图
struct BillListView: View {
    @StateObject private var billViewModel: BillViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    @StateObject private var ownerViewModel: OwnerViewModel
    @StateObject private var paymentViewModel: PaymentMethodViewModel
    @StateObject private var exportViewModel: ExportViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showingAddSheet = false
    @State private var showingError = false
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingFilterSheet = false
    @State private var isFilterExpanded = true
    @State private var showScrollToTopButton = false
    @State private var editingBill: Bill?
    @State private var showingUpgradePrompt = false
    @State private var upgradePromptFeature = ""
    @State private var showingExportConfirmation = false
    
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
    
    // 悬浮按钮位置
    @State private var floatingButtonPosition: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.height - 200)
    @State private var isDragging = false
    
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
        ZStack {
            VStack(spacing: 0) {
                // 账单限制警告
                if let warning = subscriptionManager.getBillLimitWarning(currentBillCount: billViewModel.bills.count) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("升级") {
                        upgradePromptFeature = "unlimited_bills"
                        showingUpgradePrompt = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            
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
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
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
                                                print("🔴 UI: 开始删除账单 \(bill.id)")
                                                try await billViewModel.deleteBill(bill)
                                                print("✅ UI: 删除成功，重新加载数据")
                                                
                                                // 清除缓存
                                                clearCache()
                                                
                                                // 重新加载所有数据
                                                await loadData()
                                                
                                                print("✅ UI: 数据重载完成，当前账单数: \(billViewModel.bills.count)")
                                            } catch {
                                                print("❌ UI: 删除失败: \(error)")
                                                billViewModel.errorMessage = "删除失败: \(error.localizedDescription)"
                                                showingError = true
                                            }
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
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
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("导出")
                                        .font(.headline)
                                    if hasActiveFilters {
                                        Text("\(filteredBills.count)条")
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(billViewModel.bills.isEmpty || exportViewModel.isExporting)
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
        .alert("确认导出", isPresented: $showingExportConfirmation) {
            Button("取消", role: .cancel) {}
            Button("导出") {
                performExport()
            }
        } message: {
            Text(exportConfirmationMessage)
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
            .iOS16PresentationLargeCompat()
        }
            
            // 悬浮添加按钮
            FloatingAddButton(
                position: $floatingButtonPosition,
                isDragging: $isDragging
            ) {
                showingAddSheet = true
            }
        } // ZStack 结束
        .task {
            await loadData()
        }
        .upgradePrompt(
            isPresented: $showingUpgradePrompt,
            title: upgradePromptTitle,
            message: upgradePromptMessage,
            feature: upgradePromptFeature
        )
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
        
        // 按账单类型筛选（AND逻辑：账单必须包含所有选中的类型）
        if !selectedCategoryIds.isEmpty {
            bills = bills.filter { bill in
                selectedCategoryIds.isSubset(of: Set(bill.categoryIds))
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
        // 检查导出权限
        if !subscriptionManager.canExportData {
            upgradePromptFeature = "export"
            showingUpgradePrompt = true
            return
        }
        
        // 显示确认对话框
        showingExportConfirmation = true
    }
    
    private func performExport() {
        Task {
            do {
                // 使用筛选后的账单进行导出
                let billsToExport = hasActiveFilters ? filteredBills : billViewModel.bills
                
                print("📤 导出账单: 总数=\(billViewModel.bills.count), 筛选后=\(billsToExport.count)")
                if hasActiveFilters {
                    print("  筛选条件:")
                    if !selectedOwnerIds.isEmpty {
                        print("  - 归属人: \(selectedOwnerIds.count) 个")
                    }
                    if !selectedCategoryIds.isEmpty {
                        print("  - 账单类型: \(selectedCategoryIds.count) 个")
                    }
                    if !selectedPaymentMethodIds.isEmpty {
                        print("  - 支付方式: \(selectedPaymentMethodIds.count) 个")
                    }
                    if startDate != nil || endDate != nil {
                        print("  - 日期范围: \(startDate != nil ? "有开始日期" : "") \(endDate != nil ? "有结束日期" : "")")
                    }
                }
                
                let fileURL = try await exportViewModel.exportToCSV(
                    bills: billsToExport,
                    categories: categoryViewModel.categories,
                    owners: ownerViewModel.owners,
                    paymentMethods: paymentViewModel.paymentMethods
                )
                exportedFileURL = fileURL
                showingExportSheet = true
                
                print("✅ 导出成功: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ 导出失败: \(error)")
                showingError = true
            }
        }
    }
    
    private var exportConfirmationMessage: String {
        let billsToExport = hasActiveFilters ? filteredBills : billViewModel.bills
        let count = billsToExport.count
        
        if hasActiveFilters {
            var conditions: [String] = []
            
            if !selectedOwnerIds.isEmpty {
                let names = selectedOwnerIds.compactMap { id in
                    ownerViewModel.owners.first(where: { $0.id == id })?.name
                }.joined(separator: "、")
                conditions.append("归属人: \(names)")
            }
            
            if !selectedCategoryIds.isEmpty {
                let names = selectedCategoryIds.compactMap { id in
                    categoryViewModel.categories.first(where: { $0.id == id })?.name
                }.joined(separator: "、")
                conditions.append("类型: \(names)")
            }
            
            if !selectedPaymentMethodIds.isEmpty {
                let count = selectedPaymentMethodIds.count
                conditions.append("支付方式: \(count)个")
            }
            
            if let start = startDate, let end = endDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                conditions.append("日期: \(formatter.string(from: start))~\(formatter.string(from: end))")
            } else if let start = startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                conditions.append("日期: \(formatter.string(from: start))起")
            } else if let end = endDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                conditions.append("日期: 至\(formatter.string(from: end))")
            }
            
            let conditionText = conditions.joined(separator: "\n")
            return "将导出符合以下条件的 \(count) 条账单：\n\n\(conditionText)"
        } else {
            return "将导出全部 \(count) 条账单"
        }
    }
    
    private var upgradePromptTitle: String {
        switch upgradePromptFeature {
        case "unlimited_bills":
            return "已达到账单上限"
        case "export":
            return "Pro 功能"
        default:
            return "升级到 Pro"
        }
    }
    
    private var upgradePromptMessage: String {
        switch upgradePromptFeature {
        case "unlimited_bills":
            return "免费版最多支持 500 条账单记录\n升级到 Pro 版解锁无限账单"
        case "export":
            return "数据导出功能仅限 Pro 用户使用\n升级解锁 CSV 和数据库导出"
        default:
            return "升级到 Pro 版解锁所有高级功能"
        }
    }
    
    private func deleteBillsInSection(date: String, at offsets: IndexSet) {
        guard let bills = groupedBills[date] else { return }
        
        Task {
            for index in offsets {
                let bill = bills[index]
                do {
                    print("🔴 UI: 批量删除账单 \(bill.id)")
                    try await billViewModel.deleteBill(bill)
                } catch {
                    print("❌ UI: 批量删除失败: \(error)")
                    billViewModel.errorMessage = "删除失败: \(error.localizedDescription)"
                    showingError = true
                }
            }
            
            // 删除完成后重新加载数据
            clearCache()
            await loadData()
        }
    }
}

/// 每日汇总头部视图（紧凑版）
struct DailySummaryHeader: View {
    let date: String
    let bills: [Bill]
    let paymentMethods: [PaymentMethodWrapper]
    let categories: [BillCategory]
    
    var body: some View {
        HStack(spacing: 12) {
            Text(date)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("¥\(dailyIncome as NSDecimalNumber, formatter: numberFormatter)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("¥\(dailyExpense as NSDecimalNumber, formatter: numberFormatter)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 2)
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
        HStack(spacing: 0) {
            // 左侧彩色指示条
            Rectangle()
                .fill(transactionTypeGradient)
                .frame(width: 3)
            
            // 主内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：类型图标 + 金额 + 时间 + 编辑
                HStack(alignment: .center, spacing: 6) {
                    // 类型图标（更小）
                    Image(systemName: transactionTypeIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(transactionColor)
                        .frame(width: 20, height: 20)
                        .background(transactionColor.opacity(0.12))
                        .cornerRadius(4)
                    
                    // 金额（单行显示，包含类型标签）
                    HStack(spacing: 4) {
                        Text(transactionTypeLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(transactionColor.opacity(0.7))
                        
                        Text("¥\(formattedAmount)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(transactionColor)
                    }
                    
                    Spacer()
                    
                    // 时间
                    Text(formattedDateTime)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // 编辑按钮（仅图标）
                    if let onEdit = onEdit {
                        Button(action: { onEdit(bill) }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 第二行：标签（更紧凑）
                let categoryList = bill.categoryIds.compactMap { id in
                    categories.first(where: { $0.id == id })
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                    // 归属人标签
                    if let owner = owners.first(where: { $0.id == bill.ownerId }) {
                        CompactTagView(
                            icon: "person.fill",
                            text: owner.name,
                            color: .green,
                            style: transactionType == .excluded ? .muted : .normal
                        )
                    }
                    
                    // 支付方式标签
                    if let payment = paymentMethods.first(where: { $0.id == bill.paymentMethodId }) {
                        CompactTagView(
                            icon: payment.accountType == .credit ? "creditcard.fill" : "banknote.fill",
                            text: displayPaymentMethodName(payment.name),
                            color: .blue,
                            style: transactionType == .excluded ? .muted : .normal
                        )
                    }
                    
                    // 账单类型标签
                    ForEach(categoryList) { category in
                        CompactTagView(
                            icon: "tag.fill",
                            text: category.name,
                            color: .orange,
                            style: transactionType == .excluded ? .muted : .normal
                        )
                    }
                }
                
                // 备注（如果有，更紧凑）
                if let note = bill.note, !note.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "note.text")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
        }
        .background(transactionBackgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(transactionBorderColor, lineWidth: transactionType == .excluded ? 1 : 0)
        )
    }
    
    // 获取交易类型
    private var transactionType: TransactionType {
        // 检查账单的所有类型
        let categoryList = bill.categoryIds.compactMap { id in
            categories.first(where: { $0.id == id })
        }
        
        // 如果所有类型都是不计入，则为不计入类型
        if !categoryList.isEmpty && categoryList.allSatisfy({ $0.transactionType == .excluded }) {
            return .excluded
        }
        
        // 根据金额判断收入/支出
        return bill.amount > 0 ? .income : .expense
    }
    
    // 交易类型标签
    private var transactionTypeLabel: String {
        switch transactionType {
        case .income:
            return "收入"
        case .expense:
            return "支出"
        case .excluded:
            return "不计入"
        }
    }
    
    // 交易类型图标
    private var transactionTypeIcon: String {
        switch transactionType {
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        case .excluded:
            return "minus.circle.fill"
        }
    }
    
    // 交易类型颜色
    private var transactionColor: Color {
        switch transactionType {
        case .income:
            return .green
        case .expense:
            return .red
        case .excluded:
            return .gray
        }
    }
    
    // 交易类型渐变色（左侧指示条）
    private var transactionTypeGradient: LinearGradient {
        switch transactionType {
        case .income:
            return LinearGradient(
                colors: [Color.green.opacity(0.8), Color.green],
                startPoint: .top,
                endPoint: .bottom
            )
        case .expense:
            return LinearGradient(
                colors: [Color.red.opacity(0.8), Color.red],
                startPoint: .top,
                endPoint: .bottom
            )
        case .excluded:
            return LinearGradient(
                colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // 背景颜色
    private var transactionBackgroundColor: Color {
        switch transactionType {
        case .income:
            return Color.green.opacity(0.05)
        case .expense:
            return Color.red.opacity(0.05)
        case .excluded:
            return Color.gray.opacity(0.03)
        }
    }
    
    // 边框颜色
    private var transactionBorderColor: Color {
        switch transactionType {
        case .income:
            return .clear
        case .expense:
            return .clear
        case .excluded:
            return Color.gray.opacity(0.3)
        }
    }
    
    // 格式化金额（显示绝对值）
    private var formattedAmount: String {
        let absAmount = abs(bill.amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: absAmount as NSDecimalNumber) ?? "0.00"
    }
    
    // 格式化日期时间
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: bill.createdAt)
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
        if let dashIndex = name.firstIndex(of: "-") {
            let startIndex = name.index(after: dashIndex)
            return String(name[startIndex...])
        }
        return name
    }
}

/// 紧凑标签视图（带图标）
struct CompactTagView: View {
    let icon: String
    let text: String
    let color: Color
    var style: TagStyle = .normal
    
    enum TagStyle {
        case normal
        case muted
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: style == .muted ? 0.5 : 0)
        )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .normal:
            return color.opacity(0.15)
        case .muted:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .normal:
            return color
        case .muted:
            return color.opacity(0.6)
        }
    }
    
    private var borderColor: Color {
        color.opacity(0.3)
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
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
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
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
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
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
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
                .onChange(of: selectedDate) { newValue in
                    // 只有当日期真正改变时才关闭（排除初始化时的触发）
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


/// 悬浮添加按钮组件
struct FloatingAddButton: View {
    @Binding var position: CGPoint
    @Binding var isDragging: Bool
    let action: () -> Void
    
    // 按钮大小
    private let buttonSize: CGFloat = 56
    // 安全边距
    private let edgePadding: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            Button(action: {
                // 只有在非拖动状态下才触发点击
                if !isDragging {
                    action()
                }
            }) {
                ZStack {
                    // 阴影背景
                    Circle()
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    // 图标
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: buttonSize, height: buttonSize)
            }
            .position(constrainedPosition(in: geometry))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        position = value.location
                    }
                    .onEnded { value in
                        // 延迟重置拖动状态，避免触发点击
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                        // 吸附到边缘
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            position = snapToEdge(position: value.location, in: geometry)
                        }
                    }
            )
            .onAppear {
                // 初始化位置：右下角
                let safeArea = geometry.safeAreaInsets
                position = CGPoint(
                    x: geometry.size.width - buttonSize/2 - edgePadding,
                    y: geometry.size.height - buttonSize/2 - edgePadding - safeArea.bottom - 60
                )
            }
        }
    }
    
    /// 限制按钮位置在安全区域内
    private func constrainedPosition(in geometry: GeometryProxy) -> CGPoint {
        let safeArea = geometry.safeAreaInsets
        let minX = buttonSize/2 + edgePadding
        let maxX = geometry.size.width - buttonSize/2 - edgePadding
        let minY = buttonSize/2 + edgePadding + safeArea.top
        let maxY = geometry.size.height - buttonSize/2 - edgePadding - safeArea.bottom
        
        return CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )
    }
    
    /// 吸附到最近的边缘
    private func snapToEdge(position: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        let safeArea = geometry.safeAreaInsets
        let minX = buttonSize/2 + edgePadding
        let maxX = geometry.size.width - buttonSize/2 - edgePadding
        let minY = buttonSize/2 + edgePadding + safeArea.top
        let maxY = geometry.size.height - buttonSize/2 - edgePadding - safeArea.bottom
        
        // 限制 Y 坐标
        let constrainedY = min(max(position.y, minY), maxY)
        
        // 判断靠近左边还是右边
        let centerX = geometry.size.width / 2
        let snapX = position.x < centerX ? minX : maxX
        
        return CGPoint(x: snapX, y: constrainedY)
    }
}
