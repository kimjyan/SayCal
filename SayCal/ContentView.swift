//
//  ContentView.swift
//  SayCal
//
//  Created by 김재한 on 2/26/26.
//

import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<AddScheduleFeature>

    var body: some View {
        VStack(spacing: 0) {
            navBar
            inputArea
                .padding(.horizontal, 16)
                .padding(.top, 24)
            bottomSection
        }
        .background(Color(.systemBackground))
    }

    private var navBar: some View {
        ZStack {
            Text("일정 추가")
                .font(.system(size: 17, weight: .semibold))

            HStack {
                Button {} label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                }

                Spacer()

                Button {} label: {
                    Text("추가")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(store.text.isEmpty ? Color(.systemGray3) : Color.accentColor)
                }
                .disabled(store.text.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $store.text.sending(\.textChanged))
                .font(.system(size: 22))
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .padding(12)

            if store.text.isEmpty {
                Text("이번주 토요일 3시 강남역")
                    .font(.system(size: 22))
                    .lineSpacing(6)
                    .foregroundStyle(Color(.systemGray3))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private var bottomSection: some View {
        VStack(spacing: 0) {
            Button {} label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(.systemGray2))
                    .frame(width: 72, height: 72)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.bottom, 12)

            Text("탭하여 말하기")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.systemGray))

            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 128, height: 6)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(.systemBackground).opacity(0), location: 0),
                    .init(color: Color(.systemBackground), location: 0.3),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    ContentView(store: Store(initialState: AddScheduleFeature.State()) {
        AddScheduleFeature()
    })
}
