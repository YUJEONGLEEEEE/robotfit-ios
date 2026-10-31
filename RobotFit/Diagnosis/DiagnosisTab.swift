import SwiftUI

struct DiagnosisTab: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            DiagnosisHome()
                .navigationDestination(for: DiagnosisRoute.self) { route in
                    switch route {
                    case .kitchenPhotos: PhotoStepView(step: .kitchen)
                    case .menuPhotos: PhotoStepView(step: .menu)
                    case .storeInfo: StoreInfoView()
                    case .analyzing: AnalyzingView()
                    case .result: ResultView()
                    case .compare: CompareView()
                    case .size: SizeView()
                    case .detail(let id): RobotDetailView(robotID: id)
                    case .basis(let id): BasisView(robotID: id)
                    case .notRecommended(let id): NotRecommendedView(robotID: id)
                    case .quote: PendingView(title: "판매처 조건 비교")
                    }
                }
        }
    }
}

private struct DiagnosisHome: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(padding: 24) {
                    Text("어떤 로봇이\n우리 가게에 맞을까요?")
                        .font(.title.bold())
                    Text("주방 사진과 메뉴판만 있으면\n조리로봇이 들어가는지, 언제 본전인지 알려 드려요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    Image("ChefRobot")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    PrimaryButton(title: "우리 가게 진단 시작하기") {
                        model.start()
                    }
                    Text("로봇을 팔지 않는 중립 진단이에요. 맞지 않으면 비추천도 알려 드려요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("로봇핏")
    }
}
