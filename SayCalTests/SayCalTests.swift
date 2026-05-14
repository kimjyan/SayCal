import ComposableArchitecture
import Foundation
import Testing
@testable import SayCal

@MainActor
struct AddScheduleFeatureTests {

    // MARK: - 성공 플로우 (텍스트 → 파싱 → 확인 시트 노출)

    @Test func parseSuccessPresentsConfirmation() async {
        let store = TestStore(initialState: AddScheduleFeature.State()) {
            AddScheduleFeature()
        } withDependencies: {
            $0.parseScheduleUseCase.execute = { _ in
                ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "강남역")
            }
        }

        await store.send(.textChanged("내일 3시 강남역 회의")) {
            $0.text = "내일 3시 강남역 회의"
        }

        await store.send(.addButtonTapped) {
            $0.phase = .parsing
        }

        await store.receive(\.parseResponse.success) {
            $0.phase = .idle
            $0.confirmation = ConfirmScheduleFeature.State(parsed: ParsedSchedule(
                title: "회의", date: "2026-05-20", time: "15:00", location: "강남역"
            ))
        }
    }

    // MARK: - F1 파싱 실패 → 에러 알림

    @Test func parseFailureShowsAlert() async {
        let store = TestStore(initialState: AddScheduleFeature.State(text: "??")) {
            AddScheduleFeature()
        } withDependencies: {
            $0.parseScheduleUseCase.execute = { _ in
                throw ScheduleError.parseFailure
            }
        }

        await store.send(.addButtonTapped) {
            $0.phase = .parsing
        }

        await store.receive(\.parseResponse.failure) {
            $0.phase = .idle
            $0.errorAlert = .init(error: .parseFailure)
        }
    }

    // MARK: - 파싱 결과 date 비면 parseFailure 처리

    @Test func emptyDateTreatedAsParseFailure() async {
        let store = TestStore(initialState: AddScheduleFeature.State(text: "회의")) {
            AddScheduleFeature()
        } withDependencies: {
            $0.parseScheduleUseCase.execute = { _ in
                ParsedSchedule(title: "회의", date: "", time: "", location: "")
            }
        }

        await store.send(.addButtonTapped) {
            $0.phase = .parsing
        }

        await store.receive(\.parseResponse.failure) {
            $0.phase = .idle
            $0.errorAlert = .init(error: .parseFailure)
        }
    }

    // MARK: - 확인 시트 저장 → 캘린더 이벤트 생성

    @Test func confirmationSaveCreatesCalendarEvent() async {
        let schedule = ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "강남역")
        let store = TestStore(
            initialState: AddScheduleFeature.State(
                confirmation: ConfirmScheduleFeature.State(parsed: schedule)
            )
        ) {
            AddScheduleFeature()
        } withDependencies: {
            $0.createCalendarEventUseCase.execute = { _, _, _, _ in Date(timeIntervalSince1970: 1_780_000_000) }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60, alarmOffsetMinutes: -1, recurrence: .none))))) {
            $0.confirmation = nil
            $0.phase = .saving
        }

        await store.receive(\.calendarEventResponse.success) {
            $0.phase = .idle
            $0.text = ""
            $0.savedSummary = .init(
                title: "회의",
                dateLabel: "2026-05-20 15:00",
                startDate: Date(timeIntervalSince1970: 1_780_000_000)
            )
        }
    }

    // MARK: - F3 권한 거부 → 알림 + 설정 이동

    @Test func calendarPermissionFailureShowsPermissionAlert() async {
        let schedule = ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "")
        let store = TestStore(
            initialState: AddScheduleFeature.State(
                confirmation: ConfirmScheduleFeature.State(parsed: schedule)
            )
        ) {
            AddScheduleFeature()
        } withDependencies: {
            $0.createCalendarEventUseCase.execute = { _, _, _, _ in
                throw CalendarError.accessDenied
            }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60, alarmOffsetMinutes: -1, recurrence: .none))))) {
            $0.confirmation = nil
            $0.phase = .saving
        }

        await store.receive(\.calendarEventResponse.failure) {
            $0.phase = .idle
            $0.errorAlert = .init(error: .calendarPermission)
        }
    }

    // MARK: - F4 저장 실패 → 캘린더 변경 액션

    @Test func calendarSaveFailureRoutesToSettings() async {
        let schedule = ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "")
        let store = TestStore(
            initialState: AddScheduleFeature.State(
                confirmation: ConfirmScheduleFeature.State(parsed: schedule)
            )
        ) {
            AddScheduleFeature()
        } withDependencies: {
            $0.createCalendarEventUseCase.execute = { _, _, _, _ in
                throw CalendarError.noWritableCalendar
            }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60, alarmOffsetMinutes: -1, recurrence: .none))))) {
            $0.confirmation = nil
            $0.phase = .saving
        }

        await store.receive(\.calendarEventResponse.failure) {
            $0.phase = .idle
            $0.errorAlert = .init(error: .calendarSaveFailure)
        }

        await store.send(.errorPrimaryActionTapped) {
            $0.errorAlert = nil
            $0.isSettingsPresented = true
        }
    }

    // MARK: - 단계별 statusMessage

    @Test func statusMessageByPhase() {
        var state = AddScheduleFeature.State()
        #expect(state.statusMessage == nil)
        state.phase = .recording
        #expect(state.statusMessage == "듣고 있어요…")
        state.phase = .parsing
        #expect(state.statusMessage == "일정을 분석하고 있어요…")
        state.phase = .saving
        #expect(state.statusMessage == "캘린더에 저장하고 있어요…")
    }

    @Test func micTappedDuringLoadingIsNoop() async {
        let store = TestStore(
            initialState: AddScheduleFeature.State(phase: .parsing)
        ) {
            AddScheduleFeature()
        }
        await store.send(.micButtonTapped)
    }

    // MARK: - 확인 시트 취소

    @Test func confirmationCancelDismissesSheet() async {
        let schedule = ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "")
        let store = TestStore(
            initialState: AddScheduleFeature.State(
                confirmation: ConfirmScheduleFeature.State(parsed: schedule)
            )
        ) {
            AddScheduleFeature()
        }

        await store.send(.confirmation(.presented(.delegate(.cancel)))) {
            $0.confirmation = nil
        }
    }
}

// MARK: - ScheduleError mapping

struct ScheduleErrorMappingTests {

    @Test func mapsAccessDeniedToPermission() {
        #expect(ScheduleError.from(CalendarError.accessDenied) == .calendarPermission)
    }

    @Test func mapsNoWritableCalendarToSaveFailure() {
        #expect(ScheduleError.from(CalendarError.noWritableCalendar) == .calendarSaveFailure)
    }

    @Test func mapsSaveFailedToSaveFailure() {
        #expect(ScheduleError.from(CalendarError.saveFailed) == .calendarSaveFailure)
    }

    @Test func mapsSpeechErrorToSpeechFailure() {
        #expect(ScheduleError.from(SpeechError.notAuthorized) == .speechFailure)
        #expect(ScheduleError.from(SpeechError.recognizerUnavailable) == .speechFailure)
    }

    @Test func preservesScheduleError() {
        #expect(ScheduleError.from(ScheduleError.modelUnavailable) == .modelUnavailable)
    }

    @Test func unknownErrorFallsBackToParseFailure() {
        struct UnknownError: Error {}
        #expect(ScheduleError.from(UnknownError()) == .parseFailure)
    }
}

// MARK: - ConfirmScheduleFeature.State resolved 라운드트립

struct ConfirmScheduleStateTests {

    @Test func resolvedRoundTripsDateAndTime() {
        let parsed = ParsedSchedule(title: "회의", date: "2026-05-20", time: "15:00", location: "강남역")
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        let resolved = state.resolved

        #expect(resolved.title == "회의")
        #expect(resolved.location == "강남역")
        #expect(resolved.date == "2026-05-20")
        #expect(resolved.time == "15:00")
    }

    @Test func resolvedEmitsEmptyTimeWhenAllDay() {
        let parsed = ParsedSchedule(title: "워크숍", date: "2026-05-21", time: "", location: "")
        var state = ConfirmScheduleFeature.State(parsed: parsed)
        state.hasTime = false

        let resolved = state.resolved
        #expect(resolved.time == "")
        #expect(resolved.date == "2026-05-21")
    }

    @Test func emptyDateStringDoesNotCrash() {
        let parsed = ParsedSchedule(title: "x", date: "", time: "", location: "")
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.title == "x")
        #expect(state.hasTime == false)
    }

    @Test func parsedDurationFlowsToState() {
        let parsed = ParsedSchedule(
            title: "회의", date: "2026-05-20", time: "15:00", location: "",
            durationMinutes: 90, alarmOffsetMinutes: -1
        )
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.durationMinutes == 90)
        #expect(state.alarmOffsetMinutes == -1)
    }

    @Test func missingDurationFallsBackToSixtyMinutes() {
        let parsed = ParsedSchedule(title: "x", date: "2026-05-20", time: "15:00", location: "")
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.durationMinutes == 60)
    }

    @Test func parsedAlarmFlowsToState() {
        let parsed = ParsedSchedule(
            title: "회의", date: "2026-05-20", time: "15:00", location: "",
            durationMinutes: 0, alarmOffsetMinutes: 10
        )
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.alarmOffsetMinutes == 10)
    }

    @Test func parsedRecurrenceFlowsToState() {
        let parsed = ParsedSchedule(
            title: "스탠드업", date: "2026-05-20", time: "09:00", location: "",
            recurrence: .weekly
        )
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.recurrence == .weekly)
    }

    @Test func defaultRecurrenceIsNone() {
        let parsed = ParsedSchedule(title: "x", date: "2026-05-20", time: "", location: "")
        let state = ConfirmScheduleFeature.State(parsed: parsed)
        #expect(state.recurrence == .none)
    }

    @Test func resolvedCarriesDurationAndAlarm() {
        let parsed = ParsedSchedule(
            title: "회의", date: "2026-05-20", time: "15:00", location: "",
            durationMinutes: 30, alarmOffsetMinutes: 60
        )
        var state = ConfirmScheduleFeature.State(parsed: parsed)
        state.durationMinutes = 30
        state.alarmOffsetMinutes = 60
        let resolved = state.resolved
        #expect(resolved.durationMinutes == 30)
        #expect(resolved.alarmOffsetMinutes == 60)
    }
}
