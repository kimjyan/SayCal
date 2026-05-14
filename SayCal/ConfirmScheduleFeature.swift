import ComposableArchitecture
import Foundation

@Reducer
struct ConfirmScheduleFeature {
    @ObservableState
    struct State: Equatable {
        var title: String
        var location: String
        var date: Date
        var hasTime: Bool
        var time: Date
        var durationMinutes: Int

        init(parsed: ParsedSchedule) {
            self.title = parsed.title
            self.location = parsed.location

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            self.date = formatter.date(from: parsed.date) ?? Date()

            self.hasTime = !parsed.time.isEmpty
            formatter.dateFormat = "HH:mm"
            self.time = formatter.date(from: parsed.time)
                ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

            self.durationMinutes = 60
        }

        var resolved: ParsedSchedule {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)

            let timeString: String
            if hasTime {
                dateFormatter.dateFormat = "HH:mm"
                timeString = dateFormatter.string(from: time)
            } else {
                timeString = ""
            }

            return ParsedSchedule(
                title: title,
                date: dateString,
                time: timeString,
                location: location
            )
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        enum Delegate {
            case save(ParsedSchedule, durationMinutes: Int)
            case cancel
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .saveTapped:
                return .send(.delegate(.save(state.resolved, durationMinutes: state.durationMinutes)))
            case .cancelTapped:
                return .send(.delegate(.cancel))
            case .delegate:
                return .none
            }
        }
    }
}
