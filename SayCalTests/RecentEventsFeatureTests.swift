import ComposableArchitecture
import Foundation
import Testing
@testable import SayCal

@MainActor
struct RecentEventsFeatureTests {

    private static func makeEvent(id: String, title: String) -> EventInfo {
        EventInfo(
            id: id,
            title: title,
            startDate: Date(timeIntervalSince1970: 1_780_000_000),
            isAllDay: false,
            calendarTitle: "개인",
            calendarRed: 1,
            calendarGreen: 0,
            calendarBlue: 0
        )
    }

    @Test func onAppearLoadsEvents() async {
        let events = [Self.makeEvent(id: "a", title: "회의"), Self.makeEvent(id: "b", title: "점심")]
        let store = TestStore(initialState: RecentEventsFeature.State()) {
            RecentEventsFeature()
        } withDependencies: {
            $0.fetchUpcomingEventsUseCase.execute = { events }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.eventsLoaded.success) {
            $0.isLoading = false
            $0.events = events
        }
    }

    @Test func fetchFailureShowsError() async {
        let store = TestStore(initialState: RecentEventsFeature.State()) {
            RecentEventsFeature()
        } withDependencies: {
            $0.fetchUpcomingEventsUseCase.execute = { throw CalendarError.accessDenied }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.eventsLoaded.failure) {
            $0.isLoading = false
            $0.errorMessage = "일정을 불러오지 못했어요."
        }
    }

    @Test func deleteRemovesFromList() async {
        let events = [Self.makeEvent(id: "a", title: "회의"), Self.makeEvent(id: "b", title: "점심")]
        let store = TestStore(
            initialState: RecentEventsFeature.State(events: events)
        ) {
            RecentEventsFeature()
        } withDependencies: {
            $0.deleteEventUseCase.execute = { _ in }
        }

        await store.send(.deleteTapped(id: "a")) {
            $0.pendingDeletionID = "a"
        }
        await store.receive(\.deleteResponse) {
            $0.pendingDeletionID = nil
            $0.events = [events[1]]
        }
    }

    @Test func deleteFailureKeepsEventAndShowsError() async {
        let events = [Self.makeEvent(id: "a", title: "회의")]
        let store = TestStore(
            initialState: RecentEventsFeature.State(events: events)
        ) {
            RecentEventsFeature()
        } withDependencies: {
            $0.deleteEventUseCase.execute = { _ in throw CalendarError.eventNotFound }
        }

        await store.send(.deleteTapped(id: "a")) {
            $0.pendingDeletionID = "a"
        }
        await store.receive(\.deleteResponse) {
            $0.pendingDeletionID = nil
            $0.errorMessage = "이 일정을 삭제하지 못했어요."
        }
    }

    @Test func errorDismissedClearsMessage() async {
        let store = TestStore(
            initialState: RecentEventsFeature.State(errorMessage: "일정을 불러오지 못했어요.")
        ) {
            RecentEventsFeature()
        }
        await store.send(.errorDismissed) {
            $0.errorMessage = nil
        }
    }
}
