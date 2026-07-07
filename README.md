# MojuKit

MojuKit 是一个面向 iOS App 的 UIKit 动态页面运行时，以及配套的 Studio、VS Code 插件和预览工程。

它适合把页面结构、样式、请求和部分交互能力放进受控的 JSON / DKML 流程里，让业务侧在保持原生体验的同时快速迭代页面。

## 项目内容

- `MojuKit/`：核心 SDK、预览宿主工程、文档和测试
- `VSCodeExtension/`：DynamicPageKit Studio VS Code 插件
- `StudioApp/`：本地 Studio 相关资源

## 当前能力

- 原生 UIKit 页面渲染
- 图片资源接入
- 网络请求与业务回调
- 动作编排与模板绑定
- `tableView`、`collectionView`、`forEach` 循环能力
- `.dpk` 加密包解码
- `MojuKitPreview` 本地预览工程

## 目录文档

- [接入文档](./MojuKit/Docs/MojuKit-Integration.md)
- [能力支持列表](./MojuKit/Docs/MojuKit-Capability-Support.md)
- [Studio 文档](./MojuKit/Docs/DynamicPageKit-Studio.md)

## 本地开发

Core SDK 和测试都在 `MojuKit/` 目录下。通常的开发顺序是：

1. 修改 SDK 或 Studio
2. 更新文档
3. 跑测试和预览
4. 提交并发布到 GitHub

## 说明

仓库当前同时保留了 MojuKit 运行时和 DynamicPageKit Studio 相关代码，后续会逐步统一命名和文档口径。
