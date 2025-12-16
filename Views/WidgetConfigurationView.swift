import SwiftUI

/// 小组件配置界面
struct WidgetConfigurationView: View {
    @StateObject private var widgetManager = WidgetManager.shared
    @State private var selectedItems: [QuickExpenseItem] = []
    @State private var showingItemPicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("在主屏幕添加小组件，快速记录常用支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("小组件说明")
                }
                
                Section {
                    ForEach(selectedItems.indices, id: \.self) { index in
                        QuickExpenseItemRow(
                            item: selectedItems[index],
                            onTap: {
                                Task {
                                    await testQuickExpense(selectedItems[index])
                                }
                            }
                        )
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)
                    
                    if selectedItems.count < 6 {
                        Button {
                            showingItemPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text("添加快速记账项目")
                            }
                        }
                    }
                } header: {
                    Text("小组件项目 (最多6个)")
                } footer: {
                    Text("点击项目可以测试快速记账功能")
                        .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用说明：")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("1.")
                                    .fontWeight(.medium)
                                Text("长按主屏幕空白处进入编辑模式")
                            }
                            
                            HStack {
                                Text("2.")
                                    .fontWeight(.medium)
                                Text("点击左上角的 + 号")
                            }
                            
                            HStack {
                                Text("3.")
                                    .fontWeight(.medium)
                                Text("搜索"标签记账"并添加小组件")
                            }
                            
                            HStack {
                                Text("4.")
                                    .fontWeight(.medium)
                                Text("选择合适的小组件尺寸")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("添加小组件到主屏幕")
                }
            }
            .navigationTitle("小组件配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingItemPicker) {
            QuickExpenseItemPicker(selectedItems: $selectedItems)
        }
        .onAppear {
            selectedItems = widgetManager.configuration.selectedItems
        }
        .onChange(of: selectedItems) { newItems in
            let newConfig = WidgetConfiguration(
                selectedItems: newItems,
                maxItems: 6
            )
            widgetManager.updateConfiguration(newConfig)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        selectedItems.remove(atOffsets: offsets)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        selectedItems.move(fromOffsets: source, toOffset: destination)
    }
    
    private func testQuickExpense(_ item: QuickExpenseItem) async {
        let success = await widgetManager.quickExpense(item)
        
        // 这里可以添加成功/失败的提示
        if success {
            print("✅ 测试记账成功：\(item.title)")
        } else {
            print("❌ 测试记账失败：\(item.title)")
        }
    }
}

/// 快速记账项目行
struct QuickExpenseItemRow: View {
    let item: QuickExpenseItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(Color.fromName(item.color))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("¥\(item.amount, specifier: "%.0f")")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 快速记账项目选择器
struct QuickExpenseItemPicker: View {
    @Binding var selectedItems: [QuickExpenseItem]
    @Environment(\.dismiss) private var dismiss
    
    var availableItems: [QuickExpenseItem] {
        QuickExpenseItem.defaultItems.filter { item in
            !selectedItems.contains { $0.title == item.title }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableItems) { item in
                    Button {
                        selectedItems.append(item)
                        dismiss()
                    } label: {
                        QuickExpenseItemRow(item: item) {}
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("选择记账项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WidgetConfigurationView()
}