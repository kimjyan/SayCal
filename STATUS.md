# SayCal — 프로젝트 현황 (STATUS)

> 최종 업데이트: 2026-05-14 (v2 — `ATTACK.md` 리뷰 반영 보강)
> 작성자: PM (자동 생성, 코드/커밋/Attack-doc 기반)
> 브랜치: `main` · 최신 커밋: `de701f7 Add calendar selection settings feature`
> 동봉 문서: `ATTACK.md` (출시 전 공격 리뷰)

---

## 0. v2 변경 요약 (`ATTACK.md` 반영)

- **가치 제안 재정의**: "마찰 제거"가 아니라 **"확신을 주는 빠른 저장"**. 잘못 저장된 일정 한 건이 곧 앱 삭제다.
- **실패면 매트릭스** 신설 (§9.1): 5개 실패 카테고리를 명시하고 각각 사용자에게 다른 메시지로 노출하도록 정책 못 박음.
- **출시 차단 기준 (Release Blockers)** 신설 (§10): 이게 풀리지 않으면 출시 보류.
- **신뢰 모델 (Trust Model)** 신설 (§11): 사용자가 앱을 신뢰하게 만드는 5-단계 경로.
- **갭 섹션 P0 확장** (§9.2): 캘린더 ID stale, 다중 일정 정책, FoundationModels fallback, 음성 UX 상태 전이, 저장 후 확인 경로 등 누락 항목 추가.
- **로드맵 재정렬** (§12): Sprint 1을 "Trust Foundation"으로 단일 테마 지정.
- **테스트 전략** 신설 (§13): TCA 구조를 활용한 단위/통합 테스트 매트릭스.

---

## 1. 한 줄 정의

**자연어(텍스트·음성)로 말하면 iOS 캘린더에 일정이 자동으로 추가되는 앱.**

> 예: "이번주 토요일 3시 강남역" → 토요일 15:00 / 장소 "강남역" 으로 캘린더 이벤트 생성.

---

## 2. 핵심 가치 제안 (Value Prop) — v2 재정의

| 차원 | v1 (출시 전 가설) | v2 (`ATTACK.md` 이후) |
|---|---|---|
| 1차 가치 | 마찰 제거 | **확신을 주는 빠른 저장** — 빠른 저장은 차순위 |
| 2차 가치 | 온디바이스 AI · 음성 우선 | 동일, 단 fallback과 권한 복구가 전제 |

> **핵심 원리**: 캘린더 앱은 사용자의 하루를 관리하는 도구다. 잘못 저장된 일정 1건 = 신뢰 붕괴 = 삭제. "빠르지만 가끔 틀리는 앱"이 가장 위험한 형태다.

---

## 3. 타깃 사용자 & 핵심 시나리오

| 사용자 유형 | 시나리오 |
|---|---|
| 직장인 | 회의 끝나고 통화하며 "다음주 화요일 2시 회사 미팅" |
| 학생 | 강의 중 빠르게 "내일 오후 9시 스터디" |
| 부모 | 운전 중 음성으로 "이번주 금요일 7시 학부모 모임" |

**Golden Path (v2)**: 앱 진입 → 한 문장 발화/입력 → **AI 파싱 결과 확인/수정** → 저장 → **저장 결과 요약** → 캘린더 반영.

> v1 Golden Path에서 "확인" 단계가 빠져 있던 점이 §9.2의 P0-1 이슈.

---

## 4. 기술 스택

| 항목 | 선택 |
|---|---|
| 플랫폼 | iOS 26.0+ (Bundle: `com.-jay.cal.SayCal`) |
| UI | SwiftUI |
| 상태관리 | The Composable Architecture (TCA) |
| 빌드 시스템 | Tuist 4.38.2 (`.mise.toml` 핀) |
| 자연어 파싱 | Apple `FoundationModels` (on-device, `@Generable`/`@Guide`) |
| 캘린더 연동 | `EventKit` (`EKEventStore`, `requestFullAccessToEvents`) |
| 음성 인식 | `Speech` + `AVFoundation` (ko-KR `SFSpeechRecognizer`) |
| 영속화 | `UserDefaults` (선택된 캘린더 ID) |
| 다국어 | `en`, `ko` 등록 / 실제 카피 한국어 하드코딩 (부채) |

---

## 5. 아키텍처 개요

```
ContentView (SwiftUI)
   │
   ▼
AddScheduleFeature (TCA Reducer)
   │
   ├──► ParseScheduleUseCase   ──► LanguageModelSession (FoundationModels)
   │                                 └─ ScheduleGenerableOutput { title, date, time, location }
   │
   ├──► CreateCalendarEventUseCase ──► EKEventStore.save()
   │                                     └─ UserDefaults 선택 캘린더 사용
   │
   └──► SpeechRecognitionUseCase ──► AVAudioEngine + SFSpeechRecognizer (스트리밍)

CalendarSettingsView (sheet)
   │
   ▼
CalendarSettingsFeature (TCA)
   └──► FetchCalendarsUseCase ──► EKEventStore.calendars(for: .event)
```

- **DI**: TCA `@Dependency` + `DependencyKey`로 UseCase 주입 → 테스트 시 mock 교체 가능. (현재 미활용 → §13)
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
| 6 | EventKit 이벤트 생성 | `786ca5b` | 시간 없으면 종일 |
| 7 | 음성 입력 (ko-KR STT) | `75d3f35` | partial result 스트리밍 |
| 8 | 로딩 UI 처리 | `4394704`, `74e8095` | |
| 9 | 입력 영역 패딩 정리 | `113fb5f` | |
| 10 | 캘린더 선택 설정 | `de701f7` | UserDefaults 저장 |

---

## 7. 데이터 모델

```swift
struct ParsedSchedule {           // 현재
    var title: String
    var date: String              // "yyyy-MM-dd"
    var time: String              // "HH:mm"
    var location: String
}

// v2 권장 확장 (§12 Sprint 1~2)
struct ParsedSchedule {
    var title: String
    var date: String
    var time: String
    var location: String
    var durationMinutes: Int?     // ATTACK §4
    var recurrence: Recurrence?   // ATTACK §5
    var alarmOffsetMinutes: Int?  // ATTACK §6
    var confidence: Double?       // fallback 트리거용 (ATTACK §10)
}
```

---

## 8. 권한

| 권한 | 이유 | 키 | 거부 시 복구 경로 |
|---|---|---|---|
| 캘린더 풀 액세스 | 이벤트 생성 | `NSCalendarsFullAccessUsageDescription` | **부재 (P0)** |
| 음성 인식 | 발화 → 텍스트 | `NSSpeechRecognitionUsageDescription` | **부재 (P0)** |
| 마이크 | 오디오 입력 | `NSMicrophoneUsageDescription` | **부재 (P0)** |

---

## 9. 갭 / 리스크

### 9.1 실패면 매트릭스 (신설)

> ATTACK §2 지적: 현재 `parseResponse(.failure)`·`calendarEventResponse(.failure)` 모두 `isLoading = false`만 처리. 사용자는 어떤 실패인지 구분 불가 → "추가" 눌렀는데 무반응 → 삭제.

| 카테고리 | 트리거 | 사용자 메시지 (예시) | 다음 행동 |
|---|---|---|---|
| F1. AI 파싱 실패 | FoundationModels 응답 실패 / 필드 누락 | "일정을 이해하지 못했어요. 직접 입력해 주세요." | 인라인 편집 모드 진입 |
| F2. 모델 가용성 실패 | OS/기기 조건 미충족 | "이 기기에서는 자동 분석을 사용할 수 없어요." | 수동 입력 모드로 fallback |
| F3. 캘린더 권한 실패 | `requestFullAccessToEvents()` 거부 | "캘린더 권한이 필요해요." | 설정 앱으로 이동 버튼 |
| F4. 캘린더 저장 실패 | 선택 캘린더 stale / 읽기 전용 / 저장 예외 | "선택한 캘린더에 저장할 수 없어요." | 캘린더 재선택 시트 |
| F5. 음성 인식 실패 | 마이크 권한 거부 / `SFSpeechRecognizer` 미가용 | "음성 인식을 사용할 수 없어요." | 텍스트 입력 모드 강조 |

### 9.2 P0 — 출시 차단급 (확장)

| ID | 항목 | 근거 |
|---|---|---|
| P0-1 | 파싱 결과 확인/수정 UI 부재 → 잘못된 저장 무방지 | ATTACK §1 |
| P0-2 | 실패 피드백 부재 (5개 카테고리 미분리) | ATTACK §2, §9.1 |
| P0-3 | 권한 거부 복구 플로우 부재 (캘린더/음성/마이크) | ATTACK §3 |
| P0-4 | 선택 캘린더 stale 검증 부재 (저장 ID가 더 이상 존재하지 않을 수 있음) | ATTACK §8 |
| P0-5 | 쓰기 가능 캘린더 필터 부재 (구독/읽기 전용 캘린더 노출됨) | ATTACK §8 |
| P0-6 | FoundationModels 미가용/실패 fallback 부재 | ATTACK §10 |
| P0-7 | 핵심 Reducer/UseCase 테스트 0건 | ATTACK §14 |

### 9.3 P1 — 핵심 사용성

| ID | 항목 | 근거 |
|---|---|---|
| P1-1 | 종료 시간 1시간 고정 (duration 파싱 부재) | ATTACK §4 |
| P1-2 | 반복 일정 미지원 ("매주 월요일 9시"가 단발로 저장) | ATTACK §5 |
| P1-3 | 알람/리마인더 미지원 (`EKAlarm` 미생성) | ATTACK §6 |
| P1-4 | 온보딩 화면 부재 (권한 사전 설명 없음) | ATTACK §7 |
| P1-5 | 다중 일정 입력 정책 미정 ("9시 회의, 11시 점심") | ATTACK §9 |
| P1-6 | 저장 후 결과 요약/캘린더 진입 버튼 부재 | ATTACK §11 |
| P1-7 | 음성 UX 상태(녹음/인식/파싱) 미구분 | ATTACK §12 |

### 9.4 P2 — 확장

| ID | 항목 | 근거 |
|---|---|---|
| P2-1 | App Intents · Siri · 단축어 · 위젯 진입점 부재 | ATTACK §15 |
| P2-2 | 다국어 카피 미분리 (en 등록, 카피는 한국어 하드코딩) | ATTACK §13 |
| P2-3 | 캘린더 0개 사용자 EmptyState 부재 | ATTACK §8 |
| P2-4 | 일정 목록/재편집/삭제 진입점 부재 | ATTACK §11 |

---

## 10. 출시 차단 기준 (Release Blockers, 신설)

다음 7개 중 하나라도 미해결 시 **출시 보류**:

1. ✋ 저장 전 파싱 결과 확인/수정 UI 부재 (P0-1)
2. ✋ 실패 5종(F1~F5)에 대한 사용자 메시지 분리 부재 (P0-2)
3. ✋ 권한 거부 후 복구 플로우 부재 (P0-3)
4. ✋ 선택 캘린더 유효성/쓰기 가능 검증 부재 (P0-4, P0-5)
5. ✋ duration/반복/알림 중 **최소 duration** 처리 부재 (P1-1 부분)
6. ✋ `AddScheduleFeature` 주요 상태 전이 테스트 부재 (P0-7)
7. ✋ `ParseScheduleUseCase` 날짜/시간 파싱 테스트 부재 (P0-7)

---

## 11. 신뢰 모델 (Trust Model, 신설)

> 사용자가 SayCal을 신뢰하게 만드는 5-단계 경로. 어느 단계든 빠지면 직전 단계의 의미가 사라진다.

```
1. 권한 요청  →  사용자가 왜 필요한지 안다 (온보딩)
2. 입력      →  사용자가 무엇이 인식됐는지 본다 (음성 상태/파싱 중 표시)
3. 검토      →  사용자가 저장 전 결과를 확인하고 수정한다 (확인 시트)
4. 저장      →  사용자가 어디에 저장됐는지 본다 (캘린더 + 결과 요약)
5. 복구      →  실패해도 다음 행동이 명확하다 (실패 메시지 + 액션 버튼)
```

현재 2·3·4·5 단계가 비어 있음. 1단계도 시스템 팝업만 존재.

---

## 12. 로드맵 (재정렬)

### Sprint 1 — Trust Foundation (출시 차단 해소)
**테마**: 사용자가 앱을 신뢰할 수 있게 만든다.
- P0-1: 파싱 결과 확인/편집 시트 (`ConfirmScheduleFeature` 신설 권장)
- P0-2: `AddScheduleFeature.State`에 5종 에러 상태 추가 + 토스트/배너
- P0-3: 권한 거부 복구 시트 (설정 이동 버튼)
- P0-4 / P0-5: `FetchCalendarsUseCase` 쓰기 가능 필터링 + 저장 전 stale 검증
- P0-6: FoundationModels 실패 시 정규식 fallback (날짜/시간 최소 추출)
- P0-7: 아래 §13 매트릭스대로 테스트

### Sprint 2 — 일정 풍부화
- P1-1 duration: `ParsedSchedule.durationMinutes` + `@Guide` 추가
- P1-2 반복: `Recurrence` 모델 + `EKRecurrenceRule`
- P1-3 알람: `alarmOffsetMinutes` + `EKAlarm`
- P1-4 온보딩: 3-스텝 권한 사전 설명
- P1-5 다중 일정: 정책 결정 (지원 vs 거부) 후 구현
- P1-6 저장 후 요약: 결과 카드 + "캘린더에서 열기"
- P1-7 음성 UX: idle / recording / transcribing / parsing 상태 분리

### Sprint 3 — 진입점 다양화
- P2-1 App Intents / Siri / 단축어 / 위젯
- P2-2 다국어 분리 (`Localizable.strings`)
- P2-3 / P2-4 EmptyState · 일정 목록

---

## 13. 테스트 전략 (신설)

> ATTACK §14: TCA 구조라 테스트 가능한데 안 한 것이다. 현재 `SayCalTests/SayCalTests.swift`는 템플릿 그대로.

### 13.1 매트릭스

| 대상 | 종류 | 검증 항목 |
|---|---|---|
| `ParseScheduleUseCase` | 단위 (mock model) | yyyy-MM-dd 포맷, 이번주/다음주 경계, 자정/정오, 시간 누락, 장소-제목 분리 |
| `CreateCalendarEventUseCase` | 단위 (mock store) | 캘린더 fallback, stale ID 감지, 종일/시간있음 분기, 권한 거부 throw |
| `FetchCalendarsUseCase` | 단위 | 쓰기 가능 필터링, 0개 케이스 |
| `AddScheduleFeature` | TCA `TestStore` | 성공 플로우, 5종 실패 상태 전이, 음성 시작/중단, 설정 시트 토글 |
| `CalendarSettingsFeature` | TCA `TestStore` | onAppear 로딩, 선택 영속화, 0개 fallback |

### 13.2 목표
- Sprint 1 종료 시 **핵심 Reducer 100% 상태 커버**, UseCase 80% 라인 커버.
- 회귀 방지: 날짜 파싱 테스트는 "2026-12-31 23:59" 같은 경계 케이스 고정.

---

## 14. 오픈 퀘스천 (보강)

- **다중 일정 정책**: "9시 회의, 11시 점심" 같은 입력을 지원할지 거부할지 — 지원 시 `[ParsedSchedule]`로 모델 변경, 거부 시 사전 감지 후 안내.
- **fallback 깊이**: 정규식만으로 어디까지 갈지, 아니면 fallback 시에는 인라인 편집을 강제할지.
- **반복 일정 종료 조건**: "매주 월요일"이 영원히 반복인지, 종료 시점을 사용자에게 물을지.
- **위치 정보 활용**: `location` 문자열을 `EKStructuredLocation` (지도 좌표)으로 확장할지.
- **다국어 범위**: 한국어 전용으로 좁힐지, en/ja 등 확장할지 — 현재 인스트럭션 자체가 한국어 의존.
- **모델 신뢰도**: FoundationModels `@Generable` 출력에 신뢰도가 노출되지 않음 — 휴리스틱(필드 누락 수)으로 대체 가능한지.

---

## 15. 파일 인벤토리

```
SayCal/
├── SayCalApp.swift                  — App 엔트리 (Store 주입)
├── ContentView.swift                — 메인 화면
├── AddScheduleFeature.swift         — 메인 Reducer + ParsedSchedule
├── ParseScheduleUseCase.swift       — FoundationModels 파싱 + prompt 생성
├── CreateCalendarEventUseCase.swift — EventKit 이벤트 생성
├── SpeechRecognitionUseCase.swift   — STT 스트리밍
├── CalendarSettingsFeature.swift    — 캘린더 선택 Reducer
├── CalendarSettingsView.swift       — 캘린더 선택 시트
├── CalendarInfo.swift               — 캘린더 모델
└── FetchCalendarsUseCase.swift      — 캘린더 목록 조회

SayCalTests/SayCalTests.swift        — 템플릿 (P0-7로 교체 예정)
```

---

## 16. 최종 판정 (`ATTACK.md` 반영)

현재 SayCal은 **"틀릴 수 있는 일정을 확인 없이 캘린더에 쓰는 앱"**에 가깝다.
출시 전 풀어야 할 것은 기능 추가가 아니라 **신뢰 인프라 4종 세트**다:

1. 저장 전 신뢰 (확인/수정 UI)
2. 실패 시 설명 (5종 메시지 분리)
3. 권한 거부 복구 (3종 권한별 경로)
4. 캘린더 저장 검증 (stale·쓰기 가능)

이 네 가지가 풀린 뒤에야 duration·반복·알람·온보딩·App Intents가 의미를 갖는다.
