<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet app icon" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <b>🇺🇸 English</b> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh.md">🇨🇳 中文</a>
</p>

> **A native macOS app that manages your GitHub repositories by last commit date, keeps memos of what to do next, and hands that work straight to the AI agent you already use**

Fleet does three things.

1. **Track repositories by last commit date** — pulls in all your GitHub repositories, tracks how many days have passed since the last commit (`D+XX`), and surfaces the most neglected ones first.
2. **Jot down what's next** — leave a memo (backlog item) per repository for the next thing to fix or build.
3. **Hand it to your AI, instantly** — click a memo and your existing AI agent CLI (Claude Code, Codex, Aider, etc.) starts working on it in a terminal, already scoped to that repository.

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet app screenshot" />
</p>

---

## 🌟 Key Features

### 1. Track repositories by last commit date
- **Full GitHub Repository Sync**: fetches all public/private repositories via a Personal Access Token (PAT), with real-time latest commit/push date, commit message, language, stars, forks, and open issues
- **Stale-Day & Risk Visualization**: 🟢 Active · 🟡 Warning (past 14 days by default) · 🔴 Stale (past 30 days by default, shown with a `D+XX` badge) at a glance
- **Repository Selection & List Editing**: check exactly which repositories to track when they're first fetched, then adjust anytime via the sidebar's **`[Edit List]`** button or right-click ("Exclude/Re-include in monitoring"). Excluded repositories are fully left out of the Dock badge and notifications too

### 2. Memos for what's next (Update Backlog)
- Click a repository in the sidebar to see its memo (to-do) history on the right
- Quick inline memo creation with title, details, and priority (Low/Medium/High)
- Manage progress (Pending → In Progress → Done) in a Kanban board or list view, with completion checkboxes and delete
- Safely persisted as JSON in the local `Application Support` directory — nothing sent to an external server

### 3. Hand tasks to your AI agent, instantly
- One click on **`[ 🚀 Run Task (AI) ]`** on a memo card launches your configured AI Agent CLI (Claude Code, Codex, Google Antigravity (`agy`), Cursor, Aider, Goose, OpenHands, or a custom CLI) in a terminal, right in that repository's local folder
- Automatically assembles a prompt combining the repository name, language, branch, and memo title/content (clipboard copy also supported)
- Automatically detects the local repository folder, with manual folder linking supported
- Once started, the memo status flips from `Pending` → `In Progress 🚀` in real time, recording the last run timestamp

### Extras
- **Native macOS integration**: shows the count of stale repositories as a Dock icon badge, with a system banner notification when one becomes stale
- **Menu bar widget**: check stale status and add a quick memo without opening the main window
- **Preferences (Cmd + ,)**: register/test your GitHub token, pick an AI Agent CLI preset and template, tune the stale/warning threshold sliders, toggle the Dock badge and notifications, filter archived/forked repositories
- **Multi-language support (i18n)**: full Korean / English / Japanese / Chinese (Simplified) support, selectable independently of the system language in Preferences

---

## 🏛️ Clean Architecture Design

Fleet strictly follows the three-layer Clean Architecture to maximize separation of concerns and testability.

```
Sources/Fleet/
├── App/
│   ├── FleetApp.swift           # App entry point (WindowGroup + MenuBarExtra)
│   └── AppEnvironment.swift           # DI container — the only place Data implementations are assembled
├── Domain/                             # Pure business logic (no dependency on frameworks, Data, or Presentation)
│   ├── Entities/
│   │   ├── RepositoryItem.swift       # Repository entity
│   │   ├── MemoItem.swift             # Memo entity
│   │   ├── StaleStatus.swift          # Stale status & D+day badge calculation
│   │   ├── AppSettings.swift          # App settings entity
│   │   └── AppLanguage.swift          # Display language entity (System/ko/en/ja/zh-Hans)
│   ├── Repositories/                  # Protocol interfaces (the boundary Data implements)
│   │   ├── GitHubRepositoryProtocol.swift
│   │   ├── MemoRepositoryProtocol.swift
│   │   ├── SettingsRepositoryProtocol.swift
│   │   ├── LocalPathRepositoryProtocol.swift
│   │   └── TerminalExecutionServiceProtocol.swift
│   └── UseCases/                      # Use cases — pure logic that only depends on protocols
│       ├── FetchRepositoriesUseCase.swift
│       ├── CalculateStaleStatusUseCase.swift
│       ├── ManageMemoUseCase.swift
│       ├── ExecuteAgentTaskUseCase.swift
│       ├── UpdateDockBadgeUseCase.swift
│       └── ScheduleNotificationUseCase.swift
├── Data/                              # Networking & persistence implementations (implement Domain protocols)
│   ├── DataSources/
│   │   ├── GitHub/ (GitHubAPIService, GitHubDTOs)
│   │   ├── Persistence/ (LocalMemoStorage actor)
│   │   └── System/ (DockBadgeManager, NotificationManager, TerminalExecutionService)
│   └── Repositories/
│       ├── GitHubRepositoryImpl.swift
│       ├── MemoRepositoryImpl.swift
│       ├── SettingsRepositoryImpl.swift
│       └── LocalPathRepositoryImpl.swift
├── Presentation/                      # SwiftUI + MVVM — references only Domain's UseCases/Protocols
│   ├── ViewModels/
│   │   ├── RepositoryListViewModel.swift
│   │   ├── RepositoryDetailViewModel.swift
│   │   ├── MenuBarViewModel.swift      # State/logic dedicated to the menu bar popover (Views never call UseCases directly)
│   │   ├── SettingsViewModel.swift
│   │   └── TerminalSessionManager.swift
│   ├── Theme/ (AppTheme — color, spring-animation, and button-style tokens)
│   └── Views/
│       ├── MainSplitView.swift        # Two-pane split layout + top navigation bar
│       ├── MenuBar/ (MenuBarExtraView)
│       ├── Sidebar/ (SidebarView, RepositoryRowView, RepositorySelectionSheet)
│       ├── Detail/ (RepositoryDetailView, MemoTimelineView, MemoDetailModalView, FileTreeSidebarView)
│       ├── Dashboard/ (RepoHealthDashboardView, AgentWorkflowsView, CliEnvironmentsView)
│       ├── Terminal/ (VSCodeTerminalPanelView)
│       └── Settings/ (SettingsView)
└── Resources/                         # Localization resources
    ├── ko.lproj/Localizable.strings
    ├── en.lproj/Localizable.strings
    ├── ja.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

**Dependency Rule verification**: `Presentation` and `Data` only ever reference `Domain`'s entities, use cases, and protocols — never each other directly. Concrete Data implementations (`GitHubRepositoryImpl`, etc.) are assembled and injected in exactly one place, `App/AppEnvironment.swift`; Views never instantiate them directly.

---

## 🍺 Install via Homebrew

This repository doubles as its own Homebrew tap — no separate `homebrew-*` repo needed.

```bash
brew tap mrKangHo/fleet https://github.com/mrKangHo/Fleet.git
brew install --cask fleet
```

> ⚠️ Fleet is not yet code-signed or notarized. If macOS blocks it on first launch, right-click Fleet.app in Finder and choose "Open", or run `xattr -cr /Applications/Fleet.app`. Apple Silicon (arm64) only for now.

---

## 🚀 Build & Run

### 1. Open the project in Xcode (recommended)
```bash
open Fleet.xcodeproj
```

### 2. Run tests
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

### 3. Build the macOS app bundle and run it directly
```bash
./scripts/build_app.sh
open Fleet.app
```

---

## 🔑 GitHub Token Permission Guide
To fetch all repositories, including private ones, your GitHub PAT needs the following scope:
- **`repo`** (Full control of private repositories)
