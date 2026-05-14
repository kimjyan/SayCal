import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            footer
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        HStack {
            if store.step != .welcome {
                Button("뒤로") { store.send(.backTapped) }
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            if store.step != .examples {
                Button("건너뛰기") { store.send(.skipTapped) }
                    .foregroundStyle(Color(.systemGray))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 44)
    }

    @ViewBuilder
    private var content: some View {
        switch store.step {
        case .welcome:    welcomeStep
        case .permissions: permissionsStep
        case .examples:    examplesStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
            Text("한 문장으로\n일정을 추가하세요")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            Text("말하거나 입력만 하면\n캘린더에 자동으로 정리됩니다.")
                .font(.system(size: 17))
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("권한이 필요해요")
                    .font(.system(size: 24, weight: .bold))
                Text("아래 세 가지가 있어야 일정이 정확히 저장됩니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.systemGray))
            }
            .padding(.top, 24)

            permissionRow(
                icon: "calendar",
                title: "캘린더",
                detail: "일정을 저장하기 위해 필요해요.",
                granted: store.isCalendarGranted,
                shown: store.hasRequestedPermissions
            )
            permissionRow(
                icon: "waveform",
                title: "음성 인식",
                detail: "말한 내용을 일정 텍스트로 바꿉니다.",
                granted: store.isSpeechGranted,
                shown: store.hasRequestedPermissions
            )
            permissionRow(
                icon: "mic.fill",
                title: "마이크",
                detail: "음성 입력에 필요해요.",
                granted: store.isMicGranted,
                shown: store.hasRequestedPermissions
            )

            if store.hasRequestedPermissions && !(store.isCalendarGranted && store.isSpeechGranted && store.isMicGranted) {
                Text("거부된 권한은 설정 앱에서 언제든 다시 허용할 수 있어요.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray))
                    .padding(.top, 4)
            }

            Spacer()
        }
    }

    private func permissionRow(icon: String, title: String, detail: String, granted: Bool, shown: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(Color(.systemGray))
            }

            Spacer()

            if shown {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(granted ? Color.green : Color(.systemGray3))
            }
        }
    }

    private var examplesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("이렇게 말해보세요")
                    .font(.system(size: 24, weight: .bold))
                Text("정확한 형식은 필요 없어요. 자연스럽게 말하면 됩니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.systemGray))
            }
            .padding(.top, 24)

            exampleCard("이번주 토요일 3시 강남역")
            exampleCard("내일 오전 9시 회의")
            exampleCard("다음주 금요일 저녁 7시 동기 모임 홍대")

            Spacer()
        }
    }

    private func exampleCard(_ text: String) -> some View {
        HStack {
            Image(systemName: "quote.opening")
                .font(.system(size: 14))
                .foregroundStyle(Color(.systemGray3))
            Text(text)
                .font(.system(size: 17))
            Spacer()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.primaryTapped)
            } label: {
                ZStack {
                    Text(primaryLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .opacity(store.isRequesting ? 0 : 1)
                    if store.isRequesting {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(store.isRequesting)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    private var primaryLabel: String {
        switch store.step {
        case .welcome:     "시작하기"
        case .permissions: store.hasRequestedPermissions ? "다음" : "권한 요청"
        case .examples:    "이제 사용해 볼게요"
        }
    }
}

#Preview {
    OnboardingView(store: Store(initialState: OnboardingFeature.State()) {
        OnboardingFeature()
    })
}
