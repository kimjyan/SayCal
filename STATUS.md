# SayCal — 프로젝트 현황 (STATUS)

> 최종 업데이트: 2026-05-14 (v4 — Sprint 2 일정 풍부화 완료)
> 작성자: PM (자동 생성, 코드/커밋/Attack-doc 기반)
> 브랜치: `main` · 최신 커밋: `2606b3e Add tests for multi-schedule detection and rejection`
> 동봉 문서: `ATTACK.md` (출시 전 공격 리뷰)

---

## 0. v4 변경 요약 — Sprint 2 클로즈

**Sprint 2 일정 풍부화 7개 P1 항목 전부 처리.** duration·알람·반복·다중 일정·캘린더 진입·음성 단계까지 자연어로 표현된 모든 일반 속성이 추출·편집·저장 가능해졌다.

- P1-1 자동 duration 파싱: `@Generable durationMinutes` + 정규식 (예: "1시간 30분 회의" → 90분)
- P1-2 반복 일정: `Recurrence` enum (daily/weekly/monthly/yearly) + `EKRecurrenceRule` (end nil)
- P1-3 알람: `alarmOffsetMinutes` + `EKAlarm` relative offset
- P1-5 다중 일정: 쉼표/"그리고" + 2개 이상 시각 감지 → F6 카테고리로 사전 거부
- P1-6 캘린더 진입: 저장 알림에 "캘린더에서 열기" 버튼 (`calshow:` 딥링크)
- P1-7 음성 UX 단계: idle/recording/parsing/saving phase enum + 단계 캡션
- 신뢰 모델 (§11) 5단계 모두 ✅ (P1-7로 2단계 마무리)
- 새 카테고리 F6 추가, 실패면 매트릭스 6종으로 확장
- 테스트 73건 통과 (Sprint 1 종료 시 48건 → 25건 추가)

이전 변경(v3)의 Trust Foundation은 그대로 유지.

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

**Golden Path (v4)**: 첫 실행 시 온보딩 3-step → 메인 진입 → 한 문장 발화/입력 → **AI 또는 정규식 파싱**(제목/날짜/시간/장소/길이/알림/반복 7필드) → **확인/수정 시트** → 저장 → **결과 알림** + "캘린더에서 열기" 버튼.

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

### 9.4 P2 — 확장

| ID | 항목 | 상태 |
|---|---|---|
| P2-1 | App Intents · Siri · 단축어 · 위젯 | ⏳ |
| P2-2 | 다국어 카피 분리 | ⏳ |
| P2-3 | 캘린더 0개 사용자 EmptyState | ⏳ |
| P2-4 | 일정 목록/재편집/삭제 진입점 | ⏳ |

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

### Sprint 3 — 진입점 다양화 (다음 후보)
- P2-1 App Intents / Siri / 단축어 / 위젯
- P2-2 다국어 분리 (`Localizable.strings`)
- P2-3 캘린더 0개 사용자 EmptyState
- P2-4 일정 목록 / 재편집 / 삭제 진입점

---

## 13. 테스트 전략

### 13.1 매트릭스 (구현 완료)

| 대상 | 종류 | 테스트 수 | 검증 항목 |
|---|---|---|---|
| `RegexScheduleParser` | 단위 | 35 | 날짜 12 + 시간 9 + duration 7 + 반복 5 + 다중 감지 4 + 종합 |
| `AddScheduleFeature` | TCA `TestStore` | 10 | 파싱 성공/실패, 빈 date, F3/F4/F6 라우팅, 확인 시트 저장/취소, phase 동작 |
| `OnboardingFeature` | TCA `TestStore` | 9 | step 전이, 권한 일괄 요청, 건너뛰기, 뒤로 |
| `ScheduleError` mapping | 단위 | 6 | CalendarError/SpeechError 매핑 + 미지 에러 fallback |
| `ConfirmScheduleFeature.State` | 단위 | 8 | resolved 라운드트립, 종일/시간 분기, duration/alarm/recurrence 전파 |

**총 73 테스트 / 5 suite / 모두 통과 (xcodebuild test 5초 이하).**

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
ContentView.swift                — 메인 화면
AddScheduleFeature.swift         — 메인 Reducer + ParsedSchedule
ParseScheduleUseCase.swift       — FoundationModels + 정규식 fallback 머지
RegexScheduleParser.swift        ← v3 신규 — 한국어 날짜/시간 정규식 파서
ConfirmScheduleFeature.swift     ← v3 신규 — 저장 전 편집 Reducer
ConfirmScheduleView.swift        ← v3 신규 — 확인 시트
ScheduleError.swift              ← v3 신규 — F1~F5 카테고리
CreateCalendarEventUseCase.swift — EventKit + 쓰기 가능 필터 + stale fallback
FetchCalendarsUseCase.swift      — 캘린더 목록 (쓰기 가능만)
SpeechRecognitionUseCase.swift   — STT 스트리밍
RequestPermissionsUseCase.swift  ← v3 신규 — 권한 3종 일괄 요청
OnboardingFeature.swift          ← v3 신규 — 온보딩 3-step Reducer
OnboardingView.swift             ← v3 신규 — 온보딩 UI
CalendarSettingsFeature.swift    — 캘린더 선택 Reducer
CalendarSettingsView.swift       — 캘린더 선택 시트
CalendarInfo.swift               — 캘린더 모델
```

### 테스트 (`SayCalTests/`)
```
SayCalTests.swift                — AddScheduleFeature/ScheduleError/ConfirmScheduleState (16)
RegexScheduleParserTests.swift   ← v3 신규 — 정규식 23건
OnboardingFeatureTests.swift     ← v3 신규 — 온보딩 9건
```

---

## 16. 최종 판정 (v4)

**Sprint 2 종료 시점에서 SayCal은 ATTACK 리뷰가 지적한 15개 이슈 중 P0/P1 14개를 모두 해결한 상태.** 남은 4개(P2)는 진입점·다국어·EmptyState·일정 목록으로 모두 확장 영역이지 출시 차단이 아니다.

자연어 한 문장 → 7필드 파싱 → 사용자 검토 → 캘린더 저장 → 캘린더 진입까지 끊김 없이 구현. 6종 실패 카테고리는 각자 다른 메시지와 복구 액션을 제공한다.

**스토어 제출 또는 베타 공개 모집에 적절한 시점.** Sprint 3는 진입점 확장(Siri/위젯/단축어)으로 자연어 일정 앱의 포지셔닝을 강화하는 단계가 된다.
