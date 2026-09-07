<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet app icon" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <b>🇺🇸 English</b> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh.md">🇨🇳 中文</a>
</p>

> **A native macOS app for tracking GitHub repository neglect and managing update-idea memos**

Fleet pulls in all of your GitHub repositories, tracks the days elapsed since the last commit (`D+XX`), and lets you jot down the next feature or idea to build for each repository — all built on a Clean Architecture foundation.

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet app screenshot" />
</p>

---

## 🌟 Key Features

1. **Full GitHub Repository Sync**
   - Fetches all public/private repositories via a Personal Access Token (PAT)
   - Real-time lookup of the latest commit/push date and commit message
   - Displays language, star count, fork count, and open issue count
2. **Repository Selection & List Editing (NEW ⭐️)**
   - **Initial Repository Wizard**: when repositories are first fetched, a sheet pops up letting you check exactly which ones to manage/track
   - **Edit anytime**: use the **`[Edit List]`** button at the top of the sidebar to re-check/uncheck the managed repository list at any time
   - **Right-click context menu**: right-click any repository to instantly **"Exclude this repository from monitoring (hide)"** or **"Re-include in monitoring"**
   - Repositories excluded from management are fully excluded from the Dock badge count and system notifications, avoiding noisy alerts
3. **Stale-Day & Risk Visualization**
   - 🟢 **Active**: recently active
   - 🟡 **Warning**: past the configured warning period (14 days by default)
   - 🔴 **Stale**: past the configured stale period (30 days by default, shown with a `D+XX` badge)
4. **Per-Repository Update Memos & Roadmap Management**
   - Click a repository in the sidebar to see its memo history on the right
   - Quick inline memo creation (title, details, priority)
   - Memo completion checkbox and delete support
   - Safely persisted as JSON in the local `Application Support` directory
5. **One-Click AI Agent CLI Task Execution (NEW 🚀)**
   - Clicking **`[ 🚀 Run Task (AI) ]`** on a memo card opens a terminal with your configured AI Agent CLI (Google `agy`, `claude`, `aider`, etc.) and starts the task automatically
   - Automatically detects the local repository folder, with manual folder linking supported
   - Automatically assembles a smart prompt combining the repository name, language, branch, and memo title/content
   - One-click copy of the AI prompt to the clipboard
   - Tracks memo status from `Pending` → `In Progress 🚀` in real time, recording the last run timestamp
6. **Native macOS Integration (Dock Badge & System Notifications)**
   - Shows the total count of stale repositories past the configured threshold (30 days by default) as a **macOS Dock icon badge**
   - System banner notification when a repository becomes stale
7. **Preferences (Cmd + ,)**
   - Register a GitHub Personal Access Token and test the connection live
   - Choose an AI Agent CLI preset (`agy`, `claude`, `aider`, custom) and configure its template
   - Sliders for the stale/warning threshold days
   - On/off toggles for the Dock badge and system notifications
   - Filtering options for archived and forked repositories
8. **Multi-language Support (i18n, NEW 🌐)**
   - Full support for Korean / English / Japanese / Chinese (Simplified)
   - Choose the app's display language independently of the system language, from Preferences > General
   - A "System Language" option is also available, which follows the macOS system language

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
