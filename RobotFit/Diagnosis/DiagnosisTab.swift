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
                    Text("주방 사진과 메뉴판만 있으면\n우리 가게에 딱 맞는 조리로봇은 무엇인지,\n언제 투자금을 회수하는지 알려드려요.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.sub)
                        .lineSpacing(3)
                        .padding(.top, 12)
                    Image("HomeRobot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 245, height: 251)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .accessibilityLabel("셰프 모자를 쓴 로봇핏 캐릭터")
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
