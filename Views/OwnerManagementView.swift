import SwiftUI

/// 归属人管理视图
struct OwnerManagementView: View {
    @StateObject private var viewModel: OwnerViewModel
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var editingOwner: Owner?
    @State private var newOwnerName = ""
    @State private var showingError = false
    @State private var errorTitle = "错误"
    
    init(repository: DataRepository) {
        _viewModel = StateObject(wrappedValue: OwnerViewModel(repository: repository))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.owners) { owner in
                HStack {
                    Text(owner.name)
                    Spacer()
                    Button("编辑") {
                        editingOwner = owner
                        newOwnerName = owner.name
                        showingEditSheet = true
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onDelete(perform: deleteOwners)
        }
        .navigationTitle("归属人")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addOwnerSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editOwnerSheet
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadOwners()
        }
    }
    
    private var addOwnerSheet: some View {
        NavigationView {
            Form {
                TextField("归属人名称", text: $newOwnerName)
            }
            .navigationTitle("添加归属人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        newOwnerName = ""
                        showingAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            do {
                                try await viewModel.createOwner(name: newOwnerName)
                                newOwnerName = ""
                                showingAddSheet = false
                            } catch {
                                showingError = true
                            }
                        }
                    }
                    .disabled(newOwnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var editOwnerSheet: some View {
        NavigationView {
            Form {
                TextField("归属人名称", text: $newOwnerName)
            }
            .navigationTitle("编辑归属人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        newOwnerName = ""
                        editingOwner = nil
                        showingEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if let owner = editingOwner {
                                do {
                                    try await viewModel.updateOwner(owner, newName: newOwnerName)
                                    newOwnerName = ""
                                    editingOwner = nil
                                    showingEditSheet = false
                                } catch {
                                    showingError = true
                                }
                            }
                        }
                    }
                    .disabled(newOwnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func deleteOwners(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let owner = viewModel.owners[index]
                do {
                    try await viewModel.deleteOwner(owner)
                } catch {
                    errorTitle = "无法删除"
                    viewModel.errorMessage = "该归属人仍被账单使用，无法删除"
                    showingError = true
                }
            }
        }
    }
}
