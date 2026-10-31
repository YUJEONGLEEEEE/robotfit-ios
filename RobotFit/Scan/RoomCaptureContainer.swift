import RoomPlan
import SwiftUI

struct RoomCaptureContainer: UIViewRepresentable {
    @Binding var stopRequested: Bool
    let onCaptured: (CapturedRoom) -> Void

    func makeCoordinator() -> RoomCaptureCoordinator {
        RoomCaptureCoordinator(onCaptured: onCaptured)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = context.coordinator
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return view
    }

    func updateUIView(_ view: RoomCaptureView, context: Context) {
        guard stopRequested, !context.coordinator.stopped else { return }
        context.coordinator.stopped = true
        view.captureSession.stop()
    }

    static func dismantleUIView(_ view: RoomCaptureView, coordinator: RoomCaptureCoordinator) {
        view.captureSession.stop()
    }
}

@objc(RoomCaptureCoordinator)
final class RoomCaptureCoordinator: NSObject, RoomCaptureViewDelegate {
    let onCaptured: (CapturedRoom) -> Void
    var stopped = false

    init(onCaptured: @escaping (CapturedRoom) -> Void) {
        self.onCaptured = onCaptured
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func encode(with coder: NSCoder) {}

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        onCaptured(processedResult)
    }
}
