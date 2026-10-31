import SwiftUI

struct RobotMark: View {
    var size: CGFloat = 96

    var body: some View {
        let headWidth = size
        let headHeight = size * 0.71
        let antennaWidth = size * 0.087
        let antennaHeight = size * 0.27
        let eye = size * 0.187

        VStack(spacing: -antennaWidth / 2) {
            Capsule()
                .fill(.primary)
                .frame(width: antennaWidth, height: antennaHeight)
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(.primary)
                .frame(width: headWidth, height: headHeight)
                .overlay {
                    HStack(spacing: size * 0.153) {
                        Circle().fill(Color.accentColor).frame(width: eye, height: eye)
                        Circle().fill(Color.accentColor).frame(width: eye, height: eye)
                    }
                }
        }
        .accessibilityHidden(true)
    }
}
