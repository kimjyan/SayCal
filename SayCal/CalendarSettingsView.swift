import ComposableArchitecture
import SwiftUI

struct CalendarSettingsView: View {
    let store: StoreOf<CalendarSettingsFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.calendars) { calendar in
                        Button {
                            store.send(.calendarSelected(calendar))
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(red: calendar.red, green: calendar.green, blue: calendar.blue))
                                    .frame(width: 12, height: 12)
                                Text(calendar.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.selectedIdentifier == calendar.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("캘린더 선택")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.send(.onAppear) }
    }
}
