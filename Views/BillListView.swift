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
        Group {
            if billViewModel.bills.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "暂无账单",
                    message: "点击右上角的 + 按钮创建第一条账单记录"
                )
            } else {
                List {
                    ForEach(groupedBills.keys.sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedBills[date] ?? []) { bill in
                                BillRowView(
                                    bill: bill,
                                    categories: categoryViewModel.categories,
                                    owners: ownerViewModel.owners,
                                    paymentMethods: paymentViewModel.paymentMethods
                                )
                            }
                            .onDelete { offsets in
                                deleteBillsInSection(date: date, at: offsets)
                            }
                        } header: {
                            DailySummaryHeader(
                                date: date,
                                bills: groupedBills[date] ?? [],
                                paymentMethods: paymentViewModel.paymentMethods
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("账单列表")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    exportBills()
                } label: {
                    if exportViewModel.isExporting {
                        ProgressView()
                    } else {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(billViewModel.bills.isEmpty || exportViewModel.isExporting)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
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
        .task {
            await loadData()
        }
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
            guard let paymentMethod = paymentMethods.first(where: { $0.id == bill.paymentMethodId }),
                  paymentMethod.transactionType == .income else {
                return total
            }
            return total + bill.amount
        }
    }
    
    private var dailyExpense: Decimal {
        bills.reduce(0) { total, bill in
            guard let paymentMethod = paymentMethods.first(where: { $0.id == bill.paymentMethodId }),
                  paymentMethod.transactionType == .expense else {
                return total
            }
            return total + bill.amount
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 金额和时间
            HStack {
                Text("¥\(bill.amount as NSDecimalNumber, formatter: amountFormatter)")
                    .font(.headline)
                    .foregroundColor(transactionColor)
                Spacer()
                Text(formattedDateTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 归属人
            if let owner = owners.first(where: { $0.id == bill.ownerId }) {
                HStack(spacing: 4) {
                    Text("归属人:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(owner.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            // 支付方式标签
            if let payment = paymentMethods.first(where: { $0.id == bill.paymentMethodId }) {
                HStack(spacing: 4) {
                    Text("支付方式:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TagView(text: payment.name, color: .blue)
                }
            }
            
            // 账单类型标签
            let categoryList = bill.categoryIds.compactMap { id in
                categories.first(where: { $0.id == id })
            }
            
            if !categoryList.isEmpty {
                HStack(spacing: 4) {
                    Text("类型:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(categoryList) { category in
                                TagView(text: category.name, color: .orange)
                            }
                        }
                    }
                }
            }
            
            // 备注
            if let note = bill.note, !note.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("备注:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 4)
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
