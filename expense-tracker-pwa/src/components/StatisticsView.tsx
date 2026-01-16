import { useState, useEffect } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { getBills } from '../services/billService';
import { calculateStatistics } from '../services/statisticsService';
import { Statistics, DateRangePreset, BillFilter, TransactionType } from '../models/types';
import { startOfMonth, endOfMonth, startOfYear, endOfYear, subMonths, format } from 'date-fns';
import { Calendar, X, ChevronLeft, ChevronRight } from 'lucide-react';
import StatisticsBillListView from './StatisticsBillListView';

export default function StatisticsView() {
  const [dateRange, setDateRange] = useState<DateRangePreset>(DateRangePreset.THIS_MONTH);
  const [overviewStatistics, setOverviewStatistics] = useState<Statistics | null>(null); // 总览统计（不受交易类型影响）
  const [statistics, setStatistics] = useState<Statistics | null>(null); // 列表统计（受交易类型影响）
  const [transactionTypeFilter, setTransactionTypeFilter] = useState<TransactionType | 'all'>('all');
  const [activeTab, setActiveTab] = useState<'category' | 'owner' | 'payment'>('category');
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [customStartDate, setCustomStartDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [customEndDate, setCustomEndDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [selectionMode, setSelectionMode] = useState<'month' | 'custom'>('month');
  const [showBillList, setShowBillList] = useState(false);
  const [billListFilter, setBillListFilter] = useState<BillFilter>({});
  const [billListTitle, setBillListTitle] = useState('');

  const billsData = useLiveQuery(() => db.bills.toArray(), []);

  useEffect(() => {
    loadStatistics();
  }, [billsData, dateRange, customStartDate, customEndDate, transactionTypeFilter]);

  async function loadStatistics() {
    const { startDate, endDate } = getDateRange(dateRange);
    
    // 加载总览统计（不受交易类型影响）
    const overviewBills = await getBills({ startDate, endDate });
    const overviewStats = await calculateStatistics(overviewBills);
    setOverviewStatistics(overviewStats);
    
    // 加载列表统计（受交易类型影响）
    const filter: BillFilter = { startDate, endDate };
    if (transactionTypeFilter !== 'all') {
      filter.transactionTypes = [transactionTypeFilter];
    }
    const bills = await getBills(filter);
    const stats = await calculateStatistics(bills);
    setStatistics(stats);
  }

  function getDateRange(preset: DateRangePreset) {
    const now = new Date();
    switch (preset) {
      case DateRangePreset.THIS_MONTH:
        return { startDate: startOfMonth(now), endDate: endOfMonth(now) };
      case DateRangePreset.LAST_MONTH:
        const lastMonth = subMonths(now, 1);
        return { startDate: startOfMonth(lastMonth), endDate: endOfMonth(lastMonth) };
      case DateRangePreset.THIS_YEAR:
        return { startDate: startOfYear(now), endDate: endOfYear(now) };
      case DateRangePreset.CUSTOM:
        return { 
          startDate: new Date(customStartDate), 
          endDate: new Date(customEndDate) 
        };
      case DateRangePreset.ALL:
      default:
        return { startDate: undefined, endDate: undefined };
    }
  }

  const handleCustomDateConfirm = () => {
    setDateRange(DateRangePreset.CUSTOM);
    setShowDatePicker(false);
  };

  const handleMonthSelect = (month: number) => {
    const start = new Date(selectedYear, month - 1, 1);
    const end = endOfMonth(start);
    setCustomStartDate(format(start, 'yyyy-MM-dd'));
    setCustomEndDate(format(end, 'yyyy-MM-dd'));
    // 立即设置为自定义范围，触发统计数据更新
    setDateRange(DateRangePreset.CUSTOM);
  };

  const isSelectedMonth = (month: number) => {
    const start = new Date(customStartDate);
    const end = new Date(customEndDate);
    const monthStart = new Date(selectedYear, month - 1, 1);
    const monthEnd = endOfMonth(monthStart);
    
    // 比较日期字符串
    const startMatch = format(start, 'yyyy-MM-dd') === format(monthStart, 'yyyy-MM-dd');
    const endMatch = format(end, 'yyyy-MM-dd') === format(monthEnd, 'yyyy-MM-dd');
    
    return startMatch && endMatch;
  };

  const getDateRangeLabel = () => {
    if (dateRange === DateRangePreset.CUSTOM) {
      return `${format(new Date(customStartDate), 'MM/dd')} - ${format(new Date(customEndDate), 'MM/dd')}`;
    }
    const labels = {
      [DateRangePreset.THIS_MONTH]: '本月',
      [DateRangePreset.LAST_MONTH]: '上月',
      [DateRangePreset.THIS_YEAR]: '今年',
      [DateRangePreset.ALL]: '全部'
    };
    return labels[dateRange] || '全部';
  };

  const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];

  // 点击统计项查看账单列表
  const handleCategoryClick = (categoryId: number, categoryName: string) => {
    const { startDate, endDate } = getDateRange(dateRange);
    const filter: BillFilter = {
      categoryIds: [categoryId],
      startDate,
      endDate
    };
    
    // 添加交易类型筛选
    if (transactionTypeFilter !== 'all') {
      filter.transactionTypes = [transactionTypeFilter];
    }
    
    setBillListFilter(filter);
    setBillListTitle(`${categoryName} - 账单列表`);
    setShowBillList(true);
  };

  const handleOwnerClick = (ownerId: number, ownerName: string) => {
    const { startDate, endDate } = getDateRange(dateRange);
    const filter: BillFilter = {
      ownerIds: [ownerId],
      startDate,
      endDate
    };
    
    // 添加交易类型筛选
    if (transactionTypeFilter !== 'all') {
      filter.transactionTypes = [transactionTypeFilter];
    }
    
    setBillListFilter(filter);
    setBillListTitle(`${ownerName} - 账单列表`);
    setShowBillList(true);
  };

  const handlePaymentMethodClick = (paymentMethodId: number, paymentMethodName: string) => {
    const { startDate, endDate } = getDateRange(dateRange);
    const filter: BillFilter = {
      paymentMethodIds: [paymentMethodId],
      startDate,
      endDate
    };
    
    // 添加交易类型筛选
    if (transactionTypeFilter !== 'all') {
      filter.transactionTypes = [transactionTypeFilter];
    }
    
    setBillListFilter(filter);
    setBillListTitle(`${paymentMethodName} - 账单列表`);
    setShowBillList(true);
  };

  if (showBillList) {
    return (
      <StatisticsBillListView
        filter={billListFilter}
        title={billListTitle}
        onClose={() => setShowBillList(false)}
      />
    );
  }

  if (!statistics || !overviewStatistics) {
    return <div className="p-4 text-center">加载中...</div>;
  }

  return (
    <div className="p-4 space-y-4">
      {/* 日期范围选择 */}
      <div className="flex gap-2 overflow-x-auto">
        {[
          { value: DateRangePreset.THIS_MONTH, label: '本月' },
          { value: DateRangePreset.LAST_MONTH, label: '上月' },
          { value: DateRangePreset.THIS_YEAR, label: '今年' },
          { value: DateRangePreset.ALL, label: '全部' }
        ].map(range => (
          <button
            key={range.value}
            onClick={() => setDateRange(range.value)}
            className={`px-4 py-2 rounded-lg whitespace-nowrap ${
              dateRange === range.value
                ? 'bg-primary-600 text-white'
                : 'bg-white border border-gray-300'
            }`}
          >
            {range.label}
          </button>
        ))}
        
        {/* 自定义范围按钮 */}
        <button
          onClick={() => setShowDatePicker(true)}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg whitespace-nowrap ${
            dateRange === DateRangePreset.CUSTOM
              ? 'bg-primary-600 text-white'
              : 'bg-white border border-gray-300'
          }`}
        >
          <Calendar size={16} />
          <span>{dateRange === DateRangePreset.CUSTOM ? getDateRangeLabel() : '自定义'}</span>
        </button>
      </div>

      {/* 总览卡片 */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-gradient-to-br from-green-50 to-green-100 rounded-xl shadow-sm p-4 border border-green-200">
          <div className="text-sm text-green-700 mb-1 font-medium">总收入</div>
          <div className="text-2xl font-bold text-green-600">
            ¥{overviewStatistics.totalIncome.toFixed(2)}
          </div>
        </div>
        <div className="bg-gradient-to-br from-red-50 to-red-100 rounded-xl shadow-sm p-4 border border-red-200">
          <div className="text-sm text-red-700 mb-1 font-medium">总支出</div>
          <div className="text-2xl font-bold text-red-600">
            ¥{overviewStatistics.totalExpense.toFixed(2)}
          </div>
        </div>
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-xl shadow-sm p-4 border border-blue-200">
          <div className="text-sm text-blue-700 mb-1 font-medium">净收入</div>
          <div className="text-2xl font-bold text-blue-600">
            ¥{overviewStatistics.netIncome.toFixed(2)}
          </div>
        </div>
        <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl shadow-sm p-4 border border-gray-200">
          <div className="text-sm text-gray-700 mb-1 font-medium">不计入</div>
          <div className="text-2xl font-bold text-gray-600">
            ¥{overviewStatistics.totalExcluded.toFixed(2)}
          </div>
        </div>
      </div>

      {/* 交易类型筛选 Tab */}
      <div className="flex gap-2 bg-gray-50 p-2 rounded-lg">
        {[
          { value: 'all' as const, label: '全部' },
          { value: TransactionType.EXPENSE, label: '支出' },
          { value: TransactionType.INCOME, label: '收入' },
          { value: TransactionType.EXCLUDED, label: '不计入' }
        ].map(type => (
          <button
            key={type.value}
            onClick={() => setTransactionTypeFilter(type.value)}
            className={`flex-1 py-2 rounded-lg font-medium transition-all ${
              transactionTypeFilter === type.value
                ? 'bg-white text-primary-600 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {type.label}
          </button>
        ))}
      </div>

      {/* Tab 切换 */}
      <div className="flex gap-2 border-b">
        {[
          { value: 'category' as const, label: '按类型' },
          { value: 'owner' as const, label: '按归属人' },
          { value: 'payment' as const, label: '按支付方式' }
        ].map(tab => (
          <button
            key={tab.value}
            onClick={() => setActiveTab(tab.value)}
            className={`px-4 py-2 ${
              activeTab === tab.value
                ? 'border-b-2 border-primary-600 text-primary-600 font-medium'
                : 'text-gray-600'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* 统计列表 */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 divide-y divide-gray-100 overflow-hidden">
        {activeTab === 'category' && statistics.byCategory.map(stat => (
          <button
            key={stat.categoryId}
            onClick={() => handleCategoryClick(stat.categoryId, stat.categoryName)}
            className="w-full p-4 flex justify-between items-center hover:bg-gradient-to-r hover:from-blue-50 hover:to-transparent text-left transition-all group"
          >
            <div>
              <div className="font-medium text-gray-800 group-hover:text-primary-600 transition-colors">{stat.categoryName}</div>
              <div className="text-sm text-gray-500 mt-0.5">{stat.count} 笔</div>
            </div>
            <div className="text-lg font-bold text-gray-700 group-hover:text-primary-600 transition-colors">
              ¥{stat.amount.toFixed(2)}
            </div>
          </button>
        ))}

        {activeTab === 'owner' && statistics.byOwner.map(stat => (
          <button
            key={stat.ownerId}
            onClick={() => handleOwnerClick(stat.ownerId, stat.ownerName)}
            className="w-full p-4 hover:bg-gradient-to-r hover:from-blue-50 hover:to-transparent text-left transition-all group"
          >
            <div className="font-medium text-gray-800 mb-3 group-hover:text-primary-600 transition-colors">{stat.ownerName}</div>
            <div className="grid grid-cols-3 gap-3 text-sm">
              <div className="bg-green-50 rounded-lg p-2 border border-green-100">
                <div className="text-green-700 text-xs mb-1">收入</div>
                <div className="text-green-600 font-semibold">¥{stat.income.toFixed(2)}</div>
              </div>
              <div className="bg-red-50 rounded-lg p-2 border border-red-100">
                <div className="text-red-700 text-xs mb-1">支出</div>
                <div className="text-red-600 font-semibold">¥{stat.expense.toFixed(2)}</div>
              </div>
              <div className="bg-gray-50 rounded-lg p-2 border border-gray-100">
                <div className="text-gray-700 text-xs mb-1">不计入</div>
                <div className="text-gray-600 font-semibold">¥{stat.excluded.toFixed(2)}</div>
              </div>
            </div>
            <div className="text-sm text-gray-500 mt-2">{stat.count} 笔</div>
          </button>
        ))}

        {activeTab === 'payment' && statistics.byPaymentMethod.map(stat => (
          <button
            key={stat.paymentMethodId}
            onClick={() => handlePaymentMethodClick(stat.paymentMethodId, stat.paymentMethodName)}
            className="w-full p-4 flex justify-between items-center hover:bg-gradient-to-r hover:from-blue-50 hover:to-transparent text-left transition-all group"
          >
            <div>
              <div className="font-medium text-gray-800 group-hover:text-primary-600 transition-colors">{stat.paymentMethodName}</div>
              <div className="text-sm text-gray-500 mt-0.5">{stat.count} 笔</div>
            </div>
            <div className="text-lg font-bold text-gray-700 group-hover:text-primary-600 transition-colors">
              ¥{stat.amount.toFixed(2)}
            </div>
          </button>
        ))}
      </div>

      {/* 自定义日期范围选择弹窗 */}
      {showDatePicker && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="border-b px-6 py-4 flex items-center justify-between">
              <h2 className="text-xl font-bold">选择日期范围</h2>
              <button 
                onClick={() => setShowDatePicker(false)} 
                className="p-1 hover:bg-gray-100 rounded"
              >
                <X size={24} />
              </button>
            </div>

            <div className="p-6 space-y-4">
              {/* 选择模式切换 */}
              <div className="flex gap-2">
                <button
                  onClick={() => setSelectionMode('month')}
                  className={`flex-1 py-2 rounded-lg ${
                    selectionMode === 'month'
                      ? 'bg-primary-600 text-white'
                      : 'bg-gray-100 text-gray-700'
                  }`}
                >
                  按月选择
                </button>
                <button
                  onClick={() => setSelectionMode('custom')}
                  className={`flex-1 py-2 rounded-lg ${
                    selectionMode === 'custom'
                      ? 'bg-primary-600 text-white'
                      : 'bg-gray-100 text-gray-700'
                  }`}
                >
                  自定义范围
                </button>
              </div>

              {/* 按月选择模式 */}
              {selectionMode === 'month' && (
                <div className="space-y-4">
                  {/* 年份选择 */}
                  <div className="flex items-center justify-between">
                    <button
                      onClick={() => setSelectedYear(selectedYear - 1)}
                      className="p-2 hover:bg-gray-100 rounded-lg"
                    >
                      <ChevronLeft size={24} className="text-primary-600" />
                    </button>
                    <span className="text-xl font-semibold">{selectedYear}年</span>
                    <button
                      onClick={() => setSelectedYear(selectedYear + 1)}
                      className="p-2 hover:bg-gray-100 rounded-lg"
                    >
                      <ChevronRight size={24} className="text-primary-600" />
                    </button>
                  </div>

                  {/* 月份九宫格 */}
                  <div className="grid grid-cols-3 gap-3">
                    {months.map((month, index) => {
                      const monthNum = index + 1;
                      const selected = isSelectedMonth(monthNum);
                      return (
                        <button
                          key={monthNum}
                          onClick={() => handleMonthSelect(monthNum)}
                          className={`py-4 rounded-lg font-medium transition-colors ${
                            selected
                              ? 'bg-primary-600 text-white'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                          }`}
                        >
                          {month}
                        </button>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* 自定义范围模式 */}
              {selectionMode === 'custom' && (
                <div className="space-y-4">
                  {/* 开始日期 */}
                  <div>
                    <label className="block text-sm font-medium mb-2 text-gray-700">
                      开始日期
                    </label>
                    <input
                      type="date"
                      value={customStartDate}
                      onChange={(e) => setCustomStartDate(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>

                  {/* 结束日期 */}
                  <div>
                    <label className="block text-sm font-medium mb-2 text-gray-700">
                      结束日期
                    </label>
                    <input
                      type="date"
                      value={customEndDate}
                      onChange={(e) => setCustomEndDate(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                </div>
              )}

              {/* 统计范围显示 */}
              <div className="bg-blue-50 rounded-lg p-4 text-center">
                <div className="text-sm text-gray-600 mb-1">统计范围</div>
                <div className="font-semibold text-gray-900">
                  {format(new Date(customStartDate), 'yyyy年MM月dd日')} - {format(new Date(customEndDate), 'yyyy年MM月dd日')}
                </div>
              </div>

              {/* 按钮 */}
              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowDatePicker(false)}
                  className="flex-1 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  取消
                </button>
                <button
                  type="button"
                  onClick={handleCustomDateConfirm}
                  className="flex-1 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
                >
                  确定
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
