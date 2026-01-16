import { useState } from 'react';
import { Upload, Database, Trash2, ChevronRight, Tag, Users, CreditCard } from 'lucide-react';
import { initializeData, clearAllData } from '../services/db';
import { importFromCSV } from '../services/exportService';
import CategoryManagementView from './CategoryManagementView';
import OwnerManagementView from './OwnerManagementView';
import PaymentMethodManagementView from './PaymentMethodManagementView';

type ManagementView = 'main' | 'category' | 'owner' | 'payment';

export default function SettingsView() {
  const [importing, setImporting] = useState(false);
  const [currentView, setCurrentView] = useState<ManagementView>('main');

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
