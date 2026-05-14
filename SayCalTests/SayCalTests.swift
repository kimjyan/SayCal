import ComposableArchitecture
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
            $0.isLoading = true
        }

        await store.receive(\.parseResponse.success) {
            $0.isLoading = false
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
            $0.isLoading = true
        }

        await store.receive(\.parseResponse.failure) {
            $0.isLoading = false
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
            $0.isLoading = true
        }

        await store.receive(\.parseResponse.failure) {
            $0.isLoading = false
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
            $0.createCalendarEventUseCase.execute = { _, _ in }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60))))) {
            $0.confirmation = nil
            $0.isLoading = true
        }

        await store.receive(\.calendarEventResponse.success) {
            $0.isLoading = false
            $0.text = ""
            $0.savedSummary = .init(title: "회의", dateLabel: "2026-05-20 15:00")
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
            $0.createCalendarEventUseCase.execute = { _, _ in
                throw CalendarError.accessDenied
            }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60))))) {
            $0.confirmation = nil
            $0.isLoading = true
        }

        await store.receive(\.calendarEventResponse.failure) {
            $0.isLoading = false
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
            $0.createCalendarEventUseCase.execute = { _, _ in
                throw CalendarError.noWritableCalendar
            }
        }

        await store.send(.confirmation(.presented(.delegate(.save(schedule, durationMinutes: 60))))) {
            $0.confirmation = nil
            $0.isLoading = true
        }

        await store.receive(\.calendarEventResponse.failure) {
            $0.isLoading = false
            $0.errorAlert = .init(error: .calendarSaveFailure)
        }

        await store.send(.errorPrimaryActionTapped) {
            $0.errorAlert = nil
            $0.isSettingsPresented = true
        }
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
}
