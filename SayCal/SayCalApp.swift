//
//  SayCalApp.swift
//  SayCal
//
//  Created by 김재한 on 2/26/26.
//

import ComposableArchitecture
import SwiftUI

@main
struct SayCalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialState: AddScheduleFeature.State()) {
                AddScheduleFeature()
            })
        }
    }
}
