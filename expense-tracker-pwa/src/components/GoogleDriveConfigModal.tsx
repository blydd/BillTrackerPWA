import { useState, useEffect } from 'react';
import { X, Save, ExternalLink, AlertCircle, CheckCircle } from 'lucide-react';
import { 
  getBackupConfig, 
  saveBackupConfig, 
  type BackupConfig 
} from '../services/universalBackupService';
import { 
  initializeGoogleDrive, 
  isGoogleDriveSignedIn, 
  signInToGoogleDrive,
  signOutFromGoogleDrive,
  getCurrentUser,
  isGoogleDriveConfigured
} from '../services/googleDriveService';

interface GoogleDriveConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfigSaved: () => void;
}

export default function GoogleDriveConfigModal({ 
  isOpen, 
  onClose, 
  onConfigSaved 
}: GoogleDriveConfigModalProps) {
  const [apiKey, setApiKey] = useState('');
  const [clientId, setClientId] = useState('');
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [signedIn, setSignedIn] = useState(false);
  const [currentUser, setCurrentUser] = useState<gapi.auth2.GoogleUser | null>(null);

  useEffect(() => {
    if (isOpen) {
      loadConfig();
      checkSignInStatus();
    }
  }, [isOpen]);

  async function loadConfig() {
    try {
      const config = await getBackupConfig();
      if (config.googleDriveConfig) {
        setApiKey(config.googleDriveConfig.apiKey || '');
        setClientId(config.googleDriveConfig.clientId || '');
      }
    } catch (error) {
      console.error('加载配置失败:', error);
    }
  }

  function checkSignInStatus() {
    const isSignedInNow = isGoogleDriveSignedIn();
    setSignedIn(isSignedInNow);
    if (isSignedInNow) {
      setCurrentUser(getCurrentUser());
    } else {
      setCurrentUser(null);
    }
  }

  async function handleSave() {
    if (!apiKey.trim() || !clientId.trim()) {
      alert('请填写完整的 API 密钥和客户端 ID');
      return;
    }

    setSaving(true);
    try {
      const config = await getBackupConfig();
      const newConfig: BackupConfig = {
        ...config,
        googleDriveConfig: {
          apiKey: apiKey.trim(),
          clientId: clientId.trim(),
          enabled: true
        }
      };

      await saveBackupConfig(newConfig);
      alert('Google Drive 配置保存成功！');
      onConfigSaved();
      onClose();
    } catch (error) {
      alert('保存配置失败：' + (error as Error).message);
    } finally {
      setSaving(false);
    }
  }

  async function handleTestConnection() {
    if (!apiKey.trim() || !clientId.trim()) {
      alert('请先填写 API 密钥和客户端 ID');
      return;
    }

    setTesting(true);
    try {
      await initializeGoogleDrive(apiKey.trim(), clientId.trim());
      await signInToGoogleDrive();
      checkSignInStatus();
      alert('Google Drive 连接测试成功！');
    } catch (error) {
      alert('连接测试失败：' + (error as Error).message);
    } finally {
      setTesting(false);
    }
  }

  async function handleSignOut() {
    try {
      await signOutFromGoogleDrive();
      checkSignInStatus();
      alert('已退出 Google Drive 登录');
    } catch (error) {
      alert('退出登录失败：' + (error as Error).message);
    }
  }

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        {/* 头部 */}
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-xl font-semibold text-gray-800">Google Drive 配置</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        {/* 内容 */}
        <div className="p-6 space-y-6">
          {/* 说明 */}
          <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
            <div className="flex items-start gap-3">
              <AlertCircle size={20} className="text-blue-600 mt-0.5 flex-shrink-0" />
              <div className="text-sm text-blue-800">
                <p className="font-medium mb-2">配置说明</p>
                <p className="mb-2">
                  要使用 Google Drive 备份功能，您需要创建 Google Cloud 项目并获取 API 密钥。
                </p>
                <a
                  href="https://console.cloud.google.com/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-blue-600 hover:text-blue-700 underline"
                >
                  前往 Google Cloud Console
                  <ExternalLink size={14} />
                </a>
              </div>
            </div>
          </div>

          {/* 配置表单 */}
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                API 密钥 (API Key)
              </label>
              <input
                type="text"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="输入您的 Google Drive API 密钥"
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200 transition-all"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                客户端 ID (Client ID)
              </label>
              <input
                type="text"
                value={clientId}
                onChange={(e) => setClientId(e.target.value)}
                placeholder="输入您的 Google Drive 客户端 ID"
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200 transition-all"
              />
            </div>
          </div>

          {/* 连接状态 */}
          {isGoogleDriveConfigured(apiKey, clientId) && (
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  {signedIn ? (
                    <>
                      <CheckCircle size={20} className="text-green-600" />
                      <div>
                        <div className="font-medium text-gray-800">已连接到 Google Drive</div>
                        {currentUser && (
                          <div className="text-sm text-gray-600">
                            {currentUser.getBasicProfile().getEmail()}
                          </div>
                        )}
                      </div>
                    </>
                  ) : (
                    <>
                      <AlertCircle size={20} className="text-orange-600" />
                      <div>
                        <div className="font-medium text-gray-800">未登录</div>
                        <div className="text-sm text-gray-600">需要登录 Google Drive</div>
                      </div>
                    </>
                  )}
                </div>
                
                <div className="flex gap-2">
                  {signedIn ? (
                    <button
                      onClick={handleSignOut}
                      className="px-4 py-2 bg-gray-200 text-gray-700 rounded-xl hover:bg-gray-300 transition-all text-sm"
                    >
                      退出登录
                    </button>
                  ) : (
                    <button
                      onClick={handleTestConnection}
                      disabled={testing}
                      className="px-4 py-2 bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-all text-sm disabled:opacity-50"
                    >
                      {testing ? '连接中...' : '测试连接'}
                    </button>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* 配置步骤 */}
          <div className="bg-gray-50 rounded-xl p-4">
            <h3 className="font-medium text-gray-800 mb-3">配置步骤</h3>
            <ol className="text-sm text-gray-600 space-y-2">
              <li>1. 访问 Google Cloud Console</li>
              <li>2. 创建新项目或选择现有项目</li>
              <li>3. 启用 Google Drive API</li>
              <li>4. 创建凭据（API 密钥和 OAuth 2.0 客户端 ID）</li>
              <li>5. 将凭据信息填入上方表单</li>
              <li>6. 点击"测试连接"验证配置</li>
            </ol>
          </div>
        </div>

        {/* 底部按钮 */}
        <div className="flex items-center justify-end gap-3 p-6 border-t bg-gray-50 rounded-b-2xl">
          <button
            onClick={onClose}
            className="px-6 py-2 text-gray-600 hover:text-gray-800 transition-colors"
          >
            取消
          </button>
          <button
            onClick={handleSave}
            disabled={saving || !apiKey.trim() || !clientId.trim()}
            className="px-6 py-2 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:from-blue-700 hover:to-blue-800 shadow-md transition-all disabled:opacity-50"
          >
            <Save size={18} className="inline mr-2" />
            {saving ? '保存中...' : '保存配置'}
          </button>
        </div>
      </div>
    </div>
  );
}