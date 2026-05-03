import AppIntents

struct NewProjectIntent: AppIntent {
    static var title: LocalizedStringResource = "New Project"
    static var description = IntentDescription("Create a new FrameForge project")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct ImportMediaIntent: AppIntent {
    static var title: LocalizedStringResource = "Import Media"
    static var description = IntentDescription("Import photos or videos into FrameForge")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct RecordVoiceoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Voiceover"
    static var description = IntentDescription("Start a voiceover recording in FrameForge")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct FrameForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewProjectIntent(),
            phrases: [
                "Create a new \(.applicationName) project",
                "New video in \(.applicationName)"
            ],
            shortTitle: "New Project",
            systemImageName: "plus.rectangle.fill"
        )
        AppShortcut(
            intent: ImportMediaIntent(),
            phrases: [
                "Import media into \(.applicationName)",
                "Add video to \(.applicationName)"
            ],
            shortTitle: "Import Media",
            systemImageName: "photo.on.rectangle"
        )
        AppShortcut(
            intent: RecordVoiceoverIntent(),
            phrases: [
                "Record voiceover in \(.applicationName)"
            ],
            shortTitle: "Record Voiceover",
            systemImageName: "mic.fill"
        )
    }
}
