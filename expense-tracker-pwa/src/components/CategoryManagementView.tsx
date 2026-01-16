import { useState } from 'react';
import { Plus, Edit, Trash2, X, ChevronUp, ChevronDown } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { BillCategory, TransactionType } from '../models/types';

export default function CategoryManagementView() {
  const [selectedTab, setSelectedTab] = useState<TransactionType>(TransactionType.EXPENSE);
  const [showForm, setShowForm] = useState(false);
  const [editingCategory, setEditingCategory] = useState<BillCategory | undefined>();
  const [name, setName] = useState('');
  const [transactionType, setTransactionType] = useState<TransactionType>(TransactionType.EXPENSE);

  const categories = useLiveQuery(() => db.categories.toArray(), []);

  const filteredCategories = categories
    ?.filter(c => c.transactionType === selectedTab)
    .sort((a, b) => a.sortOrder - b.sortOrder) || [];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!name.trim()) {
      alert('请输入类型名称');
      return;
    }

    try {
      if (editingCategory?.id) {
        await db.categories.update(editingCategory.id, {
          name: name.trim(),
          transactionType
        });
      } else {
        const maxOrder = categories
          ?.filter(c => c.transactionType === transactionType)
          .reduce((max, c) => Math.max(max, c.sortOrder), -1) || -1;
        
        await db.categories.add({
          name: name.trim(),
          transactionType,
          sortOrder: maxOrder + 1,
          createdAt: new Date()
        });
      }
      
      resetForm();
    } catch (error) {
      alert('保存失败：' + (error as Error).message);
    }
  };

  const handleEdit = (category: BillCategory) => {
    setEditingCategory(category);
    setName(category.name);
    setTransactionType(category.transactionType);
    setShowForm(true);
  };

  const handleDelete = async (category: BillCategory) => {
    if (!confirm(`确定要删除「${category.name}」吗？`)) {
      return;
    }

    try {
      await db.categories.delete(category.id!);
    } catch (error) {
      alert('删除失败：' + (error as Error).message);
    }
  };

  const resetForm = () => {
    setName('');
    setTransactionType(TransactionType.EXPENSE);
    setEditingCategory(undefined);
    setShowForm(false);
  };

  const handleMoveUp = async (category: BillCategory, index: number) => {
    if (index === 0) return;
    
    const prevCategory = filteredCategories[index - 1];
    
    try {
      await db.transaction('rw', db.categories, async () => {
        await db.categories.update(category.id!, { sortOrder: prevCategory.sortOrder });
        await db.categories.update(prevCategory.id!, { sortOrder: category.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  const handleMoveDown = async (category: BillCategory, index: number) => {
    if (index === filteredCategories.length - 1) return;
    
    const nextCategory = filteredCategories[index + 1];
    
    try {
      await db.transaction('rw', db.categories, async () => {
        await db.categories.update(category.id!, { sortOrder: nextCategory.sortOrder });
        await db.categories.update(nextCategory.id!, { sortOrder: category.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  const transactionTypeOptions = [
    { value: TransactionType.EXPENSE, label: '支出' },
    { value: TransactionType.INCOME, label: '收入' },
    { value: TransactionType.EXCLUDED, label: '不计入' }
  ];

  return (
    <div className="p-4 space-y-4">
      {/* Tab 切换 */}
      <div className="flex gap-3">
        {transactionTypeOptions.map(type => (
          <button
            key={type.value}
            onClick={() => setSelectedTab(type.value)}
            className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
              selectedTab === type.value
                ? type.value === 'expense'
                  ? 'border-red-500 bg-gradient-to-br from-red-50 to-red-100 text-red-700 shadow-md'
                  : type.value === 'income'
                  ? 'border-green-500 bg-gradient-to-br from-green-50 to-green-100 text-green-700 shadow-md'
                  : 'border-gray-500 bg-gradient-to-br from-gray-50 to-gray-100 text-gray-700 shadow-md'
                : 'border-gray-300 hover:border-gray-400 hover:bg-gray-50'
            }`}
          >
            {type.label}
          </button>
        ))}
      </div>

      {/* 添加按钮 */}
      <button
        onClick={() => {
          setTransactionType(selectedTab);
          setShowForm(true);
        }}
        className="w-full flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 shadow-lg transition-all"
      >
        <Plus size={20} />
        <span className="font-medium">添加类型</span>
      </button>

      {/* 类型列表 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        {filteredCategories.length === 0 ? (
          <div className="p-12 text-center">
            <div className="text-5xl mb-3">📋</div>
            <div className="text-gray-500">
              暂无{transactionTypeOptions.find(t => t.value === selectedTab)?.label}类型
            </div>
          </div>
        ) : (
          filteredCategories.map((category, index) => (
            <div 
              key={category.id} 
              className={`p-4 flex items-center justify-between hover:bg-gradient-to-r hover:from-primary-50 hover:to-transparent transition-all ${
                index !== filteredCategories.length - 1 ? 'border-b' : ''
              }`}
            >
              <span className="font-semibold text-gray-800">{category.name}</span>
              <div className="flex gap-2">
                <button
                  onClick={() => handleMoveUp(category, index)}
                  disabled={index === 0}
                  className={`p-2 rounded-lg transition-colors ${
                    index === 0
                      ? 'text-gray-300 cursor-not-allowed'
                      : 'text-gray-600 hover:bg-gray-100'
                  }`}
                  title="上移"
                >
                  <ChevronUp size={18} />
                </button>
                <button
                  onClick={() => handleMoveDown(category, index)}
                  disabled={index === filteredCategories.length - 1}
                  className={`p-2 rounded-lg transition-colors ${
                    index === filteredCategories.length - 1
                      ? 'text-gray-300 cursor-not-allowed'
                      : 'text-gray-600 hover:bg-gray-100'
                  }`}
                  title="下移"
                >
                  <ChevronDown size={18} />
                </button>
                <button
                  onClick={() => handleEdit(category)}
                  className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                  title="编辑"
                >
                  <Edit size={18} />
                </button>
                <button
                  onClick={() => handleDelete(category)}
                  className="p-2 text-red-600 hover:bg-red-100 rounded-lg transition-colors"
                  title="删除"
                >
                  <Trash2 size={18} />
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* 表单弹窗 */}
      {showForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl">
            <div className="bg-gradient-to-r from-primary-600 to-primary-700 text-white px-6 py-4 flex items-center justify-between rounded-t-2xl">
              <h2 className="text-xl font-bold">
                {editingCategory ? '编辑类型' : '添加类型'}
              </h2>
              <button onClick={resetForm} className="p-1 hover:bg-white/20 rounded-lg transition-colors">
                <X size={24} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">类型名称</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-200 transition-all"
                  placeholder="请输入类型名称"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">交易类型</label>
                <div className="flex gap-2">
                  {transactionTypeOptions.map(type => (
                    <button
                      key={type.value}
                      type="button"
                      onClick={() => setTransactionType(type.value)}
                      className={`flex-1 py-3 rounded-xl border-2 font-medium transition-all ${
                        transactionType === type.value
                          ? type.value === 'expense'
                            ? 'border-red-500 bg-gradient-to-br from-red-50 to-red-100 text-red-700 shadow-md'
                            : type.value === 'income'
                            ? 'border-green-500 bg-gradient-to-br from-green-50 to-green-100 text-green-700 shadow-md'
                            : 'border-gray-500 bg-gradient-to-br from-gray-50 to-gray-100 text-gray-700 shadow-md'
                          : 'border-gray-300 hover:border-gray-400'
                      }`}
                    >
                      {type.label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={resetForm}
                  className="flex-1 py-3 border-2 border-gray-300 rounded-xl hover:bg-gray-50 font-medium transition-all"
                >
                  取消
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 font-medium shadow-lg transition-all"
                >
                  保存
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
