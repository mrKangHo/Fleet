<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet 应用图标" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <b>🇨🇳 中文</b>
</p>

> **一款用于追踪 GitHub 仓库闲置天数并管理更新备忘的原生 macOS 应用**

Fleet 会拉取你所有的 GitHub 仓库，追踪自最后一次提交以来经过的天数（`D+XX`），并可以为每个仓库记录接下来要开发的功能或想法——整个应用基于 Clean Architecture 构建。

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet 应用截图" />
</p>

---

## 🌟 主要功能

1. **全量 GitHub 仓库同步**
   - 通过个人访问令牌（PAT）获取全部公开/私有仓库
   - 实时查询最新提交/推送时间及提交信息
   - 显示语言、星标数、复刻（Fork）数、未解决 Issue 数
2. **选择要托管的仓库 & 编辑列表（NEW ⭐️）**
   - **初始仓库选择向导**：首次拉取 GitHub 仓库时会弹出一个表单，通过复选框直接选择要实际托管/追踪的仓库
   - **随时编辑列表**：通过侧边栏顶部的**`[编辑列表]`**按钮，随时重新勾选/取消托管的仓库列表
   - **仓库右键菜单**：右键单击某个仓库，即可立即**“将此仓库从监控中排除（隐藏）”**或**“重新加入监控”**
   - 被排除托管的仓库会从程序坞（Dock）角标数量和系统通知中完全排除，避免不必要的提醒
3. **闲置天数（Stale Days）与风险可视化**
   - 🟢 **正常（Active）**：最近有活动
   - 🟡 **警告（Warning）**：超过设定的警告周期（默认 14 天）
   - 🔴 **闲置（Stale）**：超过设定的闲置周期（默认 30 天，显示 `D+XX` 角标）
4. **按仓库管理更新备忘与路线图**
   - 在侧边栏点击某个仓库，右侧主界面会显示该仓库的备忘记录
   - 支持快速内联添加备忘（标题、详细内容、优先级设置）
   - 支持备忘完成勾选框及删除功能
   - 以 JSON 格式安全持久化保存在本地 `Application Support` 目录中
5. **基于 AI 智能体 CLI 的一键任务执行（NEW 🚀）**
   - 点击备忘卡上的**`[ 🚀 执行任务 (AI) ]`**按钮，即可用已配置的 AI 智能体 CLI（Google `agy`、`claude`、`aider` 等）打开终端并自动开始任务
   - 支持自动检测本地仓库文件夹，也支持手动关联文件夹
   - 自动组装结合仓库名称、语言、分支及备忘标题/内容的智能提示词
   - 支持一键将 AI 提示词复制到剪贴板
   - 实时将备忘状态从`待处理`追踪为`进行中 🚀`，并记录最近一次执行时间
6. **原生 macOS 集成（程序坞角标与系统通知）**
   - 将超过设定阈值（默认 30 天）的**闲置仓库总数以 macOS 程序坞图标角标**形式显示
   - 出现闲置仓库时发送 macOS 系统横幅通知
7. **偏好设置（Cmd + ,）**
   - 注册 GitHub 个人访问令牌并实时测试连接
   - 选择 AI 智能体 CLI 预设（`agy`、`claude`、`aider`、自定义）并配置模板
   - 闲置/警告判定阈值天数滑块
   - 程序坞角标与系统通知的开关切换
   - 已归档（Archived）仓库与复刻（Fork）仓库的筛选选项
8. **多语言支持（i18n，NEW 🌐）**
   - 完整支持韩语 / English / 日本語 / 中文（简体）四种语言
   - 可在偏好设置 > 常规标签页中，独立于系统语言选择应用的显示语言
   - 同时支持跟随 macOS 系统语言的“系统语言”选项

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
brew tap mrKangHo/workmanager https://github.com/mrKangHo/workmanager.git
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
