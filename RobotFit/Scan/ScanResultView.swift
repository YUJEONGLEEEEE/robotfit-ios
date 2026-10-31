import SwiftUI

struct ScanResultView: View {
    let measurement: KitchenMeasurement
    let rescan: () -> Void

    var body: some View {
        List {
            Section("스캔한 주방") {
                row("주방 넓이", String(format: "약 %.1f평", measurement.areaPyeong))
                row("가로", meters(measurement.widthCm))
                row("세로", meters(measurement.depthCm))
                row("높이", meters(measurement.heightCm))
            }

            Section {
                ForEach(Catalog.robots) { robot in
                    let fit = measurement.fit(for: robot)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(robot.displayName)
                                .font(.headline)
                            if let size = robot.sizeCm {
                                Text("\(Int(size.w)) × \(Int(size.d)) × \(Int(size.h))cm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(fit.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(color(for: fit))
                    }
                }
            } header: {
                Text("로봇이 들어갈까요?")
            } footer: {
                Text("바닥 크기와 통로 \(Int(KitchenMeasurement.aisleCm))cm를 기준으로 본 참고 결과예요. 설치 위치는 판매처 실측으로 확정해요.")
            }

            if !measurement.fixtures.isEmpty {
                Section("인식한 설비") {
                    ForEach(measurement.fixtures) { fixture in
                        row(fixture.name, "\(Int(fixture.widthCm)) × \(Int(fixture.depthCm))cm")
                    }
                }
            }

            Section {
                Button("다시 스캔하기", action: rescan)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }

    private func meters(_ cm: Double) -> String {
        cm > 0 ? String(format: "%.1fm", cm / 100) : "인식 안 됨"
    }

    private func color(for fit: KitchenMeasurement.Fit) -> Color {
        switch fit {
        case .fits: .green
        case .tight: Color.accentColor
        case .noFit: .red
        case .unknown: .secondary
        }
    }
}
