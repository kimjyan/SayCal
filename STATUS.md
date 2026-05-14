# SayCal — 프로젝트 현황 (STATUS)

> 최종 업데이트: 2026-05-14 (v3 — Sprint 1 Trust Foundation 완료)
> 작성자: PM (자동 생성, 코드/커밋/Attack-doc 기반)
> 브랜치: `main` · 최신 커밋: `e95f3ae Add tests for onboarding step transitions and permission requests`
> 동봉 문서: `ATTACK.md` (출시 전 공격 리뷰)

---

## 0. v3 변경 요약 — Sprint 1 클로즈

**Sprint 1 Trust Foundation 7개 P0 항목 전부 처리.** 저장 전 신뢰·실패 분기·권한 복구·캘린더 검증·AI fallback·온보딩·테스트 베이스라인이 들어왔다.

- 출시 차단 7개 게이트 (§10) 전부 ✅
- 테스트 48건 통과 (§13.2)
- 새 파일 8개, 수정 4개
- 신뢰 모델 5단계 (§11) 중 1·3·4·5 단계 구현. 2단계(음성 UX 상태 표시)는 P1-7로 남음.

이전 변경(v2)에서 정의한 실패면 매트릭스(F1–F5)는 그대로 유효하며, 모든 실패가 사용자에게 카테고리별로 노출되도록 구현.

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

**Golden Path (v3)**: 첫 실행 시 온보딩 3-step (가치 → 권한 → 예시) → 메인 진입 → 한 문장 발화/입력 → **AI 또는 정규식 파싱** → **확인/수정 시트** → 저장 → **저장 결과 요약 알림**.

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
struct ParsedSchedule {           // 현재 사용
    var title: String
    var date: String              // "yyyy-MM-dd"
    var time: String              // "HH:mm" (빈 문자열이면 종일)
    var location: String
}

// Sprint 2 예정 확장
struct ParsedSchedule {
    var title: String
    var date: String
    var time: String
    var location: String
    var durationMinutes: Int?     // ATTACK §4 — 현재 확인 시트에서 선택, 모델에는 미반영
    var recurrence: Recurrence?   // ATTACK §5
    var alarmOffsetMinutes: Int?  // ATTACK §6
}
```

> `durationMinutes`는 v3 시점 사용자 확인 시트에서 30/60/90/120/180분 중 선택해 `CreateCalendarEventUseCase`로 전달 (모델 파싱 단계엔 미반영).

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

### 9.1 실패면 매트릭스 (구현 완료)

| 카테고리 | 트리거 | 사용자 메시지 | 다음 행동 | 구현 |
|---|---|---|---|---|
| F1. 파싱 실패 | 모델 + 정규식 모두 date 미추출 | "일정을 이해하지 못했어요" | "확인" | ✅ |
| F2. 모델 가용성 | 모델 실패 + 정규식 미추출 | "이 기기에서는 자동 분석을 사용할 수 없어요" | "확인" | ✅ |
| F3. 캘린더 권한 | `requestFullAccessToEvents` 거부 | "캘린더 권한이 필요해요" | "설정 열기" 버튼 | ✅ |
| F4. 캘린더 저장 | stale ID / 쓰기 불가 / 저장 예외 | "캘린더에 저장하지 못했어요" | "캘린더 변경" 버튼 (설정 시트) | ✅ |
| F5. 음성 인식 | 권한 거부 / 미가용 | "음성 인식을 사용할 수 없어요" | "설정 열기" 버튼 | ✅ |

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

### 9.3 P1 — 핵심 사용성 (Sprint 2 후보)

| ID | 항목 | 근거 | 상태 |
|---|---|---|---|
| P1-1 | duration 파싱 자동화 (현재는 확인 시트에서 수동 선택) | ATTACK §4 | 🟡 부분 (확인 시트만) |
| P1-2 | 반복 일정 미지원 | ATTACK §5 | ⏳ |
| P1-3 | 알람/리마인더 미지원 | ATTACK §6 | ⏳ |
| P1-4 | 온보딩 화면 부재 | ATTACK §7 | ✅ (P0-3에 흡수) |
| P1-5 | 다중 일정 입력 정책 미정 | ATTACK §9 | ⏳ |
| P1-6 | 저장 후 결과 요약 | ATTACK §11 | 🟡 알림 카드만, 캘린더 진입 버튼 없음 |
| P1-7 | 음성 UX 상태 미구분 | ATTACK §12 | ⏳ |

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
1. 권한 요청  →  사용자가 왜 필요한지 안다           ✅ 온보딩 §2
2. 입력      →  사용자가 무엇이 인식됐는지 본다       ⏳ 음성 UX 미구분 (P1-7)
3. 검토      →  사용자가 저장 전 결과를 확인/수정한다  ✅ ConfirmScheduleView
4. 저장      →  사용자가 어디에 저장됐는지 본다       ✅ 저장 완료 알림
5. 복구      →  실패해도 다음 행동이 명확하다        ✅ 5종 카테고리별 액션
```

5단계 중 4단계 구현. 남은 한 단계(2단계 음성 UX)는 P1-7로 추적.

---

## 12. 로드맵

### Sprint 1 — Trust Foundation ✅ 완료
- P0-1 ~ P0-7 전부 해제. 출시 차단 게이트 클리어.

### Sprint 2 — 일정 풍부화 (다음 후보)
- P1-1 duration 자동 파싱: `ParsedSchedule.durationMinutes` + `@Guide` 추가
- P1-2 반복: `Recurrence` 모델 + `EKRecurrenceRule`
- P1-3 알람: `alarmOffsetMinutes` + `EKAlarm`
- P1-5 다중 일정: 정책 결정 후 `[ParsedSchedule]` 구조 또는 사전 거부
- P1-6 저장 후 캘린더 진입: 알림에 "캘린더에서 열기" 버튼
- P1-7 음성 UX: idle / recording / transcribing / parsing 4-state 분리

### Sprint 3 — 진입점 다양화
- P2-1 App Intents / Siri / 단축어 / 위젯
- P2-2 다국어 분리 (`Localizable.strings`)
- P2-3 / P2-4 EmptyState · 일정 목록 화면

---

## 13. 테스트 전략

### 13.1 매트릭스 (구현 완료)

| 대상 | 종류 | 테스트 수 | 검증 항목 |
|---|---|---|---|
| `RegexScheduleParser` | 단위 | 23 | 오늘/내일/모레/글피, 이번주/다음주/단독 요일, N월 N일, 오전/오후, 자정/정오, 24h, 종합 |
| `AddScheduleFeature` | TCA `TestStore` | 7 | 파싱 성공/실패, 빈 date, 확인 시트 저장, F3/F4 라우팅, 확인 취소 |
| `OnboardingFeature` | TCA `TestStore` | 9 | step 전이, 권한 일괄 요청, 건너뛰기, 뒤로 |
| `ScheduleError` mapping | 단위 | 6 | CalendarError/SpeechError 매핑 + 미지 에러 fallback |
| `ConfirmScheduleFeature.State` | 단위 | 3 | resolved 라운드트립, 종일/시간 분기, 빈 입력 |

**총 48 테스트 / 5 suite / 모두 통과 (xcodebuild test 5초 이하).**

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

## 16. 최종 판정 (v3)

**Sprint 1 종료 시점에서 SayCal은 출시 차단 7개 게이트를 모두 통과한 상태.** ATTACK 리뷰가 지적한 신뢰 인프라 4종(저장 전 신뢰 · 실패 설명 · 권한 복구 · 캘린더 저장 검증)이 모두 들어와 있고, 추가로 FoundationModels fallback과 첫 실행 온보딩이 보강됐다.

남은 작업은 **출시 차단이 아닌 사용성/확장**: 자동 duration·반복·알람·다중 일정 처리(Sprint 2), App Intents·다국어·일정 목록(Sprint 3). 이들은 없어도 출시 가능하지만, 있으면 자연어 일정 앱이라는 포지셔닝을 강화한다.

베타 배포(친구·동료 대상) 시작에 적절한 시점.
