import ComposableArchitecture
import SwiftUI

struct ConfirmScheduleView: View {
    @Bindable var store: StoreOf<ConfirmScheduleFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section("제목") {
                    TextField("일정 제목", text: $store.title)
                }

                Section("날짜 / 시간") {
                    DatePicker("날짜", selection: $store.date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))

                    Toggle("시간 지정", isOn: $store.hasTime)

                    if store.hasTime {
                        DatePicker("시간", selection: $store.time, displayedComponents: .hourAndMinute)
                            .environment(\.locale, Locale(identifier: "ko_KR"))

                        Picker("길이", selection: $store.durationMinutes) {
                            Text("30분").tag(30)
                            Text("1시간").tag(60)
                            Text("1시간 30분").tag(90)
                            Text("2시간").tag(120)
                            Text("3시간").tag(180)
                        }
                    }
                }

                Section("장소") {
                    TextField("선택 사항", text: $store.location)
                }

                Section("알림") {
                    Picker("시점", selection: $store.alarmOffsetMinutes) {
                        Text("없음").tag(-1)
                        Text("정시").tag(0)
                        Text("5분 전").tag(5)
                        Text("10분 전").tag(10)
                        Text("15분 전").tag(15)
                        Text("30분 전").tag(30)
                        Text("1시간 전").tag(60)
                        Text("1일 전").tag(1440)
                    }
                }

                Section("반복") {
                    Picker("주기", selection: $store.recurrence) {
                        ForEach(Recurrence.allCases, id: \.self) { option in
                            Text(option.koreanLabel).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("일정 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { store.send(.cancelTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { store.send(.saveTapped) }
                        .disabled(store.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
