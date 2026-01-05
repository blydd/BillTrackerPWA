import SwiftUI

/// 统计详情账单列表视图
/// 用于显示统计分析页面点击某个维度后的账单列表
struct StatisticsBillListView: View {
    let title: String
    let bills: [Bill]
    let repository: DataRepository
    let onDismiss: () -> Void
    let onDataChanged: () -> Void
    
    @StateObject private var categoryViewModel: CategoryViewModel
    @StateObject private var ownerViewModel: OwnerViewModel
    @StateObject private var paymentViewModel: PaymentMethodViewModel
    @StateObject private var billViewModel: BillViewModel
    
    @State private var editingBill: Bill?
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var localBills: [Bill] = []
    @State private var isLoading = true  // 加载状态
    
    init(title: String, bills: [Bill], repository: DataRepository, onDismiss: @escaping () -> Void, onDataChanged: @escaping () -> Void) {
        self.title = title
        self.bills = bills
        self.repository = repository
        self.onDismiss = onDismiss
        self.onDataChanged = onDataChanged
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(repository: repository))
        _ownerViewModel = StateObject(wrappedValue: OwnerViewModel(repository: repository))
        _paymentViewModel = StateObject(wrappedValue: PaymentMethodViewModel(repository: repository))
        _billViewModel = StateObject(wrappedValue: BillViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    // 加载中状态
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("加载中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if localBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无账单")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(groupedBills.keys.sorted(by: >), id: \.self) { date in
                            Section {
                                ForEach(groupedBills[date] ?? []) { bill in
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
                                            deleteBill(bill)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                                }
                            } header: {
                                Text(date)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(localBills.count)条")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    // 编辑完成后刷新
                    Task {
                        await refreshData()
                    }
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                // 每次视图出现时重新加载数据
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // 按日期分组账单
    private var groupedBills: [String: [Bill]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var grouped: [String: [Bill]] = [:]
        
        for bill in localBills {
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
        isLoading = true
        // 先设置账单数据
        localBills = bills
        // 再加载关联数据
        await categoryViewModel.loadCategories()
        await ownerViewModel.loadOwners()
        await paymentViewModel.loadPaymentMethods()
        isLoading = false
    }
    
    private func refreshData() async {
        await billViewModel.loadBills()
        // 根据原始账单ID过滤出仍然存在的账单
        let originalIds = Set(bills.map { $0.id })
        localBills = billViewModel.bills.filter { originalIds.contains($0.id) }
        onDataChanged()
    }
    
    private func deleteBill(_ bill: Bill) {
        Task {
            do {
                try await billViewModel.deleteBill(bill)
                // 从本地列表移除
                localBills.removeAll { $0.id == bill.id }
                onDataChanged()
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}
