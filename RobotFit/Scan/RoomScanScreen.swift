import RoomPlan
import SwiftUI

struct RoomScanScreen: View {
    let onFinish: (CapturedRoom) -> Void
    let onCancel: () -> Void

    @State private var stopRequested = false
    @State private var captured: CapturedRoom?

    var body: some View {
        ZStack(alignment: .top) {
            RoomCaptureContainer(stopRequested: $stopRequested) { room in
                captured = room
            }
            .ignoresSafeArea()

            HStack {
                Button("취소", action: onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                if let captured {
                    Button("결과 보기") { onFinish(captured) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(stopRequested ? "정리하는 중…" : "스캔 완료") { stopRequested = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(stopRequested)
                }
            }
            .tint(Color.accentColor)
            .padding()
        }
    }
}
