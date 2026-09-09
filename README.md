🇰🇷 [한국어](README.md) | 🇺🇸 [English](README.en.md) | 🇯🇵 [日本語](README.ja.md) | 🇨🇳 [中文](README.zh.md)

<p align="center">
  <img src="docs/icon.png" width="120" alt="Fleet 앱 아이콘" />
</p>

<h1 align="center">Fleet (macOS)</h1>


> **내 GitHub 저장소들을 마지막 커밋일 기준으로 관리하고, 할 일을 메모해두었다가, 내가 쓰는 AI 에이전트에게 바로 맡기는 macOS 네이티브 앱**

Fleet가 하는 일은 크게 네 가지입니다.

1. **마지막 커밋일 기준 저장소 관리** — 내 GitHub 저장소들을 모두 가져와 마지막 커밋 이후 며칠이 지났는지(`D+XX`)를 추적하고, 오래 방치된 순으로 한눈에 보여줍니다.
2. **할 일 메모** — 저장소별로 "다음에 뭘 고칠지/추가할지"를 메모(백로그)로 남겨둡니다.
3. **AI로 바로 작업 수행** — 메모를 클릭하면 이미 쓰고 있는 AI 에이전트 CLI(Claude Code, Codex, Aider 등)가 터미널에서 그 저장소 컨텍스트로 바로 작업을 시작합니다.
4. **음성으로 묻고 시키기** — 마이크 버튼(⌘⇧J) 한 번으로 방치 현황 브리핑, 저장소 열기, 메모 현황 조회를 말로 처리하고, 정해진 명령이 아니어도 자유롭게 말을 걸면 AI가 자연스럽게 대답합니다.

<p align="center">
  <img src="docs/screenshot.png" width="900" alt="Fleet 앱 스크린샷" />
</p>

---

## 🌟 주요 기능

### 1. 마지막 커밋일 기준 저장소 관리
- **GitHub 전체 저장소 동기화**: Personal Access Token(PAT)으로 Public/Private 저장소를 모두 가져와 최종 커밋/푸시 일시, 커밋 메시지, 언어, 스타/포크/오픈 이슈 수를 실시간 조회
- **방치일(Stale Days) 및 위험도 시각화**: 🟢 정상(Active) · 🟡 주의(Warning, 기본 14일 초과) · 🔴 방치(Stale, 기본 30일 초과, `D+XX` 뱃지) 3단계로 한눈에 파악
- **관리할 저장소 선택 & 목록 수정**: 처음 가져올 때 체크박스로 추적할 저장소를 직접 선택하고, 사이드바 상단 **`[목록 수정]`** 버튼이나 우클릭 메뉴(**"모니터링 제외/포함"**)로 언제든 다시 조정. 제외된 저장소는 Dock 뱃지·알림에서도 완전히 빠짐

### 2. 할 일 메모 (업데이트 백로그)
- 사이드바에서 저장소를 클릭하면 그 저장소의 메모(할 일) 기록이 오른쪽 화면에 표시
- 제목, 상세 내용, 우선순위(낮음/보통/높음)를 지정해 빠르게 인라인으로 메모 추가
- 칸반 보드 또는 리스트 뷰로 진행 상태(대기 중 → 작업 중 → 완료)를 관리, 완료 체크·삭제 지원
- 로컬 `Application Support`에 JSON으로 안전하게 영속 저장 (외부 서버 전송 없음)

### 3. AI 에이전트로 바로 작업 수행
- 메모 카드의 **`[ 🚀 작업수행 (AI) ]`** 버튼 하나로, 이미 설정해 둔 AI Agent CLI(Claude Code, Codex, Google Antigravity(`agy`), Cursor, Aider, Goose, OpenHands 또는 커스텀 CLI)를 그 저장소 로컬 폴더에서 터미널로 실행
- 저장소 이름·언어·브랜치·메모 제목/내용을 조합한 프롬프트를 자동으로 만들어 전달 (클립보드 복사도 지원)
- 로컬 저장소 폴더 자동 감지, 수동 폴더 연결도 가능
- 작업이 시작되면 메모 상태가 `대기 중` → `작업 중 🚀`으로 실시간 전환되고 최근 실행 일시가 기록됨

### 4. 음성 어시스턴트 (Voice Assistant)
- **탭하여 말하기**: 메인 창 상단 마이크 버튼이나 단축키 **`⌘⇧J`**로 전체화면 오버레이를 띄우고 바로 말하기 시작, 침묵이 감지되면(~1.2초) 자동으로 듣기 종료
- **음성 명령**: "브리핑해줘"(전체 방치 현황), "OO 저장소 열어줘", "상태 알려줘", "메모 현황 알려줘" — 이름을 지정하지 않으면 모든 저장소를 합산해서 답변
- **자유 대화**: 정해진 명령이 아닌 인사·잡담·일반 질문도 Claude CLI가 실제로 답변을 생성해서 자연스럽게 응답 (환경설정에서 켜고 끌 수 있음, CLI 없으면 고정 키워드 인식으로 자동 대체)
- **음성 엔진 선택**: 기본은 Apple 내장 음성(Speech/AVSpeechSynthesizer, 무료·온디바이스). 로컬에 [MeloTTS](https://github.com/myshell-ai/MeloTTS)를 설치하면 완전 오프라인 로컬 엔진으로 전환 가능 (환경설정 → 음성 어시스턴트)
- **보이스 · 말하기 속도 커스텀**: 설치된 한국어 보이스 중 선택(Enhanced 보이스 우선 자동 선택 지원) 및 속도 슬라이더 제공, 미리 듣기 지원
- 마이크·음성 인식 권한이 필요하며, 최초 사용 시 시스템 권한 요청이 표시됩니다

### 부가 기능
- **macOS 네이티브 연동**: 방치 기준일을 넘긴 저장소 수를 Dock 아이콘 뱃지로 표시, 방치 발생 시 시스템 배너 알림
- **메뉴바 위젯**: 메인 창을 열지 않고도 메뉴바에서 방치 현황 확인과 빠른 메모 추가 가능
- **환경설정 (Cmd + ,)**: GitHub 토큰 등록/테스트, AI Agent CLI 프리셋 및 템플릿 설정, 방치/주의 기준일 슬라이더, Dock 뱃지·알림 On/Off, Archived/Fork 저장소 필터링
- **다국어 지원 (i18n)**: 한국어 / English / 日本語 / 中文(简体) 완전 지원, 시스템 언어와 무관하게 환경설정에서 직접 선택 가능

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
│   │   ├── AppLanguage.swift          # 표시 언어 엔티티 (System/ko/en/ja/zh-Hans)
│   │   ├── VoiceIntent.swift          # 음성 명령 의도 (briefing/openRepository/conversation 등)
│   │   └── SpeechVoiceOption.swift    # 선택 가능한 TTS 보이스 옵션
│   ├── Repositories/                  # 프로토콜 인터페이스 (경계, Data가 구현)
│   │   ├── GitHubRepositoryProtocol.swift
│   │   ├── MemoRepositoryProtocol.swift
│   │   ├── SettingsRepositoryProtocol.swift
│   │   ├── LocalPathRepositoryProtocol.swift
│   │   ├── TerminalExecutionServiceProtocol.swift
│   │   ├── SpeechRecognitionServiceProtocol.swift
│   │   ├── SpeechSynthesisServiceProtocol.swift
│   │   └── VoiceIntentClassifierServiceProtocol.swift
│   └── UseCases/                      # 유스케이스 (프로토콜만 주입받는 순수 로직)
│       ├── FetchRepositoriesUseCase.swift
│       ├── CalculateStaleStatusUseCase.swift
│       ├── ManageMemoUseCase.swift
│       ├── ExecuteAgentTaskUseCase.swift
│       ├── UpdateDockBadgeUseCase.swift
│       ├── ScheduleNotificationUseCase.swift
│       └── ManageVoiceCommandUseCase.swift  # 음성 의도 파싱 및 응답 문장 조립
├── Data/                              # 통신 및 영속성 구현체 (Domain 프로토콜을 구현)
│   ├── DataSources/
│   │   ├── GitHub/ (GitHubAPIService, GitHubDTOs)
│   │   ├── Persistence/ (LocalMemoStorage Actor)
│   │   ├── System/ (DockBadgeManager, NotificationManager, TerminalExecutionService)
│   │   └── Voice/ (SpeechRecognitionService, SpeechSynthesisService, MeloTTSSpeechSynthesisService, ClaudeVoiceIntentClassifierService)
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
│   │   ├── TerminalSessionManager.swift
│   │   └── VoiceAssistantViewModel.swift  # 듣기/응답 상태, 의도 해석, TTS 호출 오케스트레이션
│   ├── Theme/ (AppTheme — 색상/스프링 애니메이션/버튼 스타일 토큰)
│   └── Views/
│       ├── MainSplitView.swift        # 2단 Split Layout + 상단 내비게이션 바
│       ├── MenuBar/ (MenuBarExtraView)
│       ├── Sidebar/ (SidebarView, RepositoryRowView, RepositorySelectionSheet)
│       ├── Detail/ (RepositoryDetailView, MemoTimelineView, MemoDetailModalView, FileTreeSidebarView)
│       ├── Dashboard/ (RepoHealthDashboardView, AgentWorkflowsView, CliEnvironmentsView)
│       ├── Terminal/ (VSCodeTerminalPanelView)
│       ├── Voice/ (VoiceAssistantOverlayView)
│       └── Settings/ (SettingsView)
└── Resources/                         # 다국어 리소스 및 번들 스크립트
    ├── ko.lproj/Localizable.strings
    ├── en.lproj/Localizable.strings
    ├── ja.lproj/Localizable.strings
    ├── zh-Hans.lproj/Localizable.strings
    └── melo_tts_server.py             # MeloTTS 로컬 합성 서버 (선택 설치 시 백그라운드로 실행)
```

**의존성 규칙 (Dependency Rule) 검증**: `Presentation`과 `Data`는 오직 `Domain`의 Entity/UseCase/Protocol만 바라보며, 서로를 직접 참조하지 않습니다. Data 구현체(`GitHubRepositoryImpl` 등)는 `App/AppEnvironment.swift` 한 곳에서만 조립되어 주입되고, View는 절대 이를 직접 인스턴스화하지 않습니다.

---

## 🍺 Homebrew로 설치하기

이 저장소를 그대로 Homebrew 탭(tap)으로 사용합니다 — 별도의 `homebrew-*` 저장소 없이 바로 설치할 수 있습니다.

```bash
brew tap mrKangHo/tap
brew install fleet

# 또는 전용 tap
brew tap mrKangHo/fleet https://github.com/mrKangHo/Fleet.git
brew install --cask fleet
```

> ⚠️ Fleet은 아직 코드 서명(code signing) 및 공증(notarization)이 되어있지 않습니다. 첫 실행 시 macOS가 앱 실행을 차단하면 Finder에서 Fleet.app을 우클릭 후 "열기"를 선택하거나 `xattr -cr /Applications/Fleet.app` 명령을 실행하세요. 현재는 Apple Silicon(arm64)만 지원합니다.

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