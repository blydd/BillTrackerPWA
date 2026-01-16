import { useState, useEffect } from 'react';
import { Upload, Database, Trash2, ChevronRight, Tag, Users, CreditCard, FolderOpen, Save, RotateCcw } from 'lucide-react';
import { initializeData, clearAllData } from '../services/db';
import { importFromCSV } from '../services/exportService';
import {
  isFileSystemAccessSupported,
  requestBackupDirectory,
  performBackup,
  restoreFromBackup,
  getSavedDirectoryHandle,
  clearBackupDirectory,
  getLastBackupTime,
  AUTO_BACKUP_INTERVALS,
  getAutoBackupInterval,
  setAutoBackupInterval,
  type AutoBackupInterval
} from '../services/fileSystemBackupService';
import CategoryManagementView from './CategoryManagementView';
import OwnerManagementView from './OwnerManagementView';
import PaymentMethodManagementView from './PaymentMethodManagementView';

type ManagementView = 'main' | 'category' | 'owner' | 'payment';

export default function SettingsView() {
  const [importing, setImporting] = useState(false);
  const [currentView, setCurrentView] = useState<ManagementView>('main');
  const [backupConfigured, setBackupConfigured] = useState(false);
  const [lastBackup, setLastBackup] = useState<Date | null>(null);
  const [backing, setBacking] = useState(false);
  const [autoBackupInterval, setAutoBackupIntervalState] = useState<AutoBackupInterval>(AUTO_BACKUP_INTERVALS.WEEKLY);

  useEffect(() => {
    checkBackupStatus();
    loadAutoBackupInterval();
  }, []);

  async function loadAutoBackupInterval() {
    const interval = await getAutoBackupInterval();
    setAutoBackupIntervalState(interval);
  }

  async function handleAutoBackupIntervalChange(interval: AutoBackupInterval) {
    try {
      await setAutoBackupInterval(interval);
      setAutoBackupIntervalState(interval);
    } catch (error) {
      alert('设置失败：' + (error as Error).message);
    }
  }

  async function checkBackupStatus() {
    const dirHandle = await getSavedDirectoryHandle();
    setBackupConfigured(!!dirHandle);
    const lastTime = await getLastBackupTime();
    setLastBackup(lastTime);
  }

  const handleConfigureBackup = async () => {
    try {
      const dirHandle = await requestBackupDirectory();
      if (dirHandle) {
        alert('备份文件夹设置成功！');
        await checkBackupStatus();
      }
    } catch (error) {
      alert('设置失败：' + (error as Error).message);
    }
  };

  const handleBackupNow = async () => {
    setBacking(true);
    try {
      const fileName = await performBackup();
      alert(`备份成功！\n文件名：${fileName}`);
      await checkBackupStatus();
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
      await restoreFromBackup();
      alert('恢复成功！');
      window.location.reload();
    } catch (error) {
      alert('恢复失败：' + (error as Error).message);
    }
  };

  const handleClearBackupConfig = async () => {
    if (!confirm('确定要清除备份配置吗？')) {
      return;
    }

    try {
      await clearBackupDirectory();
      setBackupConfigured(false);
      alert('备份配置已清除');
    } catch (error) {
      alert('清除失败：' + (error as Error).message);
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

      {/* 自动备份 */}
      {isFileSystemAccessSupported() && (
        <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
          <div className="px-4 py-3 bg-gradient-to-r from-orange-600 to-orange-700">
            <h3 className="font-semibold text-white">自动备份</h3>
          </div>

          {/* 配置备份文件夹 */}
          <div className="p-4 border-b">
            <div className="flex items-center justify-between gap-4">
              <div className="flex-1">
                <div className="font-semibold text-gray-800">备份文件夹</div>
                <div className="text-sm text-gray-500 mt-1">
                  {backupConfigured ? (
                    <>
                      <span className="text-green-600">✓ 已配置</span>
                      {lastBackup && (
                        <span className="ml-2">
                          最后备份：{lastBackup.toLocaleString('zh-CN')}
                        </span>
                      )}
                    </>
                  ) : (
                    '选择本地文件夹用于自动备份'
                  )}
                </div>
              </div>
              <div className="flex gap-2">
                {backupConfigured && (
                  <button
                    onClick={handleClearBackupConfig}
                    className="px-3 py-2 bg-gray-200 text-gray-700 rounded-xl hover:bg-gray-300 transition-all whitespace-nowrap text-sm"
                  >
                    清除
                  </button>
                )}
                <button
                  onClick={handleConfigureBackup}
                  className="px-4 py-2 bg-gradient-to-r from-orange-600 to-orange-700 text-white rounded-xl hover:from-orange-700 hover:to-orange-800 shadow-md transition-all whitespace-nowrap"
                >
                  <FolderOpen size={18} className="inline mr-2" />
                  {backupConfigured ? '重新选择' : '选择文件夹'}
                </button>
              </div>
            </div>
          </div>

          {/* 自动备份间隔 */}
          {backupConfigured && (
            <div className="p-4 border-b">
              <div className="flex items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="font-semibold text-gray-800">自动备份间隔</div>
                  <div className="text-sm text-gray-500 mt-1">
                    应用运行时会自动检查并备份
                  </div>
                </div>
                <select
                  value={autoBackupInterval}
                  onChange={(e) => handleAutoBackupIntervalChange(Number(e.target.value) as AutoBackupInterval)}
                  className="px-4 py-2 border-2 border-gray-300 rounded-xl focus:border-orange-500 focus:ring-2 focus:ring-orange-200 transition-all"
                >
                  <option value={AUTO_BACKUP_INTERVALS.DAILY}>每天</option>
                  <option value={AUTO_BACKUP_INTERVALS.THREE_DAYS}>每3天</option>
                  <option value={AUTO_BACKUP_INTERVALS.WEEKLY}>每周</option>
                  <option value={AUTO_BACKUP_INTERVALS.DISABLED}>禁用</option>
                </select>
              </div>
            </div>
          )}

          {/* 立即备份 */}
          {backupConfigured && (
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
      )}

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
