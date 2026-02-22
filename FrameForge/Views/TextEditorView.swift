import SwiftUI

struct TextEditorView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = "Your Text"
    @State private var fontSize: CGFloat = 48
    @State private var selectedFontIndex = 0
    @State private var textColor: Color = .white
    @State private var backgroundColor: Color = .black
    @State private var animation: TextAnimation = .none
    @State private var hasBackground = false
    @State private var animationTrigger = false
    @State private var duration: Double = 10

    private let fontOptions: [(name: String, displayName: String, fontName: String)] = [
        ("Bold", "Bold", "HelveticaNeue-Bold"),
        ("Rounded", "Rounded", "ArialRoundedMTBold"),
        ("Futura", "Futura", "Futura-Bold"),
        ("Avenir", "Avenir", "AvenirNext-Bold"),
        ("Georgia", "Georgia", "Georgia-Bold"),
        ("Courier", "Courier", "CourierNewPS-BoldMT"),
        ("Didot", "Didot", "Didot-Bold"),
        ("Marker", "Marker", "MarkerFelt-Wide"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewBox
                    textInput
                    fontPicker
                    sizePicker
                    durationPicker
                    colorPickers
                    animationPicker
                }
                .padding(20)
            }
            .background(Color(white: 0.1).ignoresSafeArea())
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addText()
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                    .bold()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var previewBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            Text(text.isEmpty ? "Preview" : text)
                .font(.custom(
                    fontOptions[selectedFontIndex].fontName,
                    size: min(fontSize, 40)
                ))
                .foregroundColor(textColor)
                .padding(hasBackground ? 12 : 0)
                .background(hasBackground ? backgroundColor : .clear)
                .cornerRadius(8)
                .scaleEffect(animationTrigger && animation == .bounce ? 1.2 : 1.0)
                .opacity(animationTrigger && animation == .fadeIn ? 0.3 : 1.0)
                .offset(y: animationTrigger && animation == .slideUp ? 20 : 0)
                .blur(radius: animationTrigger && animation == .glow ? 2 : 0)
                .animation(.easeInOut(duration: 0.5), value: animationTrigger)
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text")
                .font(.caption.bold())
                .foregroundColor(.gray)
            TextField("Enter your text", text: $text)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .foregroundColor(.white)
                .font(.body)
        }
    }

    private var fontPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font")
                .font(.caption.bold())
                .foregroundColor(.gray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<fontOptions.count, id: \.self) { index in
                        Button(action: { selectedFontIndex = index }) {
                            VStack(spacing: 4) {
                                Text("Aa")
                                    .font(.custom(fontOptions[index].fontName, size: 18))
                                    .foregroundColor(selectedFontIndex == index ? .white : .gray)
                                Text(fontOptions[index].displayName)
                                    .font(.system(size: 8))
                                    .foregroundColor(selectedFontIndex == index ? .white : .gray.opacity(0.6))
                            }
                            .frame(width: 60, height: 56)
                            .background(
                                selectedFontIndex == index
                                ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                : Color.white.opacity(0.08)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }

    private var sizePicker: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Size")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(fontSize))pt")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $fontSize, in: 16...120, step: 2)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
    }

    private var durationPicker: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Duration")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(duration))s")
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            Slider(value: $duration, in: 1...60, step: 1)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
    }

    private var colorPickers: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Text Color")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
                ColorPicker("", selection: $textColor, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 44)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            HStack {
                Text("Background")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
                Toggle("", isOn: $hasBackground)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                if hasBackground {
                    ColorPicker("", selection: $backgroundColor, supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 44)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var animationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Animation")
                .font(.caption.bold())
                .foregroundColor(.gray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TextAnimation.allCases, id: \.self) { anim in
                        Button(action: {
                            animation = anim
                            animationTrigger = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                animationTrigger = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                animationTrigger = false
                            }
                        }) {
                            Text(anim.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(animation == anim ? .white : .gray)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    animation == anim
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                    : Color.white.opacity(0.08)
                                )
                                .cornerRadius(16)
                        }
                    }
                }
            }
        }
    }

    private func addText() {
        let resolvedTextColor = UIColor(textColor)
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        resolvedTextColor.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

        var overlay = TextOverlayData(text: text)
        overlay.fontSize = fontSize
        overlay.fontName = fontOptions[selectedFontIndex].fontName
        overlay.textColor = CodableColor(red: tr, green: tg, blue: tb, alpha: ta)
        overlay.animationStyle = animation

        if hasBackground {
            let resolvedBgColor = UIColor(backgroundColor)
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            resolvedBgColor.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            overlay.backgroundColor = CodableColor(red: br, green: bg, blue: bb, alpha: ba)
        }

        viewModel.addTextOverlay(overlay, duration: duration)
    }
}
