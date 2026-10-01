# Pensieve

Pensieve 是一个本地优先的 iPhone Obsidian 回忆卡片原型。

当前版本遵循最简单的规则：一篇 Markdown 笔记对应一张卡片。

## 功能

- 通过系统“文件”选择器选择本机或 iCloud Drive 中的 Obsidian 文件夹
- 保存安全书签，下次启动继续读取同一个文件夹
- 递归扫描 `.md`，忽略 `.git` 和 `.obsidian`
- 上下滚动阅读，左划跳过，右划标记重要
- 每处理 8 张新卡片，插入一次随机重要卡片
- 创建本地标签并筛选已标记卡片
- 保存与来源笔记关联的感悟，并标记是否已整合回 Obsidian
- 只读原始 Markdown，不写回 vault

## 运行

1. 使用 Xcode 打开 `Pensieve.xcodeproj`。
2. 选择 `Pensieve` target，在 Signing & Capabilities 中选择自己的 Team。
3. 连接 iPhone，选择真机作为运行目标。
4. 第一次启动时选择 Obsidian vault 文件夹。

使用免费 Personal Team 时，真机描述文件通常需要每 7 天重新签名安装。

## 技术栈

- SwiftUI
- UIKit Document Picker
- Security-scoped bookmark
- `NSFileCoordinator`
- 本地 JSON 状态存储

没有第三方依赖，也不需要服务器。
