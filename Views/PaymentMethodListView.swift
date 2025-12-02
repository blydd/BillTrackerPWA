import SwiftUI

/// 支付方式管理视图
struct PaymentMethodListView: View {
    @StateObject private var viewModel: PaymentMethodViewModel
    @StateObject private var ownerViewModel: OwnerViewModel
    private let repository: DataRepository
    @State private var selectedTab: AccountType = .credit
    @State private var selectedOwnerIdForFilter: UUID?
    @State private var showingAddCreditSheet = false
    @State private var showingAddSavingsSheet = false
    @State private var showingEditCreditSheet = false
    @State private var showingEditSavingsSheet = false
    @State private var showingError = false
    
    // 编辑中的支付方式
    @State private var editingCreditMethod: CreditMethod?
    @State private var editingSavingsMethod: SavingsMethod?
    
    // 信贷方式表单字段
    @State private var creditName = ""
    @State private var creditLimit = ""
    @State private var outstandingBalance = ""
    @State private var billingDate = ""
    @State private var selectedOwnerId: UUID?
    
    // 储蓄方式表单字段
    @State private var savingsName = ""
    @State private var savingsBalance = ""
    
    init(repository: DataRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: PaymentMethodViewModel(repository: repository))
        _ownerViewModel = StateObject(wrappedValue: OwnerViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 一级Tab：账户类型选择器
            Picker("账户类型", selection: $selectedTab) {
                Text("信贷方式").tag(AccountType.credit)
                Text("储蓄方式").tag(AccountType.savings)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            
            // 二级Tab：归属人选择器
            if !ownerViewModel.owners.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ownerViewModel.owners) { owner in
                            Button(action: {
                                selectedOwnerIdForFilter = owner.id
                            }) {
                                Text(owner.name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedOwnerIdForFilter == owner.id ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedOwnerIdForFilter == owner.id ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            
            List {
                if selectedTab == .credit {
                    ForEach(filteredCreditMethods, id: \.id) { method in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.name)
                                    .font(.headline)
                                
                                HStack {
                                    Text("额度: ¥\(method.creditLimit as NSDecimalNumber, formatter: numberFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text("欠费: ¥\(method.outstandingBalance as NSDecimalNumber, formatter: numberFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("可用: ¥\((method.creditLimit - method.outstandingBalance) as NSDecimalNumber, formatter: numberFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Button("编辑") {
                                editingCreditMethod = method
                                creditName = method.name
                                creditLimit = String(describing: method.creditLimit)
                                outstandingBalance = String(describing: method.outstandingBalance)
                                billingDate = String(method.billingDate)
                                selectedOwnerId = method.ownerId
                                showingEditCreditSheet = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ForEach(filteredSavingsMethods, id: \.id) { method in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.name)
                                    .font(.headline)
                                Text("余额: ¥\(method.balance as NSDecimalNumber, formatter: numberFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("编辑") {
                                editingSavingsMethod = method
                                savingsName = method.name
                                savingsBalance = String(describing: method.balance)
                                selectedOwnerId = method.ownerId
                                showingEditSavingsSheet = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("支付方式")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if selectedTab == .credit {
                        showingAddCreditSheet = true
                    } else {
                        showingAddSavingsSheet = true
                    }
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCreditSheet) {
            addCreditMethodSheet
        }
        .sheet(isPresented: $showingAddSavingsSheet) {
            addSavingsMethodSheet
        }
        .sheet(isPresented: $showingEditCreditSheet) {
            editCreditMethodSheet
        }
        .sheet(isPresented: $showingEditSavingsSheet) {
            editSavingsMethodSheet
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadPaymentMethods()
            await ownerViewModel.loadOwners()
            // 默认选择第一个归属人
            if selectedOwnerIdForFilter == nil {
                selectedOwnerIdForFilter = ownerViewModel.owners.first?.id
            }
        }
    }
    
    // 根据选择的归属人过滤信贷方式
    private var filteredCreditMethods: [CreditMethod] {
        guard let ownerId = selectedOwnerIdForFilter else {
            return viewModel.creditMethods
        }
        return viewModel.creditMethods.filter { $0.ownerId == ownerId }
    }
    
    // 根据选择的归属人过滤储蓄方式
    private var filteredSavingsMethods: [SavingsMethod] {
        guard let ownerId = selectedOwnerIdForFilter else {
            return viewModel.savingsMethods
        }
        return viewModel.savingsMethods.filter { $0.ownerId == ownerId }
    }
    private var addCreditMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $creditName)
                
                Picker("归属人", selection: $selectedOwnerId) {
                    Text("请选择").tag(nil as UUID?)
                    ForEach(ownerViewModel.owners) { owner in
                        Text(owner.name).tag(owner.id as UUID?)
                    }
                }
                
                TextField("信用额度", text: $creditLimit)
                    .keyboardType(.decimalPad)
                TextField("初始欠费", text: $outstandingBalance)
                    .keyboardType(.decimalPad)
                TextField("账单日", text: $billingDate)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("添加信贷方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetCreditForm()
                        showingAddCreditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveCreditMethod()
                        }
                    }
                }
            }
        }
    }
    private var addSavingsMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $savingsName)
                
                Picker("归属人", selection: $selectedOwnerId) {
                    Text("请选择").tag(nil as UUID?)
                    ForEach(ownerViewModel.owners) { owner in
                        Text(owner.name).tag(owner.id as UUID?)
                    }
                }
                
                TextField("初始余额", text: $savingsBalance)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("添加储蓄方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetSavingsForm()
                        showingAddSavingsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveSavingsMethod()
                        }
                    }
                }
            }
        }
    }
    
    private func saveCreditMethod() async {
        guard let limit = Decimal(string: creditLimit),
              let balance = Decimal(string: outstandingBalance),
              let date = Int(billingDate),
              let ownerId = selectedOwnerId else {
            showingError = true
            return
        }
        
        do {
            try await viewModel.createCreditMethod(
                name: creditName,
                transactionType: .expense,
                creditLimit: limit,
                outstandingBalance: balance,
                billingDate: date,
                ownerId: ownerId
            )
            resetCreditForm()
            showingAddCreditSheet = false
        } catch {
            showingError = true
        }
    }
    
    private func saveSavingsMethod() async {
        guard let balance = Decimal(string: savingsBalance),
              let ownerId = selectedOwnerId else {
            showingError = true
            return
        }
        
        do {
            try await viewModel.createSavingsMethod(
                name: savingsName,
                transactionType: .expense,
                balance: balance,
                ownerId: ownerId
            )
            resetSavingsForm()
            showingAddSavingsSheet = false
        } catch {
            showingError = true
        }
    }
    
    private func resetCreditForm() {
        creditName = ""
        creditLimit = ""
        outstandingBalance = ""
        billingDate = ""
        selectedOwnerId = nil
    }
    
    private func resetSavingsForm() {
        savingsName = ""
        savingsBalance = ""
        selectedOwnerId = nil
    }
    
    private var editCreditMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $creditName)
                
                Picker("归属人", selection: $selectedOwnerId) {
                    Text("请选择").tag(nil as UUID?)
                    ForEach(ownerViewModel.owners) { owner in
                        Text(owner.name).tag(owner.id as UUID?)
                    }
                }
                
                TextField("信用额度", text: $creditLimit)
                    .keyboardType(.decimalPad)
                TextField("当前欠费", text: $outstandingBalance)
                    .keyboardType(.decimalPad)
                TextField("账单日", text: $billingDate)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("编辑信贷方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetCreditForm()
                        editingCreditMethod = nil
                        showingEditCreditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await updateCreditMethod()
                        }
                    }
                }
            }
        }
    }
    
    private var editSavingsMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $savingsName)
                
                Picker("归属人", selection: $selectedOwnerId) {
                    Text("请选择").tag(nil as UUID?)
                    ForEach(ownerViewModel.owners) { owner in
                        Text(owner.name).tag(owner.id as UUID?)
                    }
                }
                
                TextField("当前余额", text: $savingsBalance)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("编辑储蓄方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetSavingsForm()
                        editingSavingsMethod = nil
                        showingEditSavingsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await updateSavingsMethod()
                        }
                    }
                }
            }
        }
    }
    
    private func updateCreditMethod() async {
        guard let method = editingCreditMethod,
              let limit = Decimal(string: creditLimit),
              let balance = Decimal(string: outstandingBalance),
              let date = Int(billingDate),
              let ownerId = selectedOwnerId else {
            showingError = true
            return
        }
        
        do {
            // 先更新欠费金额（通过repository直接更新）
            let updatedMethod = CreditMethod(
                id: method.id,
                name: creditName,
                transactionType: .expense,
                creditLimit: limit,
                outstandingBalance: balance,
                billingDate: date,
                ownerId: ownerId
            )
            try await repository.updatePaymentMethod(.credit(updatedMethod))
            
            // 重新加载数据
            await viewModel.loadPaymentMethods()
            
            resetCreditForm()
            editingCreditMethod = nil
            showingEditCreditSheet = false
        } catch {
            showingError = true
        }
    }
    
    private func updateSavingsMethod() async {
        guard let method = editingSavingsMethod,
              let balance = Decimal(string: savingsBalance),
              let ownerId = selectedOwnerId else {
            showingError = true
            return
        }
        
        do {
            let updatedMethod = SavingsMethod(
                id: method.id,
                name: savingsName,
                transactionType: .expense,
                balance: balance,
                ownerId: ownerId
            )
            try await repository.updatePaymentMethod(.savings(updatedMethod))
            
            // 重新加载数据
            await viewModel.loadPaymentMethods()
            
            resetSavingsForm()
            editingSavingsMethod = nil
            showingEditSavingsSheet = false
        } catch {
            showingError = true
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
