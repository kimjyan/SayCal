import ComposableArchitecture
import SwiftUI
import UIKit

struct RecentEventsView: View {
    @Bindable var store: StoreOf<RecentEventsFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.events.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.events.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(grouped, id: \.0) { sectionTitle, items in
                            Section(sectionTitle) {
                                ForEach(items) { event in
                                    row(event)
                                        .swipeActions(allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                store.send(.deleteTapped(id: event.id))
                                            } label: {
                                                Label("삭제", systemImage: "trash")
                                            }
                                            Button {
                                                store.send(.openInCalendarTapped(event))
                                                openInCalendar(event)
                                            } label: {
                                                Label("열기", systemImage: "calendar")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("최근 일정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.send(.onAppear) }
        .alert(
            "오류",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            ),
            presenting: store.errorMessage
        ) { _ in
            Button("확인", role: .cancel) { store.send(.errorDismissed) }
        } message: { message in
            Text(message)
        }
    }

    private var grouped: [(String, [EventInfo])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (EEE)"
        let cal = Calendar.current

        let byDay = Dictionary(grouping: store.events) { event in
            cal.startOfDay(for: event.startDate)
        }
        return byDay.keys.sorted().map { day in
            (formatter.string(from: day), byDay[day]!.sorted { $0.startDate < $1.startDate })
        }
    }

    private func row(_ event: EventInfo) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: event.calendarRed, green: event.calendarGreen, blue: event.calendarBlue))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                Text(timeLabel(event))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray))
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .opacity(store.pendingDeletionID == event.id ? 0.3 : 1)
    }

    private func timeLabel(_ event: EventInfo) -> String {
        if event.isAllDay { return "종일 · \(event.calendarTitle)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return "\(formatter.string(from: event.startDate)) · \(event.calendarTitle)"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(Color(.systemGray3))
            Text("선택한 캘린더에\n표시할 일정이 없어요")
                .font(.system(size: 15))
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openInCalendar(_ event: EventInfo) {
        let reference = Int(event.startDate.timeIntervalSinceReferenceDate)
        if let url = URL(string: "calshow:\(reference)") {
            UIApplication.shared.open(url)
        }
    }
}
