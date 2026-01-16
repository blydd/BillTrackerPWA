import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { Bill, TransactionType } from '../models/types';
import { Trash2, Edit } from 'lucide-react';
import { deleteBill } from '../services/billService';
import { format } from 'date-fns';

interface Props {
  bill: Bill;
  onEdit: (bill: Bill) => void;
}

export default function BillItem({ bill, onEdit }: Props) {
  const categories = useLiveQuery(() => 
    db.categories.where('id').anyOf(bill.categoryIds).toArray()
  , [bill.categoryIds]);

  const owner = useLiveQuery(() => db.owners.get(bill.ownerId), [bill.ownerId]);
  const paymentMethod = useLiveQuery(() => db.paymentMethods.get(bill.paymentMethodId), [bill.paymentMethodId]);

  // 格式化时间显示
  const timeStr = format(new Date(bill.date), 'HH:mm:ss');

  const handleDelete = async () => {
    if (confirm('确定要删除这条账单吗？')) {
      try {
        await deleteBill(bill.id!);
      } catch (error) {
        alert('删除失败：' + (error as Error).message);
      }
    }
  };

  const getAmountColor = () => {
    if (bill.transactionType === TransactionType.INCOME) return 'text-green-600';
    if (bill.transactionType === TransactionType.EXPENSE) return 'text-red-600';
    return 'text-gray-600';
  };

  const getAmountPrefix = () => {
    if (bill.transactionType === TransactionType.INCOME) return '+';
    if (bill.transactionType === TransactionType.EXPENSE) return '-';
    return '';
  };

  const getCategoryColor = (index: number) => {
    const colors = [
      'bg-blue-100 text-blue-700 border-blue-200',
      'bg-purple-100 text-purple-700 border-purple-200',
      'bg-pink-100 text-pink-700 border-pink-200',
      'bg-indigo-100 text-indigo-700 border-indigo-200',
      'bg-cyan-100 text-cyan-700 border-cyan-200',
    ];
    return colors[index % colors.length];
  };

  return (
    <div className="p-3 hover:bg-gray-50 transition-colors">
      {/* 第一行：分类、时间、金额、操作按钮 */}
      <div className="flex items-center justify-between gap-2 mb-1.5">
        <div className="flex items-center gap-1.5 flex-1 min-w-0">
          {categories?.map((cat, index) => (
            <span 
              key={cat.id} 
              className={`inline-block text-xs font-medium px-2 py-0.5 rounded-full border whitespace-nowrap ${getCategoryColor(index)}`}
            >
              {cat.name}
            </span>
          ))}
          <span className="text-xs text-gray-500 whitespace-nowrap">{timeStr}</span>
        </div>
        
        <div className="flex items-center gap-2 flex-shrink-0">
          <span className={`text-base font-bold ${getAmountColor()}`}>
            {getAmountPrefix()}¥{Math.abs(bill.amount).toFixed(2)}
          </span>
          
          <button
            onClick={() => onEdit(bill)}
            className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
            title="编辑"
          >
            <Edit size={16} />
          </button>
          <button
            onClick={handleDelete}
            className="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            title="删除"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </div>
      
      {/* 第二行：归属人、支付方式 */}
      <div className="flex items-center gap-1.5 flex-wrap">
        <span className="inline-block px-2 py-0.5 rounded-md bg-gradient-to-r from-green-100 to-green-200 text-green-800 border border-green-300 font-medium text-xs whitespace-nowrap">
          👤 {owner?.name}
        </span>
        <span className="inline-block px-2 py-0.5 rounded-md bg-gradient-to-r from-purple-100 to-purple-200 text-purple-800 border border-purple-300 font-medium text-xs whitespace-nowrap">
          💳 {paymentMethod?.name}
        </span>
      </div>
      
      {/* 第三行：备注（如果有） */}
      {bill.note && (
        <div className="text-xs text-gray-500 italic mt-1.5">"{bill.note}"</div>
      )}
    </div>
  );
}
