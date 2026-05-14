# SayCal — 프로젝트 현황 (STATUS)

> 최종 업데이트: 2026-05-14 (v5 — Sprint 3 진입점 확장 완료)
> 작성자: PM (자동 생성, 코드/커밋/Attack-doc 기반)
> 브랜치: `main` · 최신 커밋: `95f2bb2 Add tests for recent events loading, deletion, and error states`
> 동봉 문서: `ATTACK.md` (출시 전 공격 리뷰)

---

## 0. v5 변경 요약 — Sprint 3 클로즈 (P2-2 디퍼)

**Sprint 3 진입점 확장 3개 (P2-1/3/4) 처리.** Siri·Spotlight 진입, 캘린더 0개 EmptyState, 일정 목록/삭제까지 들어왔다. P2-2(다국어)는 한국어 단일 시장 결정으로 명시적 디퍼.

- **P2-1 App Intents**: `AddScheduleIntent` + `SayCalShortcutsProvider` — "Hey Siri, SayCal에 일정 추가 내일 3시 회의"로 앱 외부에서 등록 가능. 추출/생성 UseCase 재사용, 한국어 dialog 응답.
- **P2-3 EmptyState**: 캘린더 설정에서 쓰기 가능 캘린더 0개일 때 가이드 UI + "캘린더 앱 열기" 버튼.
- **P2-4 일정 목록**: `RecentEventsFeature/View` — 선택 캘린더의 -7일~+30일 이벤트를 일별로 그룹화, swipe로 삭제/캘린더 열기. `FetchUpcomingEventsUseCase` + `DeleteEventUseCase` 신설.
- **P2-2 다국어 분리**: ⏳ 한국어 단일 시장으로 결정, App Store 출시 시점에 한 줄 카피만 영어 번역 (코드 변경 불필요).
- 테스트 78건 (Sprint 2 종료 시 73건 → 5건 추가, RecentEventsFeatureTests)

이전 변경(v4)의 Sprint 1/2 결과는 그대로 유지.

---

## 1. 한 줄 정의

**자연어(텍스트·음성)로 말하면 iOS 캘린더에 일정이 자동으로 추가되는 앱.**

> 예: "이번주 토요일 3시 강남역" → 토요일 15:00 / 장소 "강남역" 으로 캘린더 이벤트 생성.

---

## 2. 핵심 가치 제안 (Value Prop)

| 차원 | 정의 |
|---|---|
| 1차 가치 | **확신을 주는 빠른 저장** — 저장 전 사용자 검토 시트, 잘못된 입력에 대한 실패 메시지 분리, 권한 거부 복구 경로 |
| 2차 가치 | 온디바이스 AI · 음성 우선 — 모델 미가용/실패 시 정규식 fallback이 대체 |

> 캘린더 앱은 사용자의 하루를 관리하는 도구다. 잘못 저장된 일정 1건 = 신뢰 붕괴 = 삭제. "빠르지만 가끔 틀리는 앱"이 가장 위험한 형태다.

---

## 3. 타깃 사용자 & 핵심 시나리오

| 사용자 유형 | 시나리오 |
|---|---|
| 직장인 | 회의 끝나고 통화하며 "다음주 화요일 2시 회사 미팅" |
| 학생 | 강의 중 빠르게 "내일 오후 9시 스터디" |
| 부모 | 운전 중 음성으로 "이번주 금요일 7시 학부모 모임" |

**Golden Path (v5)**: 첫 실행 시 온보딩 3-step → 메인 진입 → 한 문장 발화/입력 → **AI 또는 정규식 파싱**(제목/날짜/시간/장소/길이/알림/반복 7필드) → **확인/수정 시트** → 저장 → **결과 알림** + "캘린더에서 열기" 버튼.

**Alternate entry paths (v5)**:
- Siri/Spotlight: "Hey Siri, SayCal에 일정 추가 내일 3시 회의" → 확인 시트 없이 즉시 저장 + 한국어 dialog 응답
- 단축어 앱: `AddScheduleIntent` 매크로로 모든 자동화 흐름에서 호출 가능
- 일정 목록: nav bar 목록 버튼 → 최근 일정 확인/삭제/캘린더 진입

---

## 4. 기술 스택

| 항목 | 선택 |
|---|---|
| 플랫폼 | iOS 26.0+ (Bundle: `com.-jay.cal.SayCal`) |
| UI | SwiftUI |
| 상태관리 | The Composable Architecture (TCA) 1.24.1 |
| 빌드 시스템 | Tuist 4.38.2 (`.mise.toml` 핀) |
| 자연어 파싱 (1차) | Apple `FoundationModels` (on-device, `@Generable`/`@Guide`) |
| 자연어 파싱 (fallback) | 자체 `RegexScheduleParser` — 한국어 상대/절대 날짜 + 시간 |
| 캘린더 연동 | `EventKit` (`EKEventStore`, 쓰기 가능 캘린더 필터 + stale ID fallback) |
| 음성 인식 | `Speech` + `AVFoundation` (ko-KR `SFSpeechRecognizer`) |
| 영속화 | `UserDefaults` — 선택된 캘린더 ID + 온보딩 완료 플래그 |
| 다국어 | `en`, `ko` 등록 / 실제 카피 한국어 하드코딩 (부채, P2-2) |

---

## 5. 아키텍처 개요

```
SayCalApp
   │
   ├──► OnboardingView (첫 실행만)
   │     └─► OnboardingFeature (TCA)
   │           └─► RequestPermissionsUseCase ──► EventKit / Speech / AVAudio
   │
   └──► ContentView (메인)
         └─► AddScheduleFeature (TCA)
               │
               ├──► ParseScheduleUseCase
               │     ├─► LanguageModelSession (FoundationModels) [1차]
               │     └─► RegexScheduleParser [fallback]
               │
               ├──► ConfirmScheduleFeature (저장 전 검토)
               │     └─► ConfirmScheduleView
               │
               ├──► CreateCalendarEventUseCase
               │     └─► EKEventStore + 쓰기 가능 필터 + stale fallback
               │
               └──► SpeechRecognitionUseCase
                     └─► AVAudioEngine + SFSpeechRecognizer

CalendarSettingsView (sheet)
   └─► CalendarSettingsFeature
         └─► FetchCalendarsUseCase (쓰기 가능 필터)
```

- **DI**: TCA `@Dependency` + `DependencyKey`로 UseCase 주입 → 테스트 시 mock 교체 (현재 5종 UseCase 모두 mock 가능).
- **레이어**: View / Reducer / UseCase 3-레이어. 외부 SDK 호출은 모두 UseCase에 격리.

---

## 6. 구현 완료 기능

| # | 기능 | 커밋 | 비고 |
|---|---|---|---|
| 1 | Tuist 프로젝트 설정 | `741a6bf` | xcodeproj는 gitignore |
| 2 | TCA 의존성 도입 | `73e759d`, `fdc52a4` | |
| 3 | "일정 추가" 메인 UI | `fdc52a4` | |
| 4 | 추가 버튼 enable/disable | `48c68ba` | |
| 5 | FoundationModels 일정 파싱 | `0b3dd20`, `e94d069`, `da471a0` | 주간 날짜 사전 계산 |
| 6 | EventKit 이벤트 생성 | `786ca5b` | |
| 7 | 음성 입력 (ko-KR STT) | `75d3f35` | partial result 스트리밍 |
| 8 | 로딩 UI 처리 | `4394704`, `74e8095` | |
| 9 | 캘린더 선택 설정 | `de701f7` | UserDefaults 저장 |
| 10 | **STATUS/ATTACK 문서** | `0c95a47` | 제품 현황 + 출시 전 공격 리뷰 |
| 11 | **저장 전 확인 시트** | `9f614b3` | `ConfirmScheduleFeature/View` |
| 12 | **5종 에러 카테고리** | `9f614b3` | `ScheduleError` + 알림 UI |
| 13 | **쓰기 가능 캘린더 필터 + stale fallback** | `9f614b3` | `CreateCalendarEventUseCase` + `FetchCalendarsUseCase` |
| 14 | **이벤트 길이 선택** (30/60/90/120/180) | `9f614b3` | 1시간 고정 제거 |
| 15 | **정규식 파서 fallback** | `2db9d5b` | `RegexScheduleParser` |
| 16 | **첫 실행 온보딩 3-step** | `80ff3a3` | `OnboardingFeature/View` + `RequestPermissionsUseCase` |
| 17 | **테스트 베이스라인 48건** | `b11954b`, `bd3e136`, `e95f3ae` | Reducer/Parser/State |

---

## 7. 데이터 모델

```swift
struct ParsedSchedule {
    var title: String
    var date: String              // "yyyy-MM-dd"
    var time: String              // "HH:mm" (빈 문자열이면 종일)
    var location: String
    var durationMinutes: Int = 0          // 0 = 미지정, UI에서 60분 기본 적용
    var alarmOffsetMinutes: Int = -1      // -1 = 알람 없음, 0 = 정시, N = N분 전
    var recurrence: Recurrence = .none
}

enum Recurrence: String { case none, daily, weekly, monthly, yearly }
```

> 모델은 `@Generable`로 위 7개 필드를 한 번에 추출. 정규식 fallback은 date/time/duration/recurrence 4개를 보완.

---

## 8. 권한

| 권한 | 이유 | 키 | 거부 시 복구 경로 |
|---|---|---|---|
| 캘린더 풀 액세스 | 이벤트 생성 | `NSCalendarsFullAccessUsageDescription` | 온보딩 사전 설명 + 실패 시 "설정 열기" |
| 음성 인식 | 발화 → 텍스트 | `NSSpeechRecognitionUsageDescription` | 온보딩 사전 설명 + 실패 시 "설정 열기" |
| 마이크 | 오디오 입력 | `NSMicrophoneUsageDescription` | 온보딩 사전 설명 + 실패 시 "설정 열기" |

**온보딩에서 사전 동의** → 거부해도 메인 진입 가능, 실제 사용 시점에 카테고리별 메시지로 안내.

---

## 9. 갭 / 리스크

### 9.1 실패면 매트릭스 (구현 완료, v4에서 F6 추가)

| 카테고리 | 트리거 | 사용자 메시지 | 다음 행동 | 구현 |
|---|---|---|---|---|
| F1. 파싱 실패 | 모델 + 정규식 모두 date 미추출 | "일정을 이해하지 못했어요" | "확인" | ✅ |
| F2. 모델 가용성 | 모델 실패 + 정규식 미추출 | "이 기기에서는 자동 분석을 사용할 수 없어요" | "확인" | ✅ |
| F3. 캘린더 권한 | `requestFullAccessToEvents` 거부 | "캘린더 권한이 필요해요" | "설정 열기" 버튼 | ✅ |
| F4. 캘린더 저장 | stale ID / 쓰기 불가 / 저장 예외 | "캘린더에 저장하지 못했어요" | "캘린더 변경" 버튼 (설정 시트) | ✅ |
| F5. 음성 인식 | 권한 거부 / 미가용 | "음성 인식을 사용할 수 없어요" | "설정 열기" 버튼 | ✅ |
| F6. 다중 일정 | 쉼표/"그리고" + 시각 ≥2 사전 감지 | "여러 일정이 감지됐어요" | "확인" (사용자가 분리 입력) | ✅ |

### 9.2 P0 — 출시 차단급 (전부 해소)

| ID | 항목 | 상태 |
|---|---|---|
| P0-1 | 파싱 결과 확인/수정 UI | ✅ `ConfirmScheduleFeature/View` |
| P0-2 | 실패 피드백 5종 분리 | ✅ `ScheduleError` + 알림 |
| P0-3 | 권한 거부 복구 플로우 + 온보딩 | ✅ `OnboardingFeature` + 알림 액션 |
| P0-4 | 선택 캘린더 stale 검증 | ✅ `CreateCalendarEventUseCase` fallback |
| P0-5 | 쓰기 가능 캘린더 필터 | ✅ `Fetch/CreateCalendarEventUseCase` |
| P0-6 | FoundationModels 실패 fallback | ✅ `RegexScheduleParser` |
| P0-7 | 핵심 Reducer/UseCase 테스트 | ✅ 48건 |

### 9.3 P1 — 핵심 사용성 (Sprint 2 클로즈)

| ID | 항목 | 근거 | 상태 |
|---|---|---|---|
| P1-1 | duration 자동 파싱 | ATTACK §4 | ✅ `@Generable durationMinutes` + 정규식 |
| P1-2 | 반복 일정 | ATTACK §5 | ✅ `Recurrence` enum + `EKRecurrenceRule` |
| P1-3 | 알람/리마인더 | ATTACK §6 | ✅ `alarmOffsetMinutes` + `EKAlarm` |
| P1-4 | 온보딩 화면 | ATTACK §7 | ✅ (Sprint 1에서 처리) |
| P1-5 | 다중 일정 정책 | ATTACK §9 | ✅ 사전 감지 후 F6으로 거부 |
| P1-6 | 저장 후 캘린더 진입 | ATTACK §11 | ✅ "캘린더에서 열기" (`calshow:` 딥링크) |
| P1-7 | 음성 UX 단계 분리 | ATTACK §12 | ✅ `Phase` enum + 단계 캡션 |

### 9.4 P2 — 확장 (Sprint 3 클로즈)

| ID | 항목 | 상태 |
|---|---|---|
| P2-1 | App Intents · Siri · 단축어 | ✅ `AddScheduleIntent` + `SayCalShortcutsProvider` |
| P2-2 | 다국어 카피 분리 | ⏳ 한국어 단일 시장 결정 (출시 시 App Store 메타데이터만 영어 번역) |
| P2-3 | 캘린더 0개 사용자 EmptyState | ✅ `CalendarSettingsView` 가이드 |
| P2-4 | 일정 목록/삭제 진입점 | ✅ `RecentEventsFeature/View` (편집은 캘린더 딥링크로 위임) |

---

## 10. 출시 차단 기준 (Release Blockers)

| # | 기준 | 상태 |
|---|---|---|
| 1 | 저장 전 파싱 결과 확인/수정 UI | ✅ |
| 2 | 실패 5종(F1~F5) 메시지 분리 | ✅ |
| 3 | 권한 거부 복구 플로우 | ✅ |
| 4 | 선택 캘린더 유효성/쓰기 가능 검증 | ✅ |
| 5 | duration 처리 (최소 사용자 선택 가능) | ✅ |
| 6 | `AddScheduleFeature` 주요 상태 전이 테스트 | ✅ |
| 7 | `ParseScheduleUseCase` 날짜/시간 테스트 | ✅ (정규식 23건) |

**결과: 출시 차단 게이트 모두 해제.**

---

## 11. 신뢰 모델 (Trust Model)

```
1. 권한 요청  →  사용자가 왜 필요한지 안다           ✅ 온보딩 3-step
2. 입력      →  사용자가 무엇이 인식됐는지 본다       ✅ Phase 캡션 (듣고/분석/저장)
3. 검토      →  사용자가 저장 전 결과를 확인/수정한다  ✅ ConfirmScheduleView (7필드 편집)
4. 저장      →  사용자가 어디에 저장됐는지 본다       ✅ 저장 알림 + 캘린더 딥링크
5. 복구      →  실패해도 다음 행동이 명확하다        ✅ 6종 카테고리별 액션
```

5단계 모두 구현 완료.

---

## 12. 로드맵

### Sprint 1 — Trust Foundation ✅ 완료
- P0-1 ~ P0-7 전부 해제. 출시 차단 게이트 클리어.

### Sprint 2 — 일정 풍부화 ✅ 완료
- P1-1 ~ P1-7 전부 해제. 자연어 1문장이 7필드(제목/날짜/시간/장소/길이/알림/반복)로 추출되고, 사용자는 확인 시트에서 모두 편집한다.

### Sprint 3 — 진입점 다양화 ✅ 부분 완료
- P2-1 App Intents ✅ / P2-3 EmptyState ✅ / P2-4 일정 목록 ✅
- P2-2 다국어 분리 ⏳ — 한국어 단일 시장 결정으로 디퍼

### Sprint 4+ — 백로그 (출시 후 후보)
- 위젯 (홈 화면에서 마이크 즉시 입력)
- 일정 인라인 편집 (현재는 캘린더 앱으로 위임)
- 반복 종료 조건 사용자 입력
- 위치를 `EKStructuredLocation` 지도 좌표로 확장
- 영어 번역 (해외 출시 결정 시)

---

## 13. 테스트 전략

### 13.1 매트릭스 (구현 완료)

| 대상 | 종류 | 테스트 수 | 검증 항목 |
|---|---|---|---|
| `RegexScheduleParser` | 단위 | 35 | 날짜 12 + 시간 9 + duration 7 + 반복 5 + 다중 감지 4 + 종합 |
| `AddScheduleFeature` | TCA `TestStore` | 10 | 파싱 성공/실패, 빈 date, F3/F4/F6 라우팅, 확인 시트 저장/취소, phase 동작 |
| `OnboardingFeature` | TCA `TestStore` | 9 | step 전이, 권한 일괄 요청, 건너뛰기, 뒤로 |
| `RecentEventsFeature` | TCA `TestStore` | 5 | 로드 성공/실패, 삭제 성공/실패, 에러 dismiss |
| `ScheduleError` mapping | 단위 | 6 | CalendarError/SpeechError 매핑 + 미지 에러 fallback |
| `ConfirmScheduleFeature.State` | 단위 | 8 | resolved 라운드트립, 종일/시간 분기, duration/alarm/recurrence 전파 |

**총 78 테스트 / 6 suite / 모두 통과 (xcodebuild test 5초 이하).**

### 13.2 커버 안 된 영역 (Sprint 2/3 후보)
- `CreateCalendarEventUseCase` — 모킹 가능하나 mock 미작성 (EventKit 의존성 격리 필요)
- `FetchCalendarsUseCase` — 동일
- `ParseScheduleUseCase` liveValue의 모델+정규식 머지 로직 — `LanguageModelSession`이 mock 불가하여 통합 테스트 필요

---

## 14. 오픈 퀘스천

- **다중 일정 정책**: "9시 회의, 11시 점심" 같은 입력을 지원할지 거부할지.
- **반복 일정 종료 조건**: "매주 월요일"이 영원히 반복인지, 종료 시점을 사용자에게 물을지.
- **위치 정보 활용**: `location` 문자열을 `EKStructuredLocation` (지도 좌표)으로 확장할지.
- **다국어 범위**: 한국어 전용으로 좁힐지, en/ja 등 확장할지.
- **duration 자동화 vs 수동**: 모델이 잘 잡으면 자동, 못 잡으면 사용자가 선택 — 또는 항상 사용자 확인.

---

## 15. 파일 인벤토리

### 앱 (`SayCal/`)
```
SayCalApp.swift                  — App 엔트리 + 온보딩/메인 분기
ContentView.swift                — 메인 화면 (3개 sheet: 설정/목록/확인)
AddScheduleFeature.swift         — 메인 Reducer + ParsedSchedule + Recurrence
ParseScheduleUseCase.swift       — FoundationModels + 정규식 fallback 머지
RegexScheduleParser.swift        — 한국어 날짜/시간/길이/반복 + 다중 감지
ConfirmScheduleFeature.swift     — 저장 전 편집 Reducer (7필드)
ConfirmScheduleView.swift        — 확인 시트
ScheduleError.swift              — F1~F6 카테고리
CreateCalendarEventUseCase.swift — EventKit 저장 + 알람 + 반복
FetchCalendarsUseCase.swift      — 캘린더 목록 (쓰기 가능만)
FetchUpcomingEventsUseCase.swift ← v5 신규 — 일정 목록 조회
DeleteEventUseCase.swift         ← v5 신규 — 이벤트 삭제
SpeechRecognitionUseCase.swift   — STT 스트리밍
RequestPermissionsUseCase.swift  — 권한 3종 일괄 요청
OnboardingFeature.swift          — 온보딩 3-step Reducer
OnboardingView.swift             — 온보딩 UI
CalendarSettingsFeature.swift    — 캘린더 선택 Reducer
CalendarSettingsView.swift       — 캘린더 선택 시트 + EmptyState
CalendarInfo.swift               — 캘린더 모델
EventInfo.swift                  ← v5 신규 — 이벤트 모델
RecentEventsFeature.swift        ← v5 신규 — 일정 목록 Reducer
RecentEventsView.swift           ← v5 신규 — 일정 목록 UI
AddScheduleIntent.swift          ← v5 신규 — App Intent + Shortcuts
```

### 테스트 (`SayCalTests/`)
```
SayCalTests.swift                — AddScheduleFeature/ScheduleError/ConfirmScheduleState (29)
RegexScheduleParserTests.swift   — 정규식 35건
OnboardingFeatureTests.swift     — 온보딩 9건
RecentEventsFeatureTests.swift   ← v5 신규 — 일정 목록 5건
```

---

## 16. 최종 판정 (v5)

**Sprint 3 종료 시점에서 ATTACK 리뷰가 지적한 15개 이슈 중 14개 해결 + P2-2 1개 명시적 디퍼(한국어 단일 시장).** 사실상 모든 출시 작업이 끝났다.

- 입력 진입점 3종: 앱 내 (텍스트/음성) · Siri · 단축어
- 검토·저장·확인 플로우: 7필드 편집 시트 · 결과 알림 · 캘린더 딥링크 · 일정 목록 (삭제 가능)
- 실패 카테고리 6종 각각 다른 메시지 + 복구 액션
- 첫 실행 온보딩 + 권한 사전 설명 + 거부 복구
- 78 테스트 / 6 suite 통과

**App Store 제출 또는 TestFlight 공개 모집에 적절한 시점.** 출시 후 1차 피드백 루프에 따라 위젯·일정 인라인 편집·반복 종료 조건 등을 Sprint 4 백로그에서 우선순위 재조정.
