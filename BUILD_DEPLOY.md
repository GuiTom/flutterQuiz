# VitePress 构建和部署指南

## 📦 构建生成 HTML

修改 Markdown 文件后,使用以下命令生成最终的 HTML 内容:

```bash
# 确保使用 Node.js v20+
source ~/.nvm/nvm.sh && nvm use 20.10.0

# 构建生产版本
npm run docs:build
```

构建完成后,所有 HTML 文件将生成在 **`.vitepress/dist/`** 目录下。

---

## 📂 构建输出

- **输出目录**: `.vitepress/dist/`
- **总大小**: ~3.4MB
- **包含内容**:
  - 所有 HTML 页面 (21个页面)
  - 优化后的 CSS 和 JavaScript
  - 所有图片资源
  - 搜索索引

---

## 🚀 部署方式

### 方式 1: 本地预览

在部署前先本地预览构建结果:

```bash
npm run docs:preview
```

访问 `http://localhost:4173/` 查看生产版本

### 方式 2: 部署到 GitHub Pages

1. 在项目根目录创建 `.github/workflows/deploy.yml`:

```yaml
name: Deploy VitePress site to Pages

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 20
      - run: npm ci
      - run: npm run docs:build
      - uses: actions/upload-pages-artifact@v2
        with:
          path: .vitepress/dist
  
  deploy:
    needs: build
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/deploy-pages@v2
        id: deployment
```

2. 在 GitHub 仓库设置中启用 GitHub Pages (Settings → Pages → Source: GitHub Actions)

### 方式 3: 部署到 Vercel

1. 在 Vercel 中导入 GitHub 仓库
2. 配置构建设置:
   - **Build Command**: `npm run docs:build`
   - **Output Directory**: `.vitepress/dist`
   - **Install Command**: `npm install`
3. 点击 Deploy

### 方式 4: 部署到 Netlify

1. 在 Netlify 中导入 GitHub 仓库
2. 配置构建设置:
   - **Build command**: `npm run docs:build`
   - **Publish directory**: `.vitepress/dist`
3. 点击 Deploy site

### 方式 5: 手动部署到任意服务器

将 `.vitepress/dist/` 目录中的所有文件上传到您的 Web 服务器即可。

---

## 🔄 开发流程

### 日常开发

```bash
# 1. 启动开发服务器
source ~/.nvm/nvm.sh && nvm use 20.10.0
npm run docs:dev

# 2. 编辑 Markdown 文件 (实时预览)
# 文件保存后浏览器会自动刷新

# 3. 构建生产版本
npm run docs:build

# 4. 预览生产版本
npm run docs:preview
```

### 添加新页面

1. 在对应的 `Chapter` 目录下创建新的 `.md` 文件
2. 在 `.vitepress/config.mts` 中更新 `sidebar` 配置
3. 重启开发服务器查看效果

---

## ⚠️ 注意事项

1. **Node.js 版本**: 必须使用 Node.js v18 或更高版本 (推荐 v20.10.0)
2. **图片路径**: 在 Markdown 中使用相对路径 `assets/image.png` (不要加 `./`)
3. **构建前检查**: 确保开发服务器运行正常,没有错误
4. **缓存清理**: 如果构建出现问题,删除 `.vitepress/cache` 和 `.vitepress/dist` 后重新构建

---

## 📊 构建统计

- **构建时间**: ~1.5秒
- **总页面数**: 21 页
- **输出大小**: 3.4MB
- **支持的浏览器**: 所有现代浏览器

---

## 🆘 常见问题

### Q: 构建失败提示 "Not supported"
**A**: 检查 Node.js 版本,必须使用 v18+:
```bash
source ~/.nvm/nvm.sh && nvm use 20.10.0
```

### Q: 图片无法加载
**A**: 检查图片路径是否正确,应使用 `assets/image.png` 而不是 `./assets/image.png`

### Q: 修改后没有效果
**A**: 确保开发服务器正在运行,或重新构建生产版本

---

## ✅ 快速命令参考

```bash
# 开发
npm run docs:dev

# 构建
npm run docs:build

# 预览
npm run docs:preview
```
