# 快速配置 Google Drive API

## 5分钟快速配置步骤

### 第1步：创建 Google Cloud 项目
1. 访问：https://console.cloud.google.com/
2. 点击顶部的"选择项目" → "新建项目"
3. 项目名称：`BillTrackerPWA`
4. 点击"创建"

### 第2步：启用 Google Drive API
1. 在项目中，点击左侧菜单"API 和服务" → "库"
2. 搜索"Google Drive API"
3. 点击"Google Drive API" → "启用"

### 第3步：创建 API 密钥
1. 点击左侧菜单"API 和服务" → "凭据"
2. 点击"+ 创建凭据" → "API 密钥"
3. 复制生成的 API 密钥（类似：`AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`）
4. 点击"限制密钥"：
   - 应用限制：选择"HTTP 引用站点"
   - 网站限制：添加 `http://localhost:5173/*` 和 `https://bill-tracker-pwa.vercel.app/*`
   - API 限制：选择"Google Drive API"
5. 点击"保存"

### 第4步：创建 OAuth 2.0 客户端 ID
1. 在"凭据"页面，点击"+ 创建凭据" → "OAuth 客户端 ID"
2. 如果提示配置同意屏幕，点击"配置同意屏幕"：
   - 用户类型：选择"外部"
   - 应用名称：`账单管理 PWA`
   - 用户支持电子邮件：您的邮箱
   - 开发者联系信息：您的邮箱
   - 点击"保存并继续" → "保存并继续" → "保存并继续"
3. 返回创建 OAuth 客户端 ID：
   - 应用类型：选择"Web 应用"
   - 名称：`BillTrackerPWA Web Client`
   - 已获授权的 JavaScript 来源：
     - `http://localhost:5173`
     - `https://bill-tracker-pwa.vercel.app`
4. 点击"创建"
5. 复制生成的客户端 ID（类似：`1234567890-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com`）

### 第5步：更新代码配置
在 `expense-tracker-pwa/src/services/googleDriveService.ts` 文件中，将：

```typescript
const GOOGLE_DRIVE_CONFIG = {
  apiKey: 'YOUR_GOOGLE_DRIVE_API_KEY_HERE', // 替换为第3步的 API 密钥
  clientId: 'YOUR_GOOGLE_OAUTH_CLIENT_ID_HERE', // 替换为第4步的客户端 ID
  discoveryDoc: 'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
  scope: 'https://www.googleapis.com/auth/drive.file'
};
```

替换为：

```typescript
const GOOGLE_DRIVE_CONFIG = {
  apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', // 您的真实 API 密钥
  clientId: '1234567890-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com', // 您的真实客户端 ID
  discoveryDoc: 'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
  scope: 'https://www.googleapis.com/auth/drive.file'
};
```

### 第6步：测试功能
1. 保存文件后，开发服务器会自动重新加载
2. 刷新浏览器页面
3. 进入设置 → 数据备份
4. 现在 Google Drive 选项应该显示"一键登录，自动云端备份"
5. 选择 Google Drive 并点击"立即备份"测试

## 常见问题

### Q: API 密钥创建后还是显示"功能开发中"？
A: 请检查：
- 是否正确替换了代码中的占位符
- API 密钥格式是否正确（以 `AIzaSy` 开头）
- 客户端 ID 格式是否正确（以数字开头，以 `.apps.googleusercontent.com` 结尾）

### Q: 点击备份后没有弹出登录窗口？
A: 请检查：
- 浏览器是否阻止了弹窗
- 网络连接是否正常
- 在浏览器开发者工具的控制台中查看错误信息

### Q: 登录后提示"redirect_uri_mismatch"错误？
A: 请检查：
- OAuth 客户端 ID 的"已获授权的 JavaScript 来源"是否包含当前访问的域名
- 确保添加了 `http://localhost:5173` 和 `https://bill-tracker-pwa.vercel.app`

## 安全提醒

- 不要将 API 密钥提交到公开的代码仓库
- 建议使用环境变量来存储敏感信息
- 定期检查 API 使用量，避免超出配额

配置完成后，用户就可以享受一键登录的 Google Drive 云端备份功能了！