import SwiftUI

/// 账单类型管理视图
struct CategoryManagementView: View {
    @StateObject private var viewModel: CategoryViewModel
    @State private var selectedTab: TransactionType = .expense
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingCategory: BillCategory?
    @State private var newCategoryName = ""
    @State private var newTransactionType: TransactionType = .expense
    @State private var showingError = false
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: CategoryViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab 选择器
            Picker("交易类型", selection: $selectedTab) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
                Text("不计入").tag(TransactionType.excluded)
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                ForEach(filteredCategories) { category in
                    HStack {
                        Text(category.name)
                            .font(.body)
                        Spacer()
                        Button("编辑") {
                            editingCategory = category
                            newCategoryName = category.name
                            newTransactionType = category.transactionType
                            showingEditSheet = true
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            }
            .environment(\.editMode, .constant(.active))
        }
        .navigationTitle("账单类型")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    newTransactionType = selectedTab
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addCategorySheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editCategorySheet
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadCategories()
        }
    }
    
    private var addCategorySheet: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("类型名称", text: $newCategoryName)
                    
                    Picker("交易类型", selection: $newTransactionType) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                        Text("不计入").tag(TransactionType.excluded)
                    }
                }
            }
            .navigationTitle("添加类型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        newCategoryName = ""
                        newTransactionType = .expense
                        showingAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            do {
                                try await viewModel.createCategory(name: newCategoryName, transactionType: newTransactionType)
                                newCategoryName = ""
                                newTransactionType = .expense
                                showingAddSheet = false
                            } catch {
                                showingError = true
                            }
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var editCategorySheet: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("类型名称", text: $newCategoryName)
                    
                    Picker("交易类型", selection: $newTransactionType) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                        Text("不计入").tag(TransactionType.excluded)
                    }
                }
            }
            .navigationTitle("编辑类型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        newCategoryName = ""
                        newTransactionType = .expense
                        editingCategory = nil
                        showingEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if let category = editingCategory {
                                do {
                                    try await viewModel.updateCategory(category, newName: newCategoryName, newTransactionType: newTransactionType)
                                    newCategoryName = ""
                                    newTransactionType = .expense
                                    editingCategory = nil
                                    showingEditSheet = false
                                } catch {
                                    showingError = true
                                }
                            }
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // 根据选中的Tab过滤类型并按sortOrder排序
    private var filteredCategories: [BillCategory] {
        viewModel.categories
            .filter { $0.transactionType == selectedTab }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let category = filteredCategories[index]
                do {
                    try await viewModel.deleteCategory(category)
                } catch {
                    showingError = true
                }
            }
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        viewModel.moveCategories(from: source, to: destination, transactionType: selectedTab)
    }
    
    private func transactionTypeText(_ type: TransactionType) -> String {
        switch type {
        case .expense:
            return "支出"
        case .income:
            return "收入"
        case .excluded:
            return "不计入"
        }
    }
    
    private func transactionTypeColor(_ type: TransactionType) -> Color {
        switch type {
        case .expense:
            return .red
        case .income:
            return .green
        case .excluded:
            return .gray
        }
    }
}
