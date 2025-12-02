import SwiftUI

/// 支付方式管理视图
struct PaymentMethodListView: View {
    @StateObject private var viewModel: PaymentMethodViewModel
    private let repository: DataRepository
    @State private var selectedTab: AccountType = .credit
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
    
    // 储蓄方式表单字段
    @State private var savingsName = ""
    @State private var savingsBalance = ""
    
    init(repository: DataRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: PaymentMethodViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab 选择器
            Picker("账户类型", selection: $selectedTab) {
                Text("信贷方式").tag(AccountType.credit)
                Text("储蓄方式").tag(AccountType.savings)
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if selectedTab == .credit {
                    ForEach(viewModel.creditMethods, id: \.id) { method in
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
                                showingEditCreditSheet = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ForEach(viewModel.savingsMethods, id: \.id) { method in
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
        }
    }
    private var addCreditMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $creditName)
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
              let date = Int(billingDate) else {
            showingError = true
            return
        }
        
        do {
            try await viewModel.createCreditMethod(
                name: creditName,
                transactionType: .expense,
                creditLimit: limit,
                outstandingBalance: balance,
                billingDate: date
            )
            resetCreditForm()
            showingAddCreditSheet = false
        } catch {
            showingError = true
        }
    }
    
    private func saveSavingsMethod() async {
        guard let balance = Decimal(string: savingsBalance) else {
            showingError = true
            return
        }
        
        do {
            try await viewModel.createSavingsMethod(
                name: savingsName,
                transactionType: .expense,
                balance: balance
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
    }
    
    private func resetSavingsForm() {
        savingsName = ""
        savingsBalance = ""
    }
    
    private var editCreditMethodSheet: some View {
        NavigationView {
            Form {
                TextField("名称", text: $creditName)
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
              let date = Int(billingDate) else {
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
                billingDate: date
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
              let balance = Decimal(string: savingsBalance) else {
            showingError = true
            return
        }
        
        do {
            let updatedMethod = SavingsMethod(
                id: method.id,
                name: savingsName,
                transactionType: .expense,
                balance: balance
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
