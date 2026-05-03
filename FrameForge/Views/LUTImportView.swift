import SwiftUI
import UniformTypeIdentifiers

struct LUTImportView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var importedLUTs: [LUTData] = []
    @State private var showFilePicker = false
    @State private var importError: String?
    @State private var selectedLUTID: UUID?

    private enum Keys {
        static let importedLUTs = "importedLUTs"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    if importedLUTs.isEmpty {
                        emptyState
                    } else {
                        lutList
                    }

                    importButton

                    if let error = importError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("LUT Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
        }
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
        .onAppear { loadSavedLUTs() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.4))
            Text("No LUTs imported")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Import .cube files to apply cinematic color grades")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var lutList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(importedLUTs) { lut in
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                        VStack(alignment: .leading) {
                            Text(lut.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("\(lut.size)×\(lut.size)×\(lut.size)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Spacer()

                        let isApplied = selectedLUTID == lut.id
                        Button(action: {
                            if isApplied {
                                removeLUT()
                            } else {
                                applyLUT(lut)
                            }
                        }) {
                            Text(isApplied ? "Remove" : "Apply")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isApplied ? Color.red.opacity(0.2) : Color(red: 0.42, green: 0.36, blue: 0.91))
                                .foregroundColor(isApplied ? .red : .white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
    }

    private var importButton: some View {
        Button(action: { showFilePicker = true }) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Import .cube File")
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

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let lut = try LUTData.parse(from: url)
                    importedLUTs.append(lut)
                    saveLUTs()
                } catch {
                    importError = "Failed: \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func applyLUT(_ lut: LUTData) {
        selectedLUTID = lut.id
        viewModel.currentLUT = lut
        HapticManager.shared.light()
    }

    private func removeLUT() {
        selectedLUTID = nil
        viewModel.currentLUT = nil
    }

    private func saveLUTs() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(importedLUTs) {
            UserDefaults.standard.set(data, forKey: Keys.importedLUTs)
        }
    }

    private func loadSavedLUTs() {
        if let data = UserDefaults.standard.data(forKey: Keys.importedLUTs),
           let luts = try? JSONDecoder().decode([LUTData].self, from: data) {
            importedLUTs = luts
        }
    }
}
