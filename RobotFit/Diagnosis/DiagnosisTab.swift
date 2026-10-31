import SwiftUI

struct DiagnosisTab: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            DiagnosisHome()
                .navigationDestination(for: DiagnosisRoute.self) { route in
                    destination(route)
                        .toolbar(.hidden, for: .tabBar)
                }
        }
    }

    @ViewBuilder
    private func destination(_ route: DiagnosisRoute) -> some View {
        switch route {
        case .kitchenPhotos: PhotoStepView(step: .kitchen)
        case .menuPhotos: PhotoStepView(step: .menu)
        case .storeInfo: StoreInfoView()
        case .analyzing: AnalyzingView(mode: .photos)
        case .diagnosing: AnalyzingView(mode: .store)
        case .result: ResultView()
        case .compare: RecommendView()
        case .basis(let id): BasisView(robotID: id)
        case .notRecommended(let id): NotRecommendedView(robotID: id)
        case .quote: PendingView(title: "판매처 조건 비교")
        case .robot(let id): RecommendDetailView(robotID: id)
        case .compareRobots(let ids): RobotCompareView(robotIDs: ids)
        }
    }
}

private struct DiagnosisHome: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("RobotFit")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 4)
                Card(padding: 24) {
                    Text("어떤 로봇이\n우리 가게에 맞을까요?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(4)
                    Text("주방 사진과 메뉴판만 있으면\n조리로봇이 들어가는지, 언제 본전인지 알려 드려요.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.sub)
                        .lineSpacing(3)
                        .padding(.top, 12)
                    Color.clear
                        .aspectRatio(322.0 / 332.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Image("HeroKitchen")
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(1.19)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 24)
                        .accessibilityLabel("튀김기 옆에서 일하는 튀김로봇 일러스트")
                    PrimaryButton(title: "우리 가게 진단 시작하기") {
                        model.start()
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
