import SceneKit
import SwiftUI

struct Kitchen3DView: View {
    let kitchen: Kitchen
    let fryLine: StoreProfile.Line
    let scannedModelURL: URL?

    @State private var scene: SCNScene?
    @State private var camera: SCNNode?

    private var key: String {
        "\(kitchen.widthM)-\(kitchen.depthM)-\(kitchen.heightM)-\(fryLine.w)-\(fryLine.d)-\(scannedModelURL?.path ?? "")"
    }

    var body: some View {
        ZStack {
            if let scene, let camera {
                SceneView(scene: scene, pointOfView: camera, options: [.allowsCameraControl])
            } else {
                ProgressView()
            }
        }
        .task(id: key) {
            let built = scannedModelURL.flatMap(Self.scannedScene) ?? Self.generatedScene(kitchen: kitchen, fryLine: fryLine)
            scene = built.scene
            camera = built.camera
        }
        .accessibilityLabel("주방 구조 3D 모델")
    }

    private static func scannedScene(_ url: URL) -> (scene: SCNScene, camera: SCNNode)? {
        guard let scene = try? SCNScene(url: url) else { return nil }
        let (minBox, maxBox) = scene.rootNode.boundingBox
        let center = SCNVector3((minBox.x + maxBox.x) / 2, (minBox.y + maxBox.y) / 2, (minBox.z + maxBox.z) / 2)
        let span = max(maxBox.x - minBox.x, maxBox.z - minBox.z, 1)
        scene.rootNode.enumerateChildNodes { node, _ in
            node.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.93, alpha: 1)
        }
        addLights(to: scene)
        return (scene, isometricCamera(looking: center, span: Double(span), in: scene))
    }

    private static func generatedScene(kitchen: Kitchen, fryLine: StoreProfile.Line) -> (scene: SCNScene, camera: SCNNode) {
        let scene = SCNScene()
        let w = Float(kitchen.widthM)
        let d = Float(kitchen.depthM)
        let h = Float(kitchen.heightM)
        let wall: Float = 0.08
        let counterHeight: Float = 0.9

        let floor = SCNBox(width: CGFloat(w), height: 0.05, length: CGFloat(d), chamferRadius: 0)
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.78, blue: 0.68, alpha: 1)
        scene.rootNode.addChildNode(node(floor, at: SCNVector3(0, -0.025, 0)))

        let wallColor = UIColor(white: 0.95, alpha: 1)
        scene.rootNode.addChildNode(box(w + wall * 2, h, wall, wallColor, at: SCNVector3(0, h / 2, -d / 2 - wall / 2)))
        scene.rootNode.addChildNode(box(wall, h, d, wallColor, at: SCNVector3(-w / 2 - wall / 2, h / 2, 0)))
        scene.rootNode.addChildNode(box(w + wall * 2, 0.35, wall, wallColor, at: SCNVector3(0, 0.175, d / 2 + wall / 2)))
        scene.rootNode.addChildNode(box(wall, 0.35, d, wallColor, at: SCNVector3(w / 2 + wall / 2, 0.175, 0)))

        let steel = UIColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1)
        let lineW = min(Float(fryLine.w) / 100, w - 0.2)
        let lineD = min(Float(fryLine.d) / 100, d / 2)
        let lineX = -w / 2 + 0.1 + lineW / 2
        let lineZ = -d / 2 + lineD / 2
        scene.rootNode.addChildNode(box(lineW, counterHeight, lineD, steel, at: SCNVector3(lineX, counterHeight / 2, lineZ)))

        let hood = box(lineW, 0.4, lineD * 0.9, UIColor(white: 0.85, alpha: 1), at: SCNVector3(lineX, h - 0.35, lineZ))
        scene.rootNode.addChildNode(hood)

        let worktableD = Float(kitchen.worktableCm) / 100
        scene.rootNode.addChildNode(box(w - 0.2, counterHeight, worktableD, steel, at: SCNVector3(0, counterHeight / 2, d / 2 - worktableD / 2)))

        let marker = SCNSphere(radius: 0.22)
        marker.firstMaterial?.diffuse.contents = UIColor(red: 0.902, green: 0.341, blue: 0.031, alpha: 1)
        marker.firstMaterial?.lightingModel = .constant
        let markerNode = node(marker, at: SCNVector3(lineX, counterHeight + 0.35, lineZ))
        let label = SCNText(string: "1", extrusionDepth: 0)
        label.font = UIFont.systemFont(ofSize: 0.28, weight: .bold)
        label.flatness = 0.005
        label.firstMaterial?.diffuse.contents = UIColor.white
        label.firstMaterial?.lightingModel = .constant
        let labelNode = SCNNode(geometry: label)
        let (minText, maxText) = labelNode.boundingBox
        labelNode.pivot = SCNMatrix4MakeTranslation((maxText.x - minText.x) / 2 + minText.x, (maxText.y - minText.y) / 2 + minText.y, 0)
        labelNode.position = SCNVector3(0, 0, 0.23)
        markerNode.addChildNode(labelNode)
        markerNode.constraints = [SCNBillboardConstraint()]
        scene.rootNode.addChildNode(markerNode)

        addLights(to: scene)
        let camera = isometricCamera(looking: SCNVector3(0, h / 5, 0), span: Double(max(w, d)), in: scene)
        return (scene, camera)
    }

    private static func node(_ geometry: SCNGeometry, at position: SCNVector3) -> SCNNode {
        let node = SCNNode(geometry: geometry)
        node.position = position
        return node
    }

    private static func box(_ w: Float, _ h: Float, _ d: Float, _ color: UIColor, at position: SCNVector3) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.01)
        geometry.firstMaterial?.diffuse.contents = color
        return node(geometry, at: position)
    }

    private static func addLights(to scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 650
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 700
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sunNode)
        scene.background.contents = UIColor.white
    }

    private static func isometricCamera(looking center: SCNVector3, span: Double, in scene: SCNScene) -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = span * 0.74
        camera.zNear = 0.1
        camera.zFar = 100
        let node = SCNNode()
        node.camera = camera
        let distance = Float(span) * 2
        node.position = SCNVector3(center.x + distance * 0.7, center.y + distance * 0.9, center.z + distance * 0.7)
        node.look(at: center)
        scene.rootNode.addChildNode(node)
        return node
    }
}
