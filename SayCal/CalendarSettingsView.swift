import ComposableArchitecture
import SwiftUI
import UIKit

struct CalendarSettingsView: View {
    let store: StoreOf<CalendarSettingsFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.calendars.isEmpty {
                    emptyState
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray3))
            Text("사용 가능한 캘린더가 없어요")
                .font(.system(size: 17, weight: .semibold))
            Text("캘린더 앱에서 쓰기 가능한 캘린더를 만들거나\niCloud 캘린더를 활성화해 주세요.")
                .font(.system(size: 14))
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: "calshow://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("캘린더 앱 열기")
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
