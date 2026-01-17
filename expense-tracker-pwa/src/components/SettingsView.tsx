import { useState, useEffect } from 'react';
import { Upload, Database, Trash2, ChevronRight, Tag, Users, CreditCard, Download, Save, RotateCcw, Cloud } from 'lucide-react';
import { initializeData, clearAllData } from '../services/db';
import { importFromCSV } from '../services/exportService';
import {
  BackupMethod,
  BACKUP_INTERVALS,
  type BackupInterval,
  type BackupConfig,
  getBackupConfig,
  saveBackupConfig,
  downloadBackup,
  restoreFromBackupFile
} from '../services/universalBackupService';
import CategoryManagementView from './CategoryManagementView';
import OwnerManagementView from './OwnerManagementView';
import PaymentMethodManagementView from './PaymentMethodManagementView';

type ManagementView = 'main' | 'category' | 'owner' | 'payment';

export default function SettingsView() {
  const [importing, setImporting] = useState(false);
  const [currentView, setCurrentView] = useState<ManagementView>('main');
  const [backupConfig, setBackupConfig] = useState<BackupConfig>({
    method: BackupMethod.LOCAL_DOWNLOAD,
    interval: BACKUP_INTERVALS.WEEKLY
  });
  const [backing, setBacking] = useState(false);

  useEffect(() => {
    loadBackupConfig();
  }, []);

  async function loadBackupConfig() {
    try {
      const config = await getBackupConfig();
      setBackupConfig(config);
    } catch (error) {
      console.error('加载备份配置失败:', error);
    }
  }

  async function handleBackupMethodChange(method: BackupMethod) {
    try {
      const newConfig = { ...backupConfig, method };
      await saveBackupConfig(newConfig);
      setBackupConfig(newConfig);
    } catch (error) {
      alert('设置失败：' + (error as Error).message);
    }
  }

  async function handleBackupIntervalChange(interval: BackupInterval) {
    try {
      const newConfig = { ...backupConfig, interval };
      await saveBackupConfig(newConfig);
      setBackupConfig(newConfig);
    } catch (error) {
      alert('设置失败：' + (error as Error).message);
    }
  }

  const handleBackupNow = async () => {
    setBacking(true);
    try {
      if (backupConfig.method === BackupMethod.LOCAL_DOWNLOAD) {
        await downloadBackup();
        alert('备份成功！文件已下载到您的下载文件夹');
      } else if (backupConfig.method === BackupMethod.GOOGLE_DRIVE) {
        alert('Google Drive 备份功能开发中，请使用本地下载备份');
      } else {
        alert('请先选择备份方式');
      }
    } catch (error) {
      alert('备份失败：' + (error as Error).message);
    } finally {
      setBacking(false);
    }
  };

  const handleRestore = async () => {
    if (!confirm('确定要从备份恢复数据吗？这将覆盖当前所有数据！')) {
      return;
    }

    try {
      await restoreFromBackupFile();
      alert('恢复成功！');
      window.location.reload();
    } catch (error) {
      alert('恢复失败：' + (error as Error).message);
    }
  };

  const handleInitialize = async () => {
    if (!confirm('确定要初始化数据吗？这将创建默认的归属人、账单类型和支付方式。')) {
      return;
    }

    try {
      await initializeData();
      alert('初始化成功！');
      window.location.reload();
    } catch (error) {
      alert('初始化失败：' + (error as Error).message);
    }
  };

  const handleClearData = async () => {
    if (!confirm('确定要清空所有数据吗？此操作不可恢复！')) {
      return;
    }

    if (!confirm('再次确认：真的要删除所有数据吗？')) {
      return;
    }

    try {
      await clearAllData();
      alert('数据已清空');
      window.location.reload();
    } catch (error) {
      alert('清空失败：' + (error as Error).message);
    }
  };

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setImporting(true);
    try {
      const result = await importFromCSV(file);
      const messages = [
        `导入完成！`,
        `✅ 成功：${result.success} 条`,
        `❌ 失败：${result.failed} 条`,
        `⏭️ 跳过（重复）：${result.skipped} 条`
      ];
      alert(messages.join('\n'));
    } catch (error) {
      alert('导入失败：' + (error as Error).message);
    } finally {
      setImporting(false);
      e.target.value = '';
    }
  };

  // 如果在子页面，显示子页面内容
  if (currentView === 'category') {
    return (
      <div>
        <div className="bg-white border-b px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => setCurrentView('main')}
            className="text-primary-600 hover:text-primary-700"
          >
            ← 返回
          </button>
          <h2 className="text-lg font-semibold">账单类型管理</h2>
        </div>
        <CategoryManagementView />
      </div>
    );
  }

  if (currentView === 'owner') {
    return (
      <div>
        <div className="bg-white border-b px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => setCurrentView('main')}
            className="text-primary-600 hover:text-primary-700"
          >
            ← 返回
          </button>
          <h2 className="text-lg font-semibold">归属人管理</h2>
        </div>
        <OwnerManagementView />
      </div>
    );
  }

  if (currentView === 'payment') {
    return (
      <div>
        <div className="bg-white border-b px-4 py-3 flex items-center gap-3">
          <button
            onClick={() => setCurrentView('main')}
            className="text-primary-600 hover:text-primary-700"
          >
            ← 返回
          </button>
          <h2 className="text-lg font-semibold">支付方式管理</h2>
        </div>
        <PaymentMethodManagementView />
      </div>
    );
  }

  // 主设置页面
  return (
    <div className="p-4 space-y-4">
      {/* 数据管理 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        <div className="px-4 py-3 bg-gradient-to-r from-primary-600 to-primary-700">
          <h3 className="font-semibold text-white">数据管理</h3>
        </div>

        {/* 账单类型管理 */}
        <button
          onClick={() => setCurrentView('category')}
          className="w-full p-4 flex items-center justify-between hover:bg-gradient-to-r hover:from-blue-50 hover:to-transparent transition-all border-b"
        >
          <div className="flex items-center gap-3">
            <div className="p-3 bg-gradient-to-br from-blue-100 to-blue-200 rounded-xl shadow-sm">
              <Tag size={20} className="text-blue-600" />
            </div>
            <div className="text-left">
              <div className="font-semibold text-gray-800">账单类型管理</div>
              <div className="text-sm text-gray-500">管理支出、收入、不计入类型</div>
            </div>
          </div>
          <ChevronRight size={20} className="text-gray-400" />
        </button>

        {/* 归属人管理 */}
        <button
          onClick={() => setCurrentView('owner')}
          className="w-full p-4 flex items-center justify-between hover:bg-gradient-to-r hover:from-green-50 hover:to-transparent transition-all border-b"
        >
          <div className="flex items-center gap-3">
            <div className="p-3 bg-gradient-to-br from-green-100 to-green-200 rounded-xl shadow-sm">
              <Users size={20} className="text-green-600" />
            </div>
            <div className="text-left">
              <div className="font-semibold text-gray-800">归属人管理</div>
              <div className="text-sm text-gray-500">管理账单归属人</div>
            </div>
          </div>
          <ChevronRight size={20} className="text-gray-400" />
        </button>

        {/* 支付方式管理 */}
        <button
          onClick={() => setCurrentView('payment')}
          className="w-full p-4 flex items-center justify-between hover:bg-gradient-to-r hover:from-purple-50 hover:to-transparent transition-all"
        >
          <div className="flex items-center gap-3">
            <div className="p-3 bg-gradient-to-br from-purple-100 to-purple-200 rounded-xl shadow-sm">
              <CreditCard size={20} className="text-purple-600" />
            </div>
            <div className="text-left">
              <div className="font-semibold text-gray-800">支付方式管理</div>
              <div className="text-sm text-gray-500">管理信贷和储蓄方式</div>
            </div>
          </div>
          <ChevronRight size={20} className="text-gray-400" />
        </button>
      </div>

      {/* 数据备份 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        <div className="px-4 py-3 bg-gradient-to-r from-orange-600 to-orange-700">
          <h3 className="font-semibold text-white">数据备份</h3>
        </div>

        {/* 备份方式选择 */}
        <div className="p-4 border-b">
          <div className="mb-3">
            <div className="font-semibold text-gray-800 mb-2">备份方式</div>
            <div className="text-sm text-gray-500 mb-3">
              选择您偏好的备份方式
            </div>
          </div>
          <div className="space-y-2">
            <label className="flex items-center gap-3 p-3 border-2 rounded-xl cursor-pointer hover:bg-gray-50 transition-all">
              <input
                type="radio"
                name="backupMethod"
                value={BackupMethod.LOCAL_DOWNLOAD}
                checked={backupConfig.method === BackupMethod.LOCAL_DOWNLOAD}
                onChange={(e) => handleBackupMethodChange(e.target.value as BackupMethod)}
                className="text-orange-600"
              />
              <Download size={20} className="text-blue-600" />
              <div className="flex-1">
                <div className="font-medium text-gray-800">本地下载</div>
                <div className="text-sm text-gray-500">备份文件下载到本地（推荐，兼容所有浏览器）</div>
              </div>
            </label>
            <label className="flex items-center gap-3 p-3 border-2 rounded-xl cursor-pointer hover:bg-gray-50 transition-all opacity-60">
              <input
                type="radio"
                name="backupMethod"
                value={BackupMethod.GOOGLE_DRIVE}
                checked={backupConfig.method === BackupMethod.GOOGLE_DRIVE}
                onChange={(e) => handleBackupMethodChange(e.target.value as BackupMethod)}
                className="text-orange-600"
                disabled
              />
              <Cloud size={20} className="text-green-600" />
              <div className="flex-1">
                <div className="font-medium text-gray-800">Google Drive</div>
                <div className="text-sm text-gray-500">自动上传到 Google Drive（开发中）</div>
              </div>
            </label>
            <label className="flex items-center gap-3 p-3 border-2 rounded-xl cursor-pointer hover:bg-gray-50 transition-all">
              <input
                type="radio"
                name="backupMethod"
                value={BackupMethod.DISABLED}
                checked={backupConfig.method === BackupMethod.DISABLED}
                onChange={(e) => handleBackupMethodChange(e.target.value as BackupMethod)}
                className="text-orange-600"
              />
              <div className="w-5 h-5 flex items-center justify-center">
                <span className="text-gray-400">✕</span>
              </div>
              <div className="flex-1">
                <div className="font-medium text-gray-800">禁用备份</div>
                <div className="text-sm text-gray-500">不进行自动备份</div>
              </div>
            </label>
          </div>
        </div>

        {/* 自动备份间隔 */}
        {backupConfig.method !== BackupMethod.DISABLED && (
          <div className="p-4 border-b">
            <div className="flex items-center justify-between gap-4">
              <div className="flex-1">
                <div className="font-semibold text-gray-800">自动备份间隔</div>
                <div className="text-sm text-gray-500 mt-1">
                  应用运行时会自动检查并备份
                </div>
              </div>
              <select
                value={backupConfig.interval}
                onChange={(e) => handleBackupIntervalChange(Number(e.target.value) as BackupInterval)}
                className="px-4 py-2 border-2 border-gray-300 rounded-xl focus:border-orange-500 focus:ring-2 focus:ring-orange-200 transition-all"
              >
                <option value={BACKUP_INTERVALS.DAILY}>每天</option>
                <option value={BACKUP_INTERVALS.THREE_DAYS}>每3天</option>
                <option value={BACKUP_INTERVALS.WEEKLY}>每周</option>
                <option value={BACKUP_INTERVALS.DISABLED}>禁用自动备份</option>
              </select>
            </div>
          </div>
        )}

        {/* 备份状态显示 */}
        {backupConfig.lastBackupTime && (
          <div className="p-4 border-b bg-green-50">
            <div className="flex items-center gap-2">
              <span className="text-green-600">✓</span>
              <div className="text-sm text-gray-700">
                最后备份时间：{backupConfig.lastBackupTime.toLocaleString('zh-CN')}
              </div>
            </div>
          </div>
        )}

        {/* 立即备份 */}
        {backupConfig.method !== BackupMethod.DISABLED && (
          <div className="p-4 border-b">
            <div className="flex items-center justify-between gap-4">
              <div className="flex-1">
                <div className="font-semibold text-gray-800">立即备份</div>
                <div className="text-sm text-gray-500 mt-1">
                  手动执行一次备份
                </div>
              </div>
              <button
                onClick={handleBackupNow}
                disabled={backing}
                className="px-4 py-2 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:from-blue-700 hover:to-blue-800 shadow-md transition-all whitespace-nowrap disabled:opacity-50"
              >
                <Save size={18} className="inline mr-2" />
                {backing ? '备份中...' : '立即备份'}
              </button>
            </div>
          </div>
        )}

        {/* 从备份恢复 */}
        <div className="p-4">
          <div className="flex items-center justify-between gap-4">
            <div className="flex-1">
              <div className="font-semibold text-gray-800">从备份恢复</div>
              <div className="text-sm text-gray-500 mt-1">
                选择备份文件恢复数据
              </div>
            </div>
            <button
              onClick={handleRestore}
              className="px-4 py-2 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-xl hover:from-purple-700 hover:to-purple-800 shadow-md transition-all whitespace-nowrap"
            >
              <RotateCcw size={18} className="inline mr-2" />
              恢复数据
            </button>
          </div>
        </div>
      </div>

      {/* 系统操作 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        <div className="px-4 py-3 bg-gradient-to-r from-gray-700 to-gray-800">
          <h3 className="font-semibold text-white">系统操作</h3>
        </div>

        {/* 初始化数据 */}
        <div className="p-4 border-b">
          <div className="flex items-center justify-between gap-4">
            <div className="flex-1">
              <div className="font-semibold text-gray-800">初始化数据</div>
              <div className="text-sm text-gray-500 mt-1">
                创建默认的归属人、账单类型和支付方式
              </div>
            </div>
            <button
              onClick={handleInitialize}
              className="px-4 py-2 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 shadow-md transition-all whitespace-nowrap"
            >
              <Database size={18} className="inline mr-2" />
              初始化
            </button>
          </div>
        </div>

        {/* 导入数据 */}
        <div className="p-4 border-b">
          <div className="flex items-center justify-between gap-4">
            <div className="flex-1">
              <div className="font-semibold text-gray-800">导入 CSV</div>
              <div className="text-sm text-gray-500 mt-1">
                从 CSV 文件导入账单数据
              </div>
            </div>
            <label className="px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-xl hover:from-green-700 hover:to-green-800 shadow-md transition-all cursor-pointer whitespace-nowrap">
              <Upload size={18} className="inline mr-2" />
              {importing ? '导入中...' : '选择文件'}
              <input
                type="file"
                accept=".csv"
                onChange={handleImport}
                disabled={importing}
                className="hidden"
              />
            </label>
          </div>
        </div>

        {/* 清空数据 */}
        <div className="p-4">
          <div className="flex items-center justify-between gap-4">
            <div className="flex-1">
              <div className="font-semibold text-red-600">清空所有数据</div>
              <div className="text-sm text-gray-500 mt-1">
                删除所有账单、类型、归属人和支付方式（不可恢复）
              </div>
            </div>
            <button
              onClick={handleClearData}
              className="px-4 py-2 bg-gradient-to-r from-red-600 to-red-700 text-white rounded-xl hover:from-red-700 hover:to-red-800 shadow-md transition-all whitespace-nowrap"
            >
              <Trash2 size={18} className="inline mr-2" />
              清空
            </button>
          </div>
        </div>
      </div>

      {/* 关于 */}
      <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-2xl shadow-lg p-6 border border-blue-100">
        <h3 className="font-semibold text-gray-800 mb-3 text-lg">关于应用</h3>
        <div className="text-sm text-gray-700 space-y-2">
          <p className="flex items-center gap-2">
            <span className="w-2 h-2 bg-primary-600 rounded-full"></span>
            版本：1.0.0
          </p>
          <p className="flex items-center gap-2">
            <span className="w-2 h-2 bg-primary-600 rounded-full"></span>
            这是一个 PWA（渐进式 Web 应用），可以安装到主屏幕使用
          </p>
          <p className="flex items-center gap-2">
            <span className="w-2 h-2 bg-primary-600 rounded-full"></span>
            所有数据保存在本地，不会上传到云端
          </p>
        </div>
      </div>
    </div>
  );
}
