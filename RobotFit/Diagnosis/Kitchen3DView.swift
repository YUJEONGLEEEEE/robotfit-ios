import Metal
import SceneKit
import SwiftUI
import UIKit

struct PlacedRobot: Equatable {
    let widthCm: Double
    let depthCm: Double
    let heightCm: Double
    let isPrimary: Bool
}

struct Kitchen3DView: View {
    let kitchen: Kitchen
    let fryLine: StoreProfile.Line
    var layout: [LayoutItem] = []
    var scannedModelURL: URL?
    var robots: [PlacedRobot] = []
    var steps: [String] = []
    var stepIndex = 0
    var showsMarker = true

    @State private var built: Built?

    private struct Built {
        let scene: SCNScene
        let camera: SCNNode
        let basket: SCNNode?
        let path: [SCNVector3]
    }

    private var key: String {
        "\(kitchen.widthM)-\(kitchen.depthM)-\(kitchen.heightM)-\(fryLine.w)-\(fryLine.d)-\(scannedModelURL?.path ?? "")-\(robots.map { "\($0.widthCm)x\($0.depthCm)" })-\(steps.count)-\(layout.count)"
    }

    var body: some View {
        ZStack {
            if let built {
                SceneView(scene: built.scene, pointOfView: built.camera, options: [.allowsCameraControl])
            } else {
                ProgressView()
            }
        }
        .task(id: key) {
            built = scannedModelURL.flatMap(Self.scannedScene) ?? Self.generatedScene(
                kitchen: kitchen, fryLine: fryLine, robots: robots, layout: layout, stepTitles: steps, showsMarker: showsMarker
            )
            move(to: stepIndex, animated: false)
        }
        .onChange(of: stepIndex) { _, index in
            move(to: index, animated: true)
        }
        .accessibilityLabel("주방 구조 3D 모델")
    }

    private func move(to index: Int, animated: Bool) {
        guard let built, let basket = built.basket, !built.path.isEmpty else { return }
        let target = built.path[min(max(index, 0), built.path.count - 1)]
        basket.removeAllActions()
        guard animated else {
            basket.position = target
            return
        }
        let moveAction = SCNAction.move(to: target, duration: 0.6)
        moveAction.timingMode = .easeInEaseOut
        let title = index < steps.count ? steps[index] : ""
        if title.contains("흔들") {
            let shake = SCNAction.sequence([
                .moveBy(x: 0.06, y: 0, z: 0, duration: 0.08),
                .moveBy(x: -0.12, y: 0, z: 0, duration: 0.16),
                .moveBy(x: 0.06, y: 0, z: 0, duration: 0.08),
            ])
            basket.runAction(.sequence([moveAction, .repeat(shake, count: 3)]))
        } else {
            basket.runAction(moveAction)
        }
    }

    static func snapshot(of url: URL, size: CGSize = CGSize(width: 600, height: 450)) -> UIImage? {
        guard let built = scannedScene(url) else { return nil }
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = built.scene
        renderer.pointOfView = built.camera
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    }

    private static func scannedScene(_ url: URL) -> Built? {
        guard let scene = try? SCNScene(url: url) else { return nil }
        let (minBox, maxBox) = scene.rootNode.boundingBox
        let center = SCNVector3((minBox.x + maxBox.x) / 2, (minBox.y + maxBox.y) / 2, (minBox.z + maxBox.z) / 2)
        let span = max(maxBox.x - minBox.x, maxBox.z - minBox.z, 1)
        scene.rootNode.enumerateChildNodes { node, _ in
            node.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.93, alpha: 1)
        }
        addLights(to: scene)
        return Built(scene: scene, camera: isometricCamera(looking: center, span: Double(span), in: scene), basket: nil, path: [])
    }

    private static func generatedScene(
        kitchen: Kitchen, fryLine: StoreProfile.Line, robots: [PlacedRobot], layout: [LayoutItem], stepTitles: [String], showsMarker: Bool
    ) -> Built {
        let scene = SCNScene()
        let long = Float(max(kitchen.widthM, kitchen.depthM))
        let short = Float(min(kitchen.widthM, kitchen.depthM))
        let h = Float(kitchen.heightM)
        let wall: Float = 0.08
        let counterHeight: Float = 0.9

        let floor = SCNBox(width: CGFloat(long), height: 0.05, length: CGFloat(short), chamferRadius: 0)
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.78, blue: 0.68, alpha: 1)
        scene.rootNode.addChildNode(node(floor, at: SCNVector3(0, -0.025, 0)))

        let wallColor = UIColor(white: 0.95, alpha: 1)
        scene.rootNode.addChildNode(box(long + wall * 2, h, wall, wallColor, at: SCNVector3(0, h / 2, -short / 2 - wall / 2)))
        scene.rootNode.addChildNode(box(wall, h, short, wallColor, at: SCNVector3(-long / 2 - wall / 2, h / 2, 0)))
        scene.rootNode.addChildNode(box(long + wall * 2, 0.35, wall, wallColor, at: SCNVector3(0, 0.175, short / 2 + wall / 2)))
        scene.rootNode.addChildNode(box(wall, 0.35, short, wallColor, at: SCNVector3(long / 2 + wall / 2, 0.175, 0)))

        let steel = UIColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1)
        let lineW = min(Float(fryLine.w) / 100, long - 0.2)
        let lineD = min(Float(fryLine.d) / 100, short / 2)
        var lineLeft = -long / 2 + 0.1
        var lineZ = -short / 2 + lineD / 2
        var robotOnFront = false

        if layout.isEmpty {
            if robots.isEmpty {
                scene.rootNode.addChildNode(box(lineW, counterHeight, lineD, steel, at: SCNVector3(lineLeft + lineW / 2, counterHeight / 2, lineZ)))
            } else {
                scene.rootNode.addChildNode(box(lineW, 0.02, lineD, UIColor(white: 0.55, alpha: 1), at: SCNVector3(lineLeft + lineW / 2, 0.01, lineZ)))
            }
            let worktableD = Float(kitchen.worktableCm) / 100
            scene.rootNode.addChildNode(box(long - 0.2, counterHeight, worktableD, steel, at: SCNVector3(0, counterHeight / 2, short / 2 - worktableD / 2)))
        } else {
            let placed = placeLayout(layout, long: long, short: short, in: scene, hideFryers: !robots.isEmpty)
            if let fry = placed {
                lineLeft = fry.minX
                robotOnFront = fry.onFront
                lineZ = fry.onFront ? short / 2 - lineD / 2 : -short / 2 + lineD / 2
            }
        }
        let lineX = lineLeft + lineW / 2

        let orange = UIColor(red: 0.902, green: 0.341, blue: 0.031, alpha: 1)
        var basket: SCNNode?
        var path: [SCNVector3] = []
        for (index, robot) in robots.enumerated() {
            let rw = Float(robot.widthCm) / 100
            let rd = Float(robot.depthCm) / 100
            let rh = min(Float(robot.heightCm) / 100, h - 0.05)
            let rx = lineLeft + rw / 2
            let rz = robotOnFront ? short / 2 - rd / 2 : -short / 2 + rd / 2
            let color = robot.isPrimary ? UIColor(white: 0.25, alpha: 1) : orange
            if index == 0 {
                scene.rootNode.addChildNode(box(rw, counterHeight, rd, steel, at: SCNVector3(rx, counterHeight / 2, rz)))
            }
            let frame = box(rw, rh, rd, color, at: SCNVector3(rx, rh / 2, rz))
            frame.geometry?.firstMaterial?.transparency = robot.isPrimary ? 0.22 : 0.3
            scene.rootNode.addChildNode(frame)
            scene.rootNode.addChildNode(box(rw, 0.06, 0.06, color, at: SCNVector3(rx, rh - 0.1, rz)))

            if robot.isPrimary && !stepTitles.isEmpty {
                let basketNode = box(0.32, 0.16, 0.32, orange, at: SCNVector3(rx - rw / 2 + 0.25, rh - 0.3, rz))
                basket = basketNode
                scene.rootNode.addChildNode(basketNode)
                let count = stepTitles.count
                path = stepTitles.enumerated().map { step, title in
                    let t = count == 1 ? 0.5 : Float(step) / Float(count - 1)
                    let x = rx - rw / 2 + 0.25 + t * (rw - 0.5)
                    let y: Float
                    if title.contains("튀김") || title.contains("담그") { y = counterHeight + 0.02 }
                    else if title.contains("흔들") { y = counterHeight + 0.35 }
                    else if title.contains("기름") { y = counterHeight + 0.6 }
                    else { y = rh - 0.3 }
                    return SCNVector3(x, y, rz)
                }
            }
        }

        if showsMarker {
            let marker = SCNSphere(radius: 0.22)
            marker.firstMaterial?.diffuse.contents = orange
            marker.firstMaterial?.lightingModel = .constant
            let markerNode = node(marker, at: SCNVector3(lineX, counterHeight + 0.45, lineZ))
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
        }

        addLights(to: scene)
        let camera = isometricCamera(looking: SCNVector3(0, h / 5, 0), span: Double(long), in: scene)
        return Built(scene: scene, camera: camera, basket: basket, path: path)
    }

    private static func placeLayout(
        _ layout: [LayoutItem], long: Float, short: Float, in scene: SCNScene, hideFryers: Bool
    ) -> (minX: Float, onFront: Bool)? {
        var fryXs: [Float] = []
        var fryOnFront = false
        for wall in [LayoutItem.Wall.right, .left, .back] {
            let items = layout.filter { $0.wall == wall }
            guard !items.isEmpty else { continue }
            let span = wall == .back ? short - 0.2 : long - 0.2
            let total = items.reduce(Float(0)) { $0 + Float(max($1.widthCm, 30)) / 100 }
            let squeeze = total > span ? span / total : 1
            var cursor = wall == .back ? -short / 2 + 0.1 : long / 2 - 0.1
            for item in items {
                let width = Float(max(item.widthCm, 30)) / 100 * squeeze
                let (height, depth, color) = style(item.kind)
                let along = wall == .back ? cursor + width / 2 : cursor - width / 2
                cursor += wall == .back ? width : -width
                let x: Float
                let z: Float
                let w: Float
                let d: Float
                switch wall {
                case .right:
                    (x, z, w, d) = (along, -short / 2 + depth / 2, width, depth)
                case .left:
                    (x, z, w, d) = (along, short / 2 - depth / 2, width, depth)
                case .back:
                    (x, z, w, d) = (-long / 2 + depth / 2, along, depth, width)
                }
                if item.kind == .fryer && wall != .back {
                    fryXs.append(contentsOf: [x - w / 2, x + w / 2])
                    fryOnFront = wall == .left
                    if hideFryers { continue }
                }
                if item.kind == .shelf {
                    for level in [Float(1.1), 1.5] {
                        scene.rootNode.addChildNode(box(w, 0.04, d, color, at: SCNVector3(x, level, z)))
                    }
                } else {
                    scene.rootNode.addChildNode(box(w, height, d, color, at: SCNVector3(x, height / 2, z)))
                    if item.kind == .fryer {
                        let oil = UIColor(red: 0.902, green: 0.62, blue: 0.2, alpha: 1)
                        scene.rootNode.addChildNode(box(w * 0.8, 0.02, d * 0.7, oil, at: SCNVector3(x, height + 0.01, z)))
                    }
                }
            }
        }
        guard let minX = fryXs.min() else { return nil }
        return (minX, fryOnFront)
    }

    private static func style(_ kind: LayoutItem.Kind) -> (height: Float, depth: Float, color: UIColor) {
        switch kind {
        case .fryer: (0.9, 0.7, UIColor(white: 0.35, alpha: 1))
        case .sink: (0.9, 0.7, UIColor(red: 0.72, green: 0.80, blue: 0.86, alpha: 1))
        case .fridge: (1.9, 0.75, UIColor(white: 0.88, alpha: 1))
        case .worktable: (0.9, 0.7, UIColor(red: 0.78, green: 0.80, blue: 0.82, alpha: 1))
        case .shelf: (0.04, 0.35, UIColor(red: 0.74, green: 0.76, blue: 0.78, alpha: 1))
        case .dishwasher: (0.9, 0.7, UIColor(white: 0.8, alpha: 1))
        case .other: (0.9, 0.6, UIColor(white: 0.7, alpha: 1))
        }
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
        camera.orthographicScale = span * 0.55
        camera.zNear = 0.1
        camera.zFar = 100
        let node = SCNNode()
        node.camera = camera
        let distance = Float(span) * 2
        node.position = SCNVector3(center.x + distance * 0.55, center.y + distance * 0.9, center.z + distance * 0.8)
        node.look(at: center)
        scene.rootNode.addChildNode(node)
        return node
    }
}
