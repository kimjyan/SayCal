//
//  SayCalApp.swift
//  SayCal
//

import ComposableArchitecture
import SwiftUI

@main
struct SayCalApp: App {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView(store: Store(initialState: AddScheduleFeature.State()) {
                    AddScheduleFeature()
                })
            } else {
                OnboardingGate(onCompleted: { hasCompletedOnboarding = true })
            }
        }
    }
}

private struct OnboardingGate: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    let onCompleted: () -> Void

    init(onCompleted: @escaping () -> Void) {
        self._store = Bindable(wrappedValue: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        })
        self.onCompleted = onCompleted
    }

    var body: some View {
        OnboardingView(store: store)
            .onChange(of: store.isCompleted) { _, completed in
                if completed { onCompleted() }
            }
    }
}
