import SwiftUI

struct CaptionsView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var engine = CaptionEngine()
    @State private var selectedStyleID = "classic"
    @State private var phase: CaptionPhase = .transcribing
    @State private var editingSegmentID: UUID?
    @State private var editText = ""

    enum CaptionPhase {
        case transcribing
        case styling
        case reviewing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch phase {
                case .transcribing:
                    transcribingPhase
                case .styling:
                    stylingPhase
                case .reviewing:
                    reviewingPhase
                }
            }
            .navigationTitle("AI Captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task { await startTranscription() }
    }

    private func startTranscription() async {
        let authorized = await engine.requestPermission()
        guard authorized else {
            engine.error = "Speech recognition permission denied. Enable it in Settings → Privacy → Speech Recognition."
            return
        }
        await engine.generateCaptions(from: viewModel.tracks)
        if engine.error == nil && !engine.segments.isEmpty {
            phase = .styling
        }
    }

    private var transcribingPhase: some View {
        VStack(spacing: 28) {
            if let error = engine.error {
                errorState(error)
            } else {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: engine.progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                         Color(red: 0.99, green: 0.32, blue: 0.56)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: engine.progress)

                    VStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                            .symbolEffect(.variableColor.iterative)
                        Text("\(Int(engine.progress * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                Text(engine.statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Analyzing video audio only")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }
        }
        .padding()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Caption Error")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Dismiss") { dismiss() }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color(red: 0.42, green: 0.36, blue: 0.91))
                .cornerRadius(14)
            Spacer()
        }
    }

    private var stylingPhase: some View {
        VStack(spacing: 20) {
            Text("Choose Caption Style")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.top, 20)

            stylePreview

            styleGrid

            Spacer()

            Button(action: { phase = .reviewing }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Continue")
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
            .padding(.bottom)
        }
    }

    private var stylePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if let style = CaptionStylePresets.all.first(where: { $0.id == selectedStyleID }) {
                let sampleText = engine.segments.first?.text ?? "Hello World"
                VStack {
                    Spacer()
                    Text(sampleText)
                        .font(.custom(style.fontName, size: style.fontSize * 0.6))
                        .foregroundColor(Color(
                            red: style.textColor.red,
                            green: style.textColor.green,
                            blue: style.textColor.blue,
                            opacity: style.textColor.alpha
                        ))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            style.backgroundColor.map { bg in
                                Color(
                                    red: bg.red,
                                    green: bg.green,
                                    blue: bg.blue,
                                    opacity: bg.alpha
                                )
                            }
                        )
                        .cornerRadius(6)
                    Spacer().frame(height: 30)
                }
            }
        }
        .padding(.horizontal)
    }

    private var styleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(CaptionStylePresets.all) { style in
                Button(action: { selectedStyleID = style.id }) {
                    VStack(spacing: 8) {
                        Image(systemName: style.icon)
                            .font(.title2)
                            .foregroundColor(selectedStyleID == style.id ? .white : .gray)
                        Text(style.name)
                            .font(.caption.bold())
                            .foregroundColor(selectedStyleID == style.id ? .white : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(
                        selectedStyleID == style.id
                        ? Color(red: 0.42, green: 0.36, blue: 0.91)
                        : Color.white.opacity(0.06)
                    )
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedStyleID == style.id
                                ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private var reviewingPhase: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Captions")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("\(engine.segments.count) segments detected")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button("Back") { phase = .styling }
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
            }
            .padding()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(engine.segments.enumerated()), id: \.element.id) { index, segment in
                        captionRow(segment, index: index)
                    }
                }
                .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button(action: { applyCaptions() }) {
                    HStack {
                        Image(systemName: "captions.bubble.fill")
                        Text("Apply \(engine.segments.count) Captions")
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

                Button(action: {
                    engine.segments.removeAll()
                    dismiss()
                }) {
                    Text("Discard All")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }

    private func captionRow(_ segment: CaptionSegment, index: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(segment.startTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text(formatTime(segment.endTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .frame(width: 50)

            if editingSegmentID == segment.id {
                TextField("Caption", text: $editText, onCommit: {
                    if let idx = engine.segments.firstIndex(where: { $0.id == segment.id }) {
                        engine.segments[idx].text = editText
                    }
                    editingSegmentID = nil
                })
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text(segment.text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        editingSegmentID = segment.id
                        editText = segment.text
                    }
            }

            Button(action: {
                engine.segments.removeAll { $0.id == segment.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }

    private func applyCaptions() {
        guard let style = CaptionStylePresets.all.first(where: { $0.id == selectedStyleID }) else { return }
        viewModel.addCaptionSegments(engine.segments, style: style)
        dismiss()
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
}
