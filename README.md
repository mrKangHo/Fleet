<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet 앱 아이콘" />
</p>

<h1 align="center">Fleet (macOS)</h1>

<p align="center">
  <b>🇰🇷 한국어</b> | <a href="README.en.md">🇺🇸 English</a> | <a href="README.ja.md">🇯🇵 日本語</a> | <a href="README.zh.md">🇨🇳 中文</a>
</p>

> **GitHub 저장소 방치일 추적 및 업데이트 기능 메모 관리 macOS 네이티브 앱**

Fleet는 GitHub의 모든 저장소를 가져와 마지막 커밋 기준 경과 일수(`D+XX`)를 추적하고, 각 저장소별로 다음에 업데이트할 기능과 아이디어를 메모할 수 있는 클린 아키텍처 기반의 macOS 앱입니다.

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet 앱 스크린샷" />
</p>

---

## 🌟 주요 기능

1. **GitHub 전체 저장소 동기화**
   - Personal Access Token(PAT)을 통한 Public/Private 전체 저장소 조회
   - 최종 커밋/푸시 일시 및 커밋 메시지 실시간 조회
   - 언어, 스타 수, 포크 수, 오픈 이슈 수 표시
2. **관리할 저장소 선택 & 목록 수정 (NEW ⭐️)**
   - **초기 저장소 선택 마법사**: GitHub 저장소를 처음 가져올 때 팝업되는 시트에서 실제로 관리/추적할 저장소를 체크박스로 직접 선택
   - **언제든 목록 수정**: 사이드바 상단의 **`[목록 수정]`** 버튼을 통해 관리 저장소 목록을 언제든 다시 체크/해제 가능
   - **저장소 우클릭 메뉴(ContextMenu)**: 개별 저장소를 우클릭하여 **"이 저장소 모니터링 제외(숨기기)"** 또는 **"다시 모니터링에 포함"** 즉시 설정
   - 관리에서 제외된 저장소는 독(Dock) 뱃지 숫자 카운트 및 시스템 알림에서 완전히 제외되어 불필요한 알림 방지
3. **방치일(Stale Days) 및 위험도 시각화**
   - 🟢 **정상(Active)**: 최근 활동 중
   - 🟡 **주의(Warning)**: 설정된 주의 기간 초과 (기본 14일)
   - 🔴 **방치(Stale)**: 설정된 방치 기간 초과 (기본 30일, `D+XX` 뱃지 노출)
4. **저장소별 업데이트 기능 메모 & 로드맵 관리**
   - 사이드바에서 저장소를 클릭하면 우측 메인 화면에 해당 저장소의 메모 기록 노출
   - 빠른 인라인 메모 추가 (제목, 상세 내용, 우선순위 설정)
   - 메모 완료 체크박스 및 삭제 기능 지원
   - 로컬 `Application Support`에 안전하게 JSON 형태로 영속 저장
5. **AI Agent CLI 기반 원클릭 작업수행 (NEW 🚀)**
   - 메모 카드의 **`[ 🚀 작업수행 (AI) ]`** 버튼 클릭 시, 설정된 AI Agent CLI(Google `agy`, `claude`, `aider` 등)로 터미널을 열고 자동 작업 시작
   - 로컬 저장소 폴더 자동 감지 및 수동 폴더 연결 지원
   - 저장소 이름, 언어, 브랜치, 메모 제목/내용을 결합한 스마트 프롬프트 자동 조립
   - AI 프롬프트 클립보드 원클릭 복사 지원
   - 메모 상태를 `대기 중` -> `작업 중 🚀`으로 실시간 추적 및 최근 실행 일시 기록
5. **macOS 네이티브 연동 (Dock 뱃지 & 시스템 알림)**
   - 설정한 기준일(기본 30일)을 초과한 **방치 저장소 총 개수를 macOS Dock 아이콘 뱃지**로 표시
   - 방치 저장소 발생 시 macOS 시스템 배너 알림
6. **환경설정 (Cmd + ,)**
   - GitHub Personal Access Token 등록 및 실시간 연동 테스트
   - AI Agent CLI 프리셋 선택 (`agy`, `claude`, `aider`, 커스텀) 및 템플릿 설정
   - 방치/주의 판정 기준일 슬라이더
   - Dock 뱃지 및 시스템 알림 On/Off 토글
   - 보관된 저장소(Archived) 및 포크(Fork) 필터링 옵션
7. **다국어 지원 (i18n, NEW 🌐)**
   - 한국어 / English / 日本語 / 中文(简体) 4개 언어 완전 지원
   - 환경설정 > 일반 탭에서 시스템 언어와 무관하게 앱 표시 언어를 직접 선택 가능
   - macOS 시스템 언어를 그대로 따르는 "시스템 언어" 옵션도 지원

---

## 🏛️ 클린 아키텍처 (Clean Architecture) 설계

Fleet는 관심사 분리와 테스트 용이성을 극대화하기 위해 클린 아키텍처 3계층을 엄격히 준수합니다.

```
Sources/Fleet/
├── App/
│   ├── FleetApp.swift           # 앱 진입점 (WindowGroup + MenuBarExtra)
│   └── AppEnvironment.swift           # DI (의존성 주입) 컨테이너 — 오직 여기서만 Data 구현체를 조립
├── Domain/                             # 순수 비즈니스 로직 (외부 프레임워크/Data/Presentation 종속성 없음)
│   ├── Entities/
│   │   ├── RepositoryItem.swift       # 저장소 엔티티
│   │   ├── MemoItem.swift             # 메모 엔티티
│   │   ├── StaleStatus.swift          # 방치 상태 및 D+day 뱃지 계산
│   │   ├── AppSettings.swift          # 앱 환경설정 엔티티
│   │   └── AppLanguage.swift          # 표시 언어 엔티티 (System/ko/en/ja/zh-Hans)
│   ├── Repositories/                  # 프로토콜 인터페이스 (경계, Data가 구현)
│   │   ├── GitHubRepositoryProtocol.swift
│   │   ├── MemoRepositoryProtocol.swift
│   │   ├── SettingsRepositoryProtocol.swift
│   │   ├── LocalPathRepositoryProtocol.swift
│   │   └── TerminalExecutionServiceProtocol.swift
│   └── UseCases/                      # 유스케이스 (프로토콜만 주입받는 순수 로직)
│       ├── FetchRepositoriesUseCase.swift
│       ├── CalculateStaleStatusUseCase.swift
│       ├── ManageMemoUseCase.swift
│       ├── ExecuteAgentTaskUseCase.swift
│       ├── UpdateDockBadgeUseCase.swift
│       └── ScheduleNotificationUseCase.swift
├── Data/                              # 통신 및 영속성 구현체 (Domain 프로토콜을 구현)
│   ├── DataSources/
│   │   ├── GitHub/ (GitHubAPIService, GitHubDTOs)
│   │   ├── Persistence/ (LocalMemoStorage Actor)
│   │   └── System/ (DockBadgeManager, NotificationManager, TerminalExecutionService)
│   └── Repositories/
│       ├── GitHubRepositoryImpl.swift
│       ├── MemoRepositoryImpl.swift
│       ├── SettingsRepositoryImpl.swift
│       └── LocalPathRepositoryImpl.swift
├── Presentation/                      # SwiftUI + MVVM — Domain의 UseCase/Protocol만 참조
│   ├── ViewModels/
│   │   ├── RepositoryListViewModel.swift
│   │   ├── RepositoryDetailViewModel.swift
│   │   ├── MenuBarViewModel.swift      # 메뉴바 팝오버 전용 상태/로직 (View에서 UseCase 직접 호출 금지)
│   │   ├── SettingsViewModel.swift
│   │   └── TerminalSessionManager.swift
│   ├── Theme/ (AppTheme — 색상/스프링 애니메이션/버튼 스타일 토큰)
│   └── Views/
│       ├── MainSplitView.swift        # 2단 Split Layout + 상단 내비게이션 바
│       ├── MenuBar/ (MenuBarExtraView)
│       ├── Sidebar/ (SidebarView, RepositoryRowView, RepositorySelectionSheet)
│       ├── Detail/ (RepositoryDetailView, MemoTimelineView, MemoDetailModalView, FileTreeSidebarView)
│       ├── Dashboard/ (RepoHealthDashboardView, AgentWorkflowsView, CliEnvironmentsView)
│       ├── Terminal/ (VSCodeTerminalPanelView)
│       └── Settings/ (SettingsView)
└── Resources/                         # 다국어 리소스
    ├── ko.lproj/Localizable.strings
    ├── en.lproj/Localizable.strings
    ├── ja.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

**의존성 규칙 (Dependency Rule) 검증**: `Presentation`과 `Data`는 오직 `Domain`의 Entity/UseCase/Protocol만 바라보며, 서로를 직접 참조하지 않습니다. Data 구현체(`GitHubRepositoryImpl` 등)는 `App/AppEnvironment.swift` 한 곳에서만 조립되어 주입되고, View는 절대 이를 직접 인스턴스화하지 않습니다.

---

## 🚀 실행 및 빌드 방법

### 1. Xcode로 프로젝트 열기 (추천)
```bash
open Fleet.xcodeproj
```

### 2. 테스트 실행
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

### 3. macOS App 번들 빌드 및 직접 실행
```bash
./scripts/build_app.sh
open Fleet.app
```

---

## 🔑 GitHub Token 권한 가이드
Private 저장소를 포함하여 모든 저장소를 조회하려면 GitHub PAT 생성 시 아래 권한이 필요합니다:
- **`repo`** (Full control of private repositories)
