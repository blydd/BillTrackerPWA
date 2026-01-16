import { useState, useEffect } from 'react';
import { Home, BarChart3, Settings } from 'lucide-react';
import BillListView from './components/BillListView';
import StatisticsView from './components/StatisticsView';
import SettingsView from './components/SettingsView';
import { startAutoBackupCheck, stopAutoBackupCheck } from './services/fileSystemBackupService';

type Tab = 'bills' | 'statistics' | 'settings';

function App() {
  const [activeTab, setActiveTab] = useState<Tab>('bills');

  // 启动自动备份检查
  useEffect(() => {
    startAutoBackupCheck();
    
    return () => {
      stopAutoBackupCheck();
    };
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex flex-col">
      {/* 头部 */}
      <header className="bg-gradient-to-r from-primary-600 via-primary-700 to-primary-800 text-white shadow-xl">
        <div className="max-w-7xl mx-auto px-4 py-5">
          <h1 className="text-2xl font-bold tracking-wide">💰 账单管理</h1>
        </div>
      </header>

      {/* 主内容区 */}
      <main className="flex-1 overflow-auto pb-16">
        <div className="max-w-7xl mx-auto">
          {activeTab === 'bills' && <BillListView />}
          {activeTab === 'statistics' && <StatisticsView />}
          {activeTab === 'settings' && <SettingsView />}
        </div>
      </main>

      {/* 底部导航栏 */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-2xl">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex justify-around">
            <button
              onClick={() => setActiveTab('bills')}
              className={`flex-1 flex flex-col items-center py-3 transition-all ${
                activeTab === 'bills' 
                  ? 'text-primary-600 scale-105' 
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <Home size={24} className={activeTab === 'bills' ? 'drop-shadow-md' : ''} />
              <span className={`text-xs mt-1 font-medium ${activeTab === 'bills' ? 'font-semibold' : ''}`}>
                账单
              </span>
            </button>
            
            <button
              onClick={() => setActiveTab('statistics')}
              className={`flex-1 flex flex-col items-center py-3 transition-all ${
                activeTab === 'statistics' 
                  ? 'text-primary-600 scale-105' 
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <BarChart3 size={24} className={activeTab === 'statistics' ? 'drop-shadow-md' : ''} />
              <span className={`text-xs mt-1 font-medium ${activeTab === 'statistics' ? 'font-semibold' : ''}`}>
                统计
              </span>
            </button>
            
            <button
              onClick={() => setActiveTab('settings')}
              className={`flex-1 flex flex-col items-center py-3 transition-all ${
                activeTab === 'settings' 
                  ? 'text-primary-600 scale-105' 
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <Settings size={24} className={activeTab === 'settings' ? 'drop-shadow-md' : ''} />
              <span className={`text-xs mt-1 font-medium ${activeTab === 'settings' ? 'font-semibold' : ''}`}>
                设置
              </span>
            </button>
          </div>
        </div>
      </nav>
    </div>
  );
}

export default App;
