<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleetアプリアイコン" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> | <a href="README.en.md">🇺🇸 English</a> | <b>🇯🇵 日本語</b> | <a href="README.zh.md">🇨🇳 中文</a>
</p>

> **GitHubリポジトリを最終コミット日で管理し、次にやることをメモしておき、そのままいつも使っているAIエージェントに任せられるmacOSネイティブアプリ**

Fleetがすることは3つだけです。

1. **最終コミット日でリポジトリを管理** — GitHubのすべてのリポジトリを取得し、最終コミットからの経過日数（`D+XX`）を追跡して、放置期間が長い順に一覧表示します。
2. **次にやることをメモ** — リポジトリごとに「次に直すこと・追加すること」をメモ（バックログ）として残します。
3. **AIにそのまま任せる** — メモをクリックすると、すでに使っているAIエージェントCLI（Claude Code、Codex、Aiderなど）がそのリポジトリのコンテキストでターミナル上ですぐに作業を開始します。

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleetアプリのスクリーンショット" />
</p>

---

## 🌟 主な機能

### 1. 最終コミット日でリポジトリを管理
- **GitHub全リポジトリ同期**: Personal Access Token（PAT）でPublic/Private全リポジトリを取得し、最終コミット／プッシュ日時、コミットメッセージ、言語、スター／フォーク／オープンイシュー数をリアルタイム表示
- **放置日数（Stale Days）とリスクの可視化**: 🟢 正常（Active）・🟡 注意（Warning、デフォルト14日超過）・🔴 放置（Stale、デフォルト30日超過、`D+XX`バッジ表示）の3段階でひと目で把握
- **管理リポジトリの選択＆リスト編集**: 初回取得時にチェックボックスで追跡するリポジトリを直接選択し、サイドバー上部の**`[リスト編集]`**ボタンや右クリックメニュー（**「モニタリング対象から除外／再度含める」**）でいつでも調整可能。除外されたリポジトリはDockバッジや通知からも完全に除外

### 2. 次にやることをメモ（更新バックログ）
- サイドバーでリポジトリをクリックすると、そのリポジトリのメモ（やること）履歴が右側に表示
- タイトル・詳細内容・優先度（低／中／高）を指定して素早くインラインでメモ追加
- カンバンボードまたはリストビューで進行状況（待機中→作業中→完了）を管理、完了チェックや削除にも対応
- ローカルの`Application Support`にJSON形式で安全に永続保存（外部サーバーへの送信なし）

### 3. AIエージェントにそのまま作業を任せる
- メモカードの**`[ 🚀 作業実行 (AI) ]`**ボタン一つで、設定済みのAIエージェントCLI（Claude Code、Codex、Google Antigravity（`agy`）、Cursor、Aider、Goose、OpenHands、またはカスタムCLI）をそのリポジトリのローカルフォルダでターミナル起動
- リポジトリ名・言語・ブランチ・メモのタイトル／内容を組み合わせたプロンプトを自動生成（クリップボードコピーにも対応）
- ローカルリポジトリフォルダの自動検出、手動フォルダ連携にも対応
- 作業が始まるとメモのステータスが`待機中`→`作業中 🚀`にリアルタイムで切り替わり、最終実行日時を記録

### 付加機能
- **macOSネイティブ連携**: 放置基準日を超えたリポジトリ数をDockアイコンのバッジとして表示、放置発生時にシステムバナー通知
- **メニューバーウィジェット**: メインウィンドウを開かなくても、メニューバーから放置状況の確認とクイックメモ追加が可能
- **環境設定（Cmd + ,）**: GitHubトークンの登録・テスト、AIエージェントCLIプリセットとテンプレート設定、放置／注意基準日のスライダー、Dockバッジ・通知のOn/Off、アーカイブ済み／フォークリポジトリのフィルタリング
- **多言語対応（i18n）**: 韓国語／English／日本語／中文（簡体）に完全対応、環境設定からシステム言語とは独立して選択可能

---

## 🏛️ クリーンアーキテクチャ（Clean Architecture）設計

Fleetは、関心の分離とテスト容易性を最大化するため、クリーンアーキテクチャの3層構造を厳格に遵守しています。

```
Sources/Fleet/
├── App/
│   ├── FleetApp.swift           # アプリのエントリーポイント（WindowGroup + MenuBarExtra）
│   └── AppEnvironment.swift           # DI（依存性注入）コンテナ — Data実装を組み立てる唯一の場所
├── Domain/                             # 純粋なビジネスロジック（外部フレームワーク／Data／Presentationに非依存）
│   ├── Entities/
│   │   ├── RepositoryItem.swift       # リポジトリエンティティ
│   │   ├── MemoItem.swift             # メモエンティティ
│   │   ├── StaleStatus.swift          # 放置ステータスとD+dayバッジの計算
│   │   ├── AppSettings.swift          # アプリ環境設定エンティティ
│   │   └── AppLanguage.swift          # 表示言語エンティティ（System/ko/en/ja/zh-Hans）
│   ├── Repositories/                  # プロトコルインターフェース（境界、Dataが実装）
│   │   ├── GitHubRepositoryProtocol.swift
│   │   ├── MemoRepositoryProtocol.swift
│   │   ├── SettingsRepositoryProtocol.swift
│   │   ├── LocalPathRepositoryProtocol.swift
│   │   └── TerminalExecutionServiceProtocol.swift
│   └── UseCases/                      # ユースケース（プロトコルのみを注入される純粋なロジック）
│       ├── FetchRepositoriesUseCase.swift
│       ├── CalculateStaleStatusUseCase.swift
│       ├── ManageMemoUseCase.swift
│       ├── ExecuteAgentTaskUseCase.swift
│       ├── UpdateDockBadgeUseCase.swift
│       └── ScheduleNotificationUseCase.swift
├── Data/                              # 通信および永続化の実装（Domainのプロトコルを実装）
│   ├── DataSources/
│   │   ├── GitHub/ (GitHubAPIService, GitHubDTOs)
│   │   ├── Persistence/ (LocalMemoStorage Actor)
│   │   └── System/ (DockBadgeManager, NotificationManager, TerminalExecutionService)
│   └── Repositories/
│       ├── GitHubRepositoryImpl.swift
│       ├── MemoRepositoryImpl.swift
│       ├── SettingsRepositoryImpl.swift
│       └── LocalPathRepositoryImpl.swift
├── Presentation/                      # SwiftUI + MVVM — DomainのUseCase／Protocolのみを参照
│   ├── ViewModels/
│   │   ├── RepositoryListViewModel.swift
│   │   ├── RepositoryDetailViewModel.swift
│   │   ├── MenuBarViewModel.swift      # メニューバーポップオーバー専用の状態／ロジック（Viewから直接UseCaseを呼び出さない）
│   │   ├── SettingsViewModel.swift
│   │   └── TerminalSessionManager.swift
│   ├── Theme/ (AppTheme — 色／スプリングアニメーション／ボタンスタイルのトークン)
│   └── Views/
│       ├── MainSplitView.swift        # 2ペインスプリットレイアウト＋上部ナビゲーションバー
│       ├── MenuBar/ (MenuBarExtraView)
│       ├── Sidebar/ (SidebarView, RepositoryRowView, RepositorySelectionSheet)
│       ├── Detail/ (RepositoryDetailView, MemoTimelineView, MemoDetailModalView, FileTreeSidebarView)
│       ├── Dashboard/ (RepoHealthDashboardView, AgentWorkflowsView, CliEnvironmentsView)
│       ├── Terminal/ (VSCodeTerminalPanelView)
│       └── Settings/ (SettingsView)
└── Resources/                         # 多言語リソース
    ├── ko.lproj/Localizable.strings
    ├── en.lproj/Localizable.strings
    ├── ja.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

**依存関係ルール（Dependency Rule）の検証**: `Presentation`と`Data`は、`Domain`のEntity／UseCase／Protocolのみを参照し、互いを直接参照することはありません。Data実装（`GitHubRepositoryImpl`など）は`App/AppEnvironment.swift`の1か所でのみ組み立てられて注入され、Viewがこれを直接インスタンス化することはありません。

---

## 🍺 Homebrewでインストール

このリポジトリ自体をHomebrewのタップ（tap）として使用します — 別途`homebrew-*`リポジトリを作る必要はありません。

```bash
brew tap mrKangHo/fleet https://github.com/mrKangHo/Fleet.git
brew install --cask fleet
```

> ⚠️ Fleetはまだコード署名（code signing）と公証（notarization）がされていません。初回起動時にmacOSがアプリをブロックした場合は、Finderで Fleet.app を右クリックして「開く」を選択するか、`xattr -cr /Applications/Fleet.app` を実行してください。現時点ではApple Silicon（arm64）のみ対応しています。

---

## 🚀 ビルド＆実行方法

### 1. Xcodeでプロジェクトを開く（推奨）
```bash
open Fleet.xcodeproj
```

### 2. テストの実行
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

### 3. macOSアプリバンドルのビルドと直接実行
```bash
./scripts/build_app.sh
open Fleet.app
```

---

## 🔑 GitHub Tokenの権限ガイド
非公開リポジトリを含むすべてのリポジトリを取得するには、GitHub PAT作成時に以下の権限が必要です:
- **`repo`**（Full control of private repositories）
