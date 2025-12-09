import SwiftUI

/// 云同步设置视图
struct CloudSyncSettingsView: View {
    @EnvironmentObject var syncManager: AutoSyncManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingError = false
    @State private var showingPurchase = false
    
    var body: some View {
        List {
            // Pro 功能检查
            if !subscriptionManager.canUseCloudSync {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                        
                        Text("云同步是 Pro 功能")
                            .font(.headline)
                        
                        Text("升级到 Pro 版解锁 iCloud 云同步，在多设备间同步您的账单数据")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            showingPurchase = true
                        } label: {
                            Text("升级到 Pro")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .sheet(isPresented: $showingPurchase) {
                    PurchaseView()
                }
            } else {
                // 原有的云同步设置内容
                // 同步状态
                Section {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(syncManager.isSyncing ? .blue : .gray)
                    Text("iCloud 同步")
                    Spacer()
                    if syncManager.isSyncing {
                        ProgressView()
                    } else if syncManager.lastSyncDate != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if let lastSync = syncManager.lastSyncDate {
                    HStack {
                        Text("上次同步")
                        Spacer()
                        Text(timeAgo(lastSync))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = syncManager.syncError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 自动同步开关
            Section {
                Toggle(isOn: $syncManager.isAutoSyncEnabled) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("自动同步")
                    }
                }
                
                if syncManager.isAutoSyncEnabled {
                    Picker("同步频率", selection: $syncManager.syncInterval) {
                        ForEach(AutoSyncManager.SyncInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                }
            } footer: {
                Text(syncManager.isAutoSyncEnabled ? "应用会在后台自动同步数据到 iCloud" : "关闭自动同步后，需要手动点击同步按钮")
            }
            
            // 手动同步按钮
            Section {
                Button(action: {
                    Task {
                        await syncManager.manualSync()
                    }
                }) {
                    HStack {
                        Spacer()
                        if syncManager.isSyncing {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(syncManager.isSyncing ? "同步中..." : "立即同步")
                        Spacer()
                    }
                }
                .disabled(syncManager.isSyncing)
            } footer: {
                Text("手动同步会立即上传本地数据到 iCloud，并下载云端的最新数据")
            }
            
            // 说明
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("数据安全", systemImage: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("所有数据通过 iCloud 加密传输和存储")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("多设备同步", systemImage: "iphone.and.ipad")
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    Text("在你的所有 Apple 设备间自动同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("离线可用", systemImage: "wifi.slash")
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                    Text("即使没有网络，应用也能正常使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            }
        }
        .navigationTitle("云同步设置")
        .alert("同步失败", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            if let error = syncManager.syncError {
                Text(error)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }
}
