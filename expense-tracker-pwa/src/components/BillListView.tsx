import { useState, useEffect } from 'react';
import { Plus, Filter, Download } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { Bill, BillFilter, TransactionType } from '../models/types';
import { getBills } from '../services/billService';
import { exportToCSV } from '../services/exportService';
import BillFormModal from './BillFormModal';
import BillFilterModal from './BillFilterModal';
import BillItem from './BillItem';
import { format } from 'date-fns';

export default function BillListView() {
  const [showForm, setShowForm] = useState(false);
  const [showFilter, setShowFilter] = useState(false);
  const [editingBill, setEditingBill] = useState<Bill | undefined>();
  const [filter, setFilter] = useState<BillFilter>({});
  const [bills, setBills] = useState<Bill[]>([]);

  // 监听数据变化
  const billsData = useLiveQuery(() => db.bills.toArray(), []);
  
  useEffect(() => {
    loadBills();
  }, [billsData, filter]);

  async function loadBills() {
    const result = await getBills(filter);
    setBills(result);
  }

  // 按日期分组
  const groupedBills = bills.reduce((groups, bill) => {
    const dateKey = format(bill.date, 'yyyy-MM-dd');
    if (!groups[dateKey]) {
      groups[dateKey] = [];
    }
    groups[dateKey].push(bill);
    return groups;
  }, {} as Record<string, Bill[]>);

  // 对每日账单按时间排序
  Object.keys(groupedBills).forEach(dateKey => {
    groupedBills[dateKey].sort((a, b) => 
      new Date(b.date).getTime() - new Date(a.date).getTime()
    );
  });

  // 计算每日统计
  const getDayStatistics = (dayBills: Bill[]) => {
    return dayBills.reduce((stats, bill) => {
      if (bill.transactionType === TransactionType.EXPENSE) {
        stats.expense += bill.amount;
      } else if (bill.transactionType === TransactionType.INCOME) {
        stats.income += bill.amount;
      } else if (bill.transactionType === TransactionType.EXCLUDED) {
        stats.excluded += bill.amount;
      }
      return stats;
    }, { expense: 0, income: 0, excluded: 0 });
  };

  const handleEdit = (bill: Bill) => {
    setEditingBill(bill);
    setShowForm(true);
  };

  const handleExport = async () => {
    try {
      await exportToCSV(bills);
    } catch (error) {
      alert('导出失败：' + (error as Error).message);
    }
  };

  return (
    <div className="p-3">
      {/* 操作栏 */}
      <div className="flex gap-2 mb-3">
        <button
          onClick={() => setShowFilter(true)}
          className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <Filter size={16} />
          <span>筛选</span>
        </button>
        
        <button
          onClick={handleExport}
          className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
        >
          <Download size={16} />
          <span>导出</span>
        </button>

        <button
          onClick={() => {
            setEditingBill(undefined);
            setShowForm(true);
          }}
          className="ml-auto flex items-center gap-1.5 px-3 py-1.5 text-sm bg-primary-600 text-white rounded-lg hover:bg-primary-700"
        >
          <Plus size={16} />
          <span>添加账单</span>
        </button>
      </div>

      {/* 账单列表 */}
      <div className="space-y-3">
        {Object.keys(groupedBills).length === 0 ? (
          <div className="text-center py-16">
            <div className="text-gray-400 text-5xl mb-4">📝</div>
            <p className="text-gray-500 text-lg">暂无账单记录</p>
            <p className="text-sm text-gray-400 mt-2">点击右上角添加按钮创建账单</p>
          </div>
        ) : (
          Object.entries(groupedBills).map(([date, dayBills]) => {
            const stats = getDayStatistics(dayBills);
            return (
              <div key={date} className="bg-white rounded-lg shadow-sm border border-gray-100 overflow-hidden">
                <div className="px-3 py-2 bg-gradient-to-r from-gray-50 to-gray-100 border-b border-gray-200">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-sm text-gray-700">{date}</span>
                    <div className="flex items-center gap-2 text-xs">
                      {stats.expense > 0 && (
                        <span className="text-red-600 font-medium">
                          支出 ¥{stats.expense.toFixed(2)}
                        </span>
                      )}
                      {stats.income > 0 && (
                        <span className="text-green-600 font-medium">
                          收入 ¥{stats.income.toFixed(2)}
                        </span>
                      )}
                      {stats.excluded > 0 && (
                        <span className="text-gray-600 font-medium">
                          不计入 ¥{stats.excluded.toFixed(2)}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
                <div className="divide-y divide-gray-100">
                  {dayBills.map(bill => (
                    <BillItem key={bill.id} bill={bill} onEdit={handleEdit} />
                  ))}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* 表单弹窗 */}
      {showForm && (
        <BillFormModal
          bill={editingBill}
          onClose={() => {
            setShowForm(false);
            setEditingBill(undefined);
          }}
        />
      )}

      {/* 筛选弹窗 */}
      {showFilter && (
        <BillFilterModal
          filter={filter}
          onApply={(newFilter: BillFilter) => {
            setFilter(newFilter);
            setShowFilter(false);
          }}
          onClose={() => setShowFilter(false)}
        />
      )}
    </div>
  );
}
