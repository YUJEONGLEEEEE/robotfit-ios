import SwiftUI

struct AnalyzingView: View {
    enum Mode {
        case photos
        case store
    }

    @Environment(DiagnosisModel.self) private var model
    let mode: Mode
    @State private var bubbles: [Bubble] = []
    @State private var started = false
    @State private var bob = false

    struct Bubble: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var live = false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Headline(
                    title: mode == .photos ? "AI가 사진을 읽고 있어요" : "AI가 가게 정보를 분석하고 있어요",
                    sub: mode == .photos
                        ? "메뉴판과 주방 사진을 확인하는 중이에요.\n잠시만 기다려 주세요."
                        : "우리 가게에 딱 맞는 분석 결과를 작성 중입니다.\n잠시만 기다려주세요."
                )
                    .padding(.top, 8)
                Image("ChefRobot")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .offset(y: bob ? -6 : 6)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
                    .padding(.vertical, 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bubbles) { bubble in
                        HStack(spacing: 10) {
                            RobotMark(size: 18)
                                .frame(width: 44, height: 44)
                                .background(Color.white, in: Circle())
                            HStack(spacing: 8) {
                                if bubble.live {
                                    Circle()
                                        .fill(Color(red: 0.204, green: 0.78, blue: 0.349))
                                        .frame(width: 8, height: 8)
                                }
                                Text(bubble.live ? "\(bubble.text)~" : bubble.text)
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(bubble.live ? .white : Palette.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(bubble.live ? Palette.ink : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("AI 분석")
        .task {
            guard !started else { return }
            started = true
            bob = true
            await run()
        }
    }

    private func run() async {
        switch mode {
        case .photos: await readPhotos()
        case .store: await analyzeStore()
        }
    }

    private func readPhotos() async {
        bubbles = [Bubble(text: "메뉴판 읽는 중", live: true)]
        let kitchen = model.kitchenPhotos.compactMap(\.image)
        let menu = model.menuPhotos.compactMap(\.image)
        async let result = kitchen.isEmpty && menu.isEmpty
            ? PhotoAnalysis.example
            : PhotoAnalysisClient.analyze(kitchen: kitchen, menu: menu)
        try? await Task.sleep(for: .milliseconds(1400))
        let analysis = await result
        withAnimation {
            bubbles = [Bubble(text: "메뉴판 읽기 완료"), Bubble(text: "주방 사진 읽는 중", live: true)]
        }
        try? await Task.sleep(for: .milliseconds(1000))
        let lines = summary(analysis)
        for count in 1...lines.count {
            withAnimation { bubbles = lines.prefix(count).map { Bubble(text: $0) } }
            try? await Task.sleep(for: .milliseconds(550))
        }
        try? await Task.sleep(for: .milliseconds(500))
        guard model.path.last == .analyzing else { return }
        model.applyAnalysis(analysis)
        model.path.removeLast()
        model.path.append(.kitchenConfirm)
    }

    private func analyzeStore() async {
        let evaluation = model.evaluation
        let picked = Engine.compare(evaluation.results).compared.count
        let steps: [(live: String, done: String)] = [
            ("가게 정보 파악 중", "가게 정보를 파악했어요"),
            ("조리 공정 및 병목 구간 분석 중", model.store.processes.contains(.fry)
                ? "튀김 공정이 병목 1순위예요 (하루 손작업 약 \(Int(evaluation.diag.handMinutesPerDay.rounded()))분)"
                : "로봇이 맡을 튀김 공정이 없어요"),
            ("로봇 \(evaluation.results.count)종과 비교 중", "우리 가게 기준으로 로봇 \(picked)대를 골랐어요"),
        ]
        var done: [Bubble] = []
        for step in steps {
            withAnimation { bubbles = done + [Bubble(text: step.live, live: true)] }
            try? await Task.sleep(for: .milliseconds(1100))
            done.append(Bubble(text: step.done))
            withAnimation { bubbles = done }
            try? await Task.sleep(for: .milliseconds(450))
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard model.path.last == .diagnosing else { return }
        model.path.removeLast()
        model.path.append(.result)
    }

    private func summary(_ analysis: PhotoAnalysis) -> [String] {
        let names = analysis.menus.prefix(3).map(\.name).joined(separator: "·")
        var lines = [
            "메뉴 \(analysis.menus.count)개를 찾았어요 (\(names)\(analysis.menus.count > 3 ? " 외" : ""))",
            "주요 공정은 \(analysis.processes.map(\.label).joined(separator: "·"))이에요",
        ]
        if let fryers = analysis.fryerCount { lines.append("튀김기 \(fryers)대를 찾았어요") }
        if let hood = analysis.hasExhaustHood { lines.append("배기 후드가 \(hood ? "있어요" : "안 보여요")") }
        return lines
    }
}
