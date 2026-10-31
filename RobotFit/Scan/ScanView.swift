import RoomPlan
import SwiftUI

struct ScanView: View {
    @State private var isScanning = false
    @State private var measurement: KitchenMeasurement?

    var body: some View {
        NavigationStack {
            Group {
                if let measurement {
                    ScanResultView(measurement: measurement) {
                        self.measurement = nil
                        isScanning = true
                    }
                } else {
                    intro
                }
            }
            .navigationTitle("주방 스캔")
        }
        .fullScreenCover(isPresented: $isScanning) {
            RoomScanScreen { room in
                measurement = KitchenMeasurement(room: room)
                isScanning = false
            } onCancel: {
                isScanning = false
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("휴대폰으로 주방을 천천히 비춰 주세요")
                .font(.title3.bold())
            Text("벽과 설비를 인식해 주방 크기를 재고\n로봇이 들어가는지 바로 알려 드려요")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if RoomCaptureSession.isSupported {
                Button {
                    isScanning = true
                } label: {
                    Text("스캔 시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            } else {
                Text("LiDAR 센서가 있는 iPhone Pro에서만 스캔할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

private struct RoomScanScreen: View {
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
