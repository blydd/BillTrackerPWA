// 导入 Google Drive API 类型
/// <reference types="gapi.client.drive-v3" />

// Google Drive API 配置（已配置）
const GOOGLE_DRIVE_CONFIG = {
  apiKey: 'AIzaSyCtWm_TVom890L2igJQlTaPv7NG803XwTo', // 您的 API 密钥
  clientId: '944550060079-1td76f082g50c0au6ma4hrudtvjjujhb.apps.googleusercontent.com', // 您的客户端 ID
  scope: 'https://www.googleapis.com/auth/drive.file'
};

// Google Identity Services 初始化状态
let isGISInitialized = false;
let isSignedIn = false;
let accessToken: string | null = null;

// 等待 Google Identity Services 加载
function waitForGIS(): Promise<void> {
  return new Promise((resolve, reject) => {
    // 如果 google 已经存在，直接返回
    if (typeof google !== 'undefined' && google.accounts) {
      resolve();
      return;
    }

    // 等待 google 加载，最多等待 10 秒
    let attempts = 0;
    const maxAttempts = 100; // 10秒 (100 * 100ms)
    
    const checkGoogle = () => {
      attempts++;
      if (typeof google !== 'undefined' && google.accounts) {
        resolve();
      } else if (attempts >= maxAttempts) {
        reject(new Error('Google Identity Services 脚本加载超时，请检查网络连接'));
      } else {
        setTimeout(checkGoogle, 100);
      }
    };
    
    checkGoogle();
  });
}

// 初始化 Google Identity Services
export async function initializeGoogleDrive(): Promise<void> {
  try {
    if (isGISInitialized) {
      return;
    }

    // 等待 Google Identity Services 加载
    await waitForGIS();

    isGISInitialized = true;
    console.log('Google Drive API 初始化成功');
  } catch (error) {
    console.error('Google Drive API 初始化失败:', error);
    throw error;
  }
}

// 检查是否已登录
export function isGoogleDriveSignedIn(): boolean {
  return isSignedIn && !!accessToken;
}

// 登录 Google Drive
export async function signInToGoogleDrive(): Promise<void> {
  try {
    if (!isGISInitialized) {
      await initializeGoogleDrive();
    }

    return new Promise((resolve, reject) => {
      const tokenClient = google.accounts.oauth2.initTokenClient({
        client_id: GOOGLE_DRIVE_CONFIG.clientId,
        scope: GOOGLE_DRIVE_CONFIG.scope,
        callback: (response: any) => {
          if (response.error) {
            reject(new Error(`登录失败: ${response.error}`));
            return;
          }
          
          accessToken = response.access_token;
          isSignedIn = true;
          console.log('Google Drive 登录成功');
          resolve();
        },
      });

      tokenClient.requestAccessToken();
    });
  } catch (error) {
    console.error('Google Drive 登录失败:', error);
    throw error;
  }
}

// 登出 Google Drive
export async function signOutFromGoogleDrive(): Promise<void> {
  try {
    if (accessToken) {
      google.accounts.oauth2.revoke(accessToken);
    }
    
    accessToken = null;
    isSignedIn = false;
    console.log('Google Drive 登出成功');
  } catch (error) {
    console.error('Google Drive 登出失败:', error);
    throw error;
  }
}

// 获取当前用户信息（简化版）
export function getCurrentUser(): any {
  if (!isSignedIn) {
    return null;
  }
  
  // 返回一个模拟的用户对象
  return {
    getBasicProfile: () => ({
      getEmail: () => '已登录用户'
    })
  };
}

// 使用 REST API 调用 Google Drive
async function callGoogleDriveAPI(endpoint: string, options: RequestInit = {}): Promise<any> {
  if (!accessToken) {
    throw new Error('未登录 Google Drive');
  }

  const response = await fetch(`https://www.googleapis.com/drive/v3${endpoint}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ...options.headers
    }
  });

  if (!response.ok) {
    throw new Error(`API 调用失败: ${response.statusText}`);
  }

  return response.json();
}

// 上传备份文件到 Google Drive
export async function uploadBackupToGoogleDrive(
  fileName: string, 
  content: string
): Promise<string> {
  try {
    if (!isSignedIn || !accessToken) {
      throw new Error('请先登录 Google Drive');
    }

    // 创建文件元数据
    const metadata = {
      name: fileName,
      parents: ['appDataFolder'], // 使用应用数据文件夹，用户不可见
      description: '账单管理 PWA 备份文件'
    };

    // 创建表单数据
    const form = new FormData();
    form.append('metadata', new Blob([JSON.stringify(metadata)], { type: 'application/json' }));
    form.append('file', new Blob([content], { type: 'application/json' }));

    // 上传文件
    const response = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`
      },
      body: form
    });

    if (!response.ok) {
      throw new Error(`上传失败: ${response.statusText}`);
    }

    const result = await response.json();
    console.log('备份文件上传成功:', result.id);
    return result.id;
  } catch (error) {
    console.error('上传备份文件失败:', error);
    throw error;
  }
}

// 从 Google Drive 下载备份文件
export async function downloadBackupFromGoogleDrive(fileId: string): Promise<string> {
  try {
    if (!isSignedIn || !accessToken) {
      throw new Error('请先登录 Google Drive');
    }

    const response = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });

    if (!response.ok) {
      throw new Error(`下载失败: ${response.statusText}`);
    }

    return await response.text();
  } catch (error) {
    console.error('下载备份文件失败:', error);
    throw error;
  }
}

// 列出 Google Drive 中的备份文件
export async function listBackupFiles(): Promise<any[]> {
  try {
    if (!isSignedIn || !accessToken) {
      throw new Error('请先登录 Google Drive');
    }

    const result = await callGoogleDriveAPI('/files?q=' + encodeURIComponent("parents in 'appDataFolder' and name contains '账单备份_'") + '&orderBy=createdTime desc&pageSize=10');
    
    return result.files || [];
  } catch (error) {
    console.error('获取备份文件列表失败:', error);
    throw error;
  }
}

// 删除 Google Drive 中的备份文件
export async function deleteBackupFromGoogleDrive(fileId: string): Promise<void> {
  try {
    if (!isSignedIn || !accessToken) {
      throw new Error('请先登录 Google Drive');
    }

    await callGoogleDriveAPI(`/files/${fileId}`, {
      method: 'DELETE'
    });

    console.log('备份文件删除成功:', fileId);
  } catch (error) {
    console.error('删除备份文件失败:', error);
    throw error;
  }
}

// 检查 Google Drive 是否可用（预配置版本）
export function isGoogleDriveAvailable(): boolean {
  // 检查是否已配置真实的 API 密钥（不是占位符）
  return !!(
    GOOGLE_DRIVE_CONFIG.apiKey && 
    GOOGLE_DRIVE_CONFIG.clientId &&
    !GOOGLE_DRIVE_CONFIG.apiKey.includes('YOUR_') &&
    !GOOGLE_DRIVE_CONFIG.clientId.includes('YOUR_')
  );
}

// 获取用户的 Google Drive 存储空间信息
export async function getGoogleDriveStorageInfo(): Promise<{
  used: string;
  limit: string;
  usedInDrive: string;
}> {
  try {
    if (!isSignedIn || !accessToken) {
      throw new Error('请先登录 Google Drive');
    }

    const result = await callGoogleDriveAPI('/about?fields=storageQuota');
    
    const quota = result.storageQuota;
    return {
      used: quota?.usage || '0',
      limit: quota?.limit || '0',
      usedInDrive: quota?.usageInDrive || '0'
    };
  } catch (error) {
    console.error('获取存储空间信息失败:', error);
    throw error;
  }
}