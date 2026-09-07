<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet 应用图标" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <b>🇨🇳 中文</b>
</p>

> **一款按最后提交日期管理你的 GitHub 仓库、记录接下来要做的事、并直接交给你正在使用的 AI 智能体去完成的原生 macOS 应用**

Fleet 只做三件事。

1. **按最后提交日期管理仓库** — 拉取你所有的 GitHub 仓库，追踪自最后一次提交以来经过的天数（`D+XX`），并优先显示闲置最久的仓库。
2. **记下接下来要做的事** — 为每个仓库记录一条备忘（待办事项），写下接下来要修复或开发的内容。
3. **直接交给 AI 去做** — 点击一条备忘，你已经在用的 AI 智能体 CLI（Claude Code、Codex、Aider 等）就会在终端里针对该仓库直接开始工作。

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet 应用截图" />
</p>

---

## 🌟 主要功能

### 1. 按最后提交日期管理仓库
- **全量 GitHub 仓库同步**：通过个人访问令牌（PAT）获取全部公开/私有仓库，实时显示最新提交/推送时间、提交信息、语言、星标/复刻/未解决 Issue 数
- **闲置天数（Stale Days）与风险可视化**：🟢 正常（Active）· 🟡 警告（Warning，默认超过 14 天）· 🔴 闲置（Stale，默认超过 30 天，显示 `D+XX` 角标）三档一目了然
- **选择要托管的仓库 & 编辑列表**：首次拉取时通过复选框直接选择要追踪的仓库，之后随时可通过侧边栏顶部的**`[编辑列表]`**按钮或右键菜单（**"从监控中排除／重新加入监控"**）调整。被排除的仓库也会从程序坞角标和通知中完全排除

### 2. 记下接下来要做的事（更新待办）
- 在侧边栏点击某个仓库，右侧会显示该仓库的备忘（待办）记录
- 支持快速内联添加备忘：标题、详细内容、优先级（低/中/高）
- 通过看板或列表视图管理进度（待处理 → 进行中 → 完成），支持完成勾选与删除
- 以 JSON 格式安全持久化保存在本地 `Application Support` 目录中——不会发送到任何外部服务器

### 3. 直接交给 AI 智能体去完成
- 点击备忘卡上的**`[ 🚀 执行任务 (AI) ]`**按钮，即可在该仓库的本地文件夹中，用已配置的 AI 智能体 CLI（Claude Code、Codex、Google Antigravity（`agy`）、Cursor、Aider、Goose、OpenHands 或自定义 CLI）打开终端并开始工作
- 自动组装结合仓库名称、语言、分支及备忘标题/内容的提示词（也支持一键复制到剪贴板）
- 支持自动检测本地仓库文件夹，也可手动关联文件夹
- 任务一旦开始，备忘状态会实时从`待处理`切换为`进行中 🚀`，并记录最近一次执行时间

### 附加功能
- **原生 macOS 集成**：将超过闲置阈值的仓库数量以程序坞图标角标显示，出现闲置仓库时发送系统横幅通知
- **菜单栏小组件**：无需打开主窗口，即可在菜单栏查看闲置情况并快速添加备忘
- **偏好设置（Cmd + ,）**：注册/测试 GitHub 令牌、选择 AI 智能体 CLI 预设与模板、调整闲置/警告阈值天数滑块、开关程序坞角标与通知、筛选已归档/复刻仓库
- **多语言支持（i18n）**：完整支持韩语 / English / 日本語 / 中文（简体），可在偏好设置中独立于系统语言进行选择

---

## 🏛️ Clean Architecture（整洁架构）设计

Fleet 严格遵循三层 Clean Architecture，以最大化关注点分离与可测试性。

```
Sources/Fleet/
├── App/
│   ├── FleetApp.swift           # 应用入口（WindowGroup + MenuBarExtra）
│   └── AppEnvironment.swift           # DI（依赖注入）容器 — 唯一组装 Data 层实现的地方
├── Domain/                             # 纯业务逻辑（不依赖任何外部框架、Data 层或 Presentation 层）
│   ├── Entities/
│   │   ├── RepositoryItem.swift       # 仓库实体
│   │   ├── MemoItem.swift             # 备忘实体
│   │   ├── StaleStatus.swift          # 闲置状态与 D+day 角标计算
│   │   ├── AppSettings.swift          # 应用设置实体
│   │   └── AppLanguage.swift          # 显示语言实体（System/ko/en/ja/zh-Hans）
│   ├── Repositories/                  # 协议接口（边界，由 Data 层实现）
│   │   ├── GitHubRepositoryProtocol.swift
│   │   ├── MemoRepositoryProtocol.swift
│   │   ├── SettingsRepositoryProtocol.swift
│   │   ├── LocalPathRepositoryProtocol.swift
│   │   └── TerminalExecutionServiceProtocol.swift
│   └── UseCases/                      # 用例（仅依赖协议的纯逻辑）
│       ├── FetchRepositoriesUseCase.swift
│       ├── CalculateStaleStatusUseCase.swift
│       ├── ManageMemoUseCase.swift
│       ├── ExecuteAgentTaskUseCase.swift
│       ├── UpdateDockBadgeUseCase.swift
│       └── ScheduleNotificationUseCase.swift
├── Data/                              # 网络与持久化实现（实现 Domain 层协议）
│   ├── DataSources/
│   │   ├── GitHub/ (GitHubAPIService, GitHubDTOs)
│   │   ├── Persistence/ (LocalMemoStorage Actor)
│   │   └── System/ (DockBadgeManager, NotificationManager, TerminalExecutionService)
│   └── Repositories/
│       ├── GitHubRepositoryImpl.swift
│       ├── MemoRepositoryImpl.swift
│       ├── SettingsRepositoryImpl.swift
│       └── LocalPathRepositoryImpl.swift
├── Presentation/                      # SwiftUI + MVVM — 仅引用 Domain 层的 UseCase/协议
│   ├── ViewModels/
│   │   ├── RepositoryListViewModel.swift
│   │   ├── RepositoryDetailViewModel.swift
│   │   ├── MenuBarViewModel.swift      # 菜单栏弹出面板专用的状态/逻辑（View 禁止直接调用 UseCase）
│   │   ├── SettingsViewModel.swift
│   │   └── TerminalSessionManager.swift
│   ├── Theme/ (AppTheme — 颜色/弹簧动画/按钮样式令牌)
│   └── Views/
│       ├── MainSplitView.swift        # 双栏分割布局 + 顶部导航栏
│       ├── MenuBar/ (MenuBarExtraView)
│       ├── Sidebar/ (SidebarView, RepositoryRowView, RepositorySelectionSheet)
│       ├── Detail/ (RepositoryDetailView, MemoTimelineView, MemoDetailModalView, FileTreeSidebarView)
│       ├── Dashboard/ (RepoHealthDashboardView, AgentWorkflowsView, CliEnvironmentsView)
│       ├── Terminal/ (VSCodeTerminalPanelView)
│       └── Settings/ (SettingsView)
└── Resources/                         # 多语言资源
    ├── ko.lproj/Localizable.strings
    ├── en.lproj/Localizable.strings
    ├── ja.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

**依赖规则（Dependency Rule）验证**：`Presentation` 层与 `Data` 层仅引用 `Domain` 层的实体/用例/协议，彼此之间从不直接引用。Data 层的具体实现（如 `GitHubRepositoryImpl`）只在 `App/AppEnvironment.swift` 这一处被组装并注入，View 绝不会直接实例化它们。

---

## 🍺 通过 Homebrew 安装

本仓库本身即作为 Homebrew tap 使用——无需另建独立的 `homebrew-*` 仓库。

```bash
brew tap mrKangHo/fleet https://github.com/mrKangHo/Fleet.git
brew install --cask fleet
```

> ⚠️ Fleet 尚未进行代码签名（code signing）与公证（notarization）。若 macOS 在首次启动时阻止运行，请在 Finder 中右键点击 Fleet.app 并选择"打开"，或执行 `xattr -cr /Applications/Fleet.app`。目前仅支持 Apple Silicon（arm64）。

---

## 🚀 构建与运行

### 1. 用 Xcode 打开项目（推荐）
```bash
open Fleet.xcodeproj
```

### 2. 运行测试
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

### 3. 构建 macOS 应用包并直接运行
```bash
./scripts/build_app.sh
open Fleet.app
```

---

## 🔑 GitHub Token 权限指南
若要获取包括私有仓库在内的全部仓库，创建 GitHub PAT 时需要以下权限：
- **`repo`**（Full control of private repositories）
