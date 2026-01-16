import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Bill, BillFilter } from '../models/types';
import { getBills } from '../services/billService';
import BillItem from './BillItem';
import BillFormModal from './BillFormModal';
import { format } from 'date-fns';

interface Props {
  filter: BillFilter;
  title: string;
  onClose: () => void;
}

export default function StatisticsBillListView({ filter, title, onClose }: Props) {
  const [bills, setBills] = useState<Bill[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingBill, setEditingBill] = useState<Bill | undefined>();

  useEffect(() => {
    loadBills();
  }, [filter]);

  async function loadBills() {
    const result = await getBills(filter);
    setBills(result);
  }

  const handleEdit = (bill: Bill) => {
    setEditingBill(bill);
    setShowForm(true);
  };

  const handleFormClose = () => {
    setShowForm(false);
    setEditingBill(undefined);
    loadBills(); // 重新加载数据
  };

  // 按日期分组
  const groupedBills = bills.reduce((groups, bill) => {
    const dateKey = format(bill.date, 'yyyy-MM-dd');
    if (!groups[dateKey]) {
      groups[dateKey] = [];
    }
    groups[dateKey].push(bill);
    return groups;
  }, {} as Record<string, Bill[]>);

  return (
    <div className="fixed inset-0 bg-white z-50 flex flex-col">
      {/* 头部 */}
      <div className="bg-primary-600 text-white shadow-lg">
        <div className="px-4 py-4 flex items-center justify-between">
          <h2 className="text-xl font-bold">{title}</h2>
          <button onClick={onClose} className="p-1 hover:bg-primary-700 rounded">
            <X size={24} />
          </button>
        </div>
      </div>

      {/* 账单列表 */}
      <div className="flex-1 overflow-auto p-4">
        {bills.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            暂无账单记录
          </div>
        ) : (
          <div className="space-y-4">
            {Object.entries(groupedBills).map(([date, dayBills]) => (
              <div key={date} className="bg-white rounded-lg shadow">
                <div className="px-4 py-2 bg-gray-50 border-b">
                  <span className="font-medium">{date}</span>
                  <span className="text-sm text-gray-500 ml-2">
                    ({dayBills.length} 笔)
                  </span>
                </div>
                <div className="divide-y">
                  {dayBills.map(bill => (
                    <BillItem key={bill.id} bill={bill} onEdit={handleEdit} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 表单弹窗 */}
      {showForm && (
        <BillFormModal
          bill={editingBill}
          onClose={handleFormClose}
        />
      )}
    </div>
  );
}
