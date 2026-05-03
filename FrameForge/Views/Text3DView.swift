import SwiftUI
import SceneKit

struct Text3DView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text3D = "HELLO"
    @State private var depth: CGFloat = 4.0
    @State private var color3D: Color = .white
    @State private var fontName3D = "Helvetica-Bold"
    @State private var chamfer: CGFloat = 0.5

    private let fontOptions = [
        "Helvetica-Bold", "ArialRoundedMTBold", "Futura-Bold",
        "GillSans-Bold", "AvenirNext-Bold", "Menlo-Bold"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    scenePreview
                    controlPanel
                    addButton
                }
            }
            .navigationTitle("3D Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.visible)
    }

    private var scenePreview: some View {
        SceneView(
            scene: build3DScene(),
            options: [.autoenablesDefaultLighting, .allowsCameraControl]
        )
        .frame(height: 180)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Text")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                TextField("Enter text", text: $text3D)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
            }

            HStack {
                Text("Font")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: $fontName3D) {
                    ForEach(fontOptions, id: \.self) { font in
                        Text(font.replacingOccurrences(of: "-", with: " "))
                            .tag(font)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
            }

            HStack {
                Text("Depth")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                Slider(value: $depth, in: 0.5...10.0)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text(String(format: "%.1f", depth))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 30)
            }

            HStack {
                Text("Bevel")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                Slider(value: $chamfer, in: 0...2.0)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text(String(format: "%.1f", chamfer))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(width: 30)
            }

            HStack {
                Text("Color")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)
                ColorPicker("", selection: $color3D, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var addButton: some View {
        Button(action: { addToTimeline() }) {
            HStack {
                Image(systemName: "cube.fill")
                Text("Add 3D Text")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                             Color(red: 0.99, green: 0.32, blue: 0.56)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }

    private func build3DScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        let textGeometry = SCNText(string: text3D, extrusionDepth: depth)
        textGeometry.chamferRadius = chamfer
        textGeometry.font = UIFont(name: fontName3D, size: 8) ?? UIFont.boldSystemFont(ofSize: 8)
        textGeometry.firstMaterial?.diffuse.contents = UIColor(color3D)
        textGeometry.firstMaterial?.specular.contents = UIColor.white
        textGeometry.flatness = 0.2

        let textNode = SCNNode(geometry: textGeometry)
        let (min, max) = textNode.boundingBox
        let dx = (max.x - min.x) / 2
        let dy = (max.y - min.y) / 2
        textNode.position = SCNVector3(-dx, -dy, 0)

        let containerNode = SCNNode()
        containerNode.addChildNode(textNode)
        scene.rootNode.addChildNode(containerNode)

        let camera = SCNCamera()
        camera.fieldOfView = 40
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 50)
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNLight()
        light.type = .directional
        light.intensity = 1000
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 10, 20)
        scene.rootNode.addChildNode(lightNode)

        return scene
    }

    private func addToTimeline() {
        let uiColor = UIColor(color3D)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)

        let overlay = TextOverlayData(
            text: text3D,
            fontName: fontName3D,
            fontSize: 42,
            textColor: CodableColor(red: r, green: g, blue: b, alpha: 1),
            backgroundColor: nil,
            position: CGPoint(x: 0.5, y: 0.5),
            rotation: 0,
            scale: 1.0,
            animationType: "bounce"
        )
        viewModel.addTextOverlay(overlay, duration: 3.0)
        HapticManager.shared.success()
        dismiss()
    }
}
