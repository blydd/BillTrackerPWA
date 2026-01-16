import { useState } from 'react';
import { Plus, Edit, Trash2, X, ChevronUp, ChevronDown } from 'lucide-react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../services/db';
import { Owner } from '../models/types';

export default function OwnerManagementView() {
  const [showForm, setShowForm] = useState(false);
  const [editingOwner, setEditingOwner] = useState<Owner | undefined>();
  const [name, setName] = useState('');

  const owners = useLiveQuery(() => 
    db.owners.orderBy('sortOrder').toArray()
  , []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!name.trim()) {
      alert('请输入归属人名称');
      return;
    }

    try {
      if (editingOwner?.id) {
        // 更新
        await db.owners.update(editingOwner.id, {
          name: name.trim()
        });
      } else {
        // 新增
        const maxOrder = owners?.reduce((max, o) => Math.max(max, o.sortOrder), -1) || -1;
        
        await db.owners.add({
          name: name.trim(),
          sortOrder: maxOrder + 1,
          createdAt: new Date()
        });
      }
      
      resetForm();
    } catch (error) {
      alert('保存失败：' + (error as Error).message);
    }
  };

  const handleEdit = (owner: Owner) => {
    setEditingOwner(owner);
    setName(owner.name);
    setShowForm(true);
  };

  const handleDelete = async (owner: Owner) => {
    if (!confirm(`确定要删除「${owner.name}」吗？\n\n注意：该归属人的支付方式和账单也会受影响。`)) {
      return;
    }

    try {
      // 检查是否有关联的账单
      const billCount = await db.bills.where('ownerId').equals(owner.id!).count();
      if (billCount > 0) {
        alert(`无法删除：该归属人还有 ${billCount} 条账单记录`);
        return;
      }

      // 检查是否有关联的支付方式
      const pmCount = await db.paymentMethods.where('ownerId').equals(owner.id!).count();
      if (pmCount > 0) {
        alert(`无法删除：该归属人还有 ${pmCount} 个支付方式`);
        return;
      }

      await db.owners.delete(owner.id!);
    } catch (error) {
      alert('删除失败：' + (error as Error).message);
    }
  };

  const resetForm = () => {
    setName('');
    setEditingOwner(undefined);
    setShowForm(false);
  };

  const handleMoveUp = async (owner: Owner, index: number) => {
    if (index === 0 || !owners) return;
    
    const prevOwner = owners[index - 1];
    
    try {
      await db.transaction('rw', db.owners, async () => {
        await db.owners.update(owner.id!, { sortOrder: prevOwner.sortOrder });
        await db.owners.update(prevOwner.id!, { sortOrder: owner.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  const handleMoveDown = async (owner: Owner, index: number) => {
    if (!owners || index === owners.length - 1) return;
    
    const nextOwner = owners[index + 1];
    
    try {
      await db.transaction('rw', db.owners, async () => {
        await db.owners.update(owner.id!, { sortOrder: nextOwner.sortOrder });
        await db.owners.update(nextOwner.id!, { sortOrder: owner.sortOrder });
      });
    } catch (error) {
      alert('移动失败：' + (error as Error).message);
    }
  };

  return (
    <div className="p-4 space-y-4">
      {/* 添加按钮 */}
      <button
        onClick={() => setShowForm(true)}
        className="w-full flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-primary-600 to-primary-700 text-white rounded-xl hover:from-primary-700 hover:to-primary-800 shadow-lg transition-all"
      >
        <Plus size={20} />
        <span className="font-medium">添加归属人</span>
      </button>

      {/* 归属人列表 */}
      <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
        {!owners || owners.length === 0 ? (
          <div className="p-12 text-center">
            <div className="text-5xl mb-3">👥</div>
            <div className="text-gray-500">暂无归属人</div>
          </div>
        ) : (
          owners.map((owner, index) => (
            <div 
              key={owner.id} 
              className={`p-4 flex items-center justify-between hover:bg-gradient-to-r hover:from-green-50 hover:to-transparent transition-all ${
                index !== owners.length - 1 ? 'border-b' : ''
              }`}
            >
              <span className="font-semibold text-gray-800">{owner.name}</span>
              <div className="flex gap-2">
                <button
                  onClick={() => handleMoveUp(owner, index)}
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
                  onClick={() => handleMoveDown(owner, index)}
                  disabled={index === owners.length - 1}
                  className={`p-2 rounded-lg transition-colors ${
                    index === owners.length - 1
                      ? 'text-gray-300 cursor-not-allowed'
                      : 'text-gray-600 hover:bg-gray-100'
                  }`}
                  title="下移"
                >
                  <ChevronDown size={18} />
                </button>
                <button
                  onClick={() => handleEdit(owner)}
                  className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                  title="编辑"
                >
                  <Edit size={18} />
                </button>
                <button
                  onClick={() => handleDelete(owner)}
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
            <div className="bg-gradient-to-r from-green-600 to-green-700 text-white px-6 py-4 flex items-center justify-between rounded-t-2xl">
              <h2 className="text-xl font-bold">
                {editingOwner ? '编辑归属人' : '添加归属人'}
              </h2>
              <button onClick={resetForm} className="p-1 hover:bg-white/20 rounded-lg transition-colors">
                <X size={24} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-semibold mb-3 text-gray-700">归属人名称</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-green-500 focus:ring-2 focus:ring-green-200 transition-all"
                  placeholder="请输入归属人名称"
                  required
                />
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
                  className="flex-1 py-3 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-xl hover:from-green-700 hover:to-green-800 font-medium shadow-lg transition-all"
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
