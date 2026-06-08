import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Project.modifiedAt, order: .reverse) private var projects: [Project]
    @State private var showNewProject = false
    @State private var newProjectName = ""
    @State private var selectedAspectRatio: AspectRatio = .landscape16x9
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showProjectLimitAlert = false
    @State private var showProUpgrade = false
    @State private var projectToDelete: Project?
    @ObservedObject private var store = StoreKitManager.shared

    private var maxProjects: Int { store.isPro ? 10 : 5 }

    var onSelectProject: (Project) -> Void

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                // Sticky header — never scrolls
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .background(Color.black)
                    .padding(.top, 24)

                // Scrollable content below
                ScrollView {
                    VStack(spacing: 24) {
                        newProjectButton
                        if !projects.isEmpty {
                            projectsGrid
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showNewProject) {
            newProjectSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Project Limit Reached", isPresented: $showProjectLimitAlert) {
            if !store.isPro {
                Button("Upgrade to Pro") { showProUpgrade = true }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.isPro
                 ? "Pro accounts can save up to 10 projects. Delete an existing project to create a new one."
                 : "Free accounts can save up to 5 projects. Upgrade to Pro for 10 projects, or delete an existing one.")
        }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView()
        }
        .alert("Delete Project?",
               isPresented: Binding(
                   get: { projectToDelete != nil },
                   set: { if !$0 { projectToDelete = nil } }
               )
        ) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    modelContext.delete(project)
                    try? modelContext.save()
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("This will permanently delete \"\(projectToDelete?.name ?? "")\" and all its clips. This cannot be undone.")
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FrameForge")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("Video Editor")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Menu {
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
                Button(action: { showAbout = true }) {
                    Label("About FrameForge", systemImage: "info.circle")
                }
                Button(action: { requestReview() }) {
                    Label("Rate App", systemImage: "star")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var newProjectButton: some View {
        Button(action: {
            if projects.count >= maxProjects {
                showProjectLimitAlert = true
                return
            }
            newProjectName = ""
            selectedAspectRatio = .landscape16x9
            showNewProject = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.91),
                                     Color(red: 0.99, green: 0.32, blue: 0.56)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Project")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Start editing a new video")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var projectsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Projects")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(projects) { project in
                    projectCard(project)
                }
            }
        }
    }

    private func projectCard(_ project: Project) -> some View {
        Button(action: {
            project.modifiedAt = Date()
            onSelectProject(project)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))

                    if let data = project.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .cornerRadius(12)

                Text(project.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(formattedDate(project.modifiedAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                projectToDelete = project
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            Text("No projects yet")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Tap \"New Project\" to start editing")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var newProjectSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Name")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    TextField("My Video Project", text: $newProjectName)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.body)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Aspect Ratio")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(AspectRatio.allCases, id: \.self) { ratio in
                            Button(action: { selectedAspectRatio = ratio }) {
                                VStack(spacing: 6) {
                                    Image(systemName: ratio.icon)
                                        .font(.title2)
                                    Text(ratio.rawValue)
                                        .font(.caption.bold())
                                    Text(ratio.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedAspectRatio == ratio
                                    ? Color(red: 0.42, green: 0.36, blue: 0.91).opacity(0.3)
                                    : Color.white.opacity(0.05)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedAspectRatio == ratio
                                            ? Color(red: 0.42, green: 0.36, blue: 0.91)
                                            : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                Button(action: createProject) {
                    Text("Create Project")
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
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
            .background(Color(white: 0.1).ignoresSafeArea())
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewProject = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = name.isEmpty ? "Untitled Project" : name
        let finalName = uniqueProjectName(baseName)
        let project = Project(name: finalName, aspectRatio: selectedAspectRatio)
        modelContext.insert(project)
        showNewProject = false
        newProjectName = ""
        onSelectProject(project)
    }

    private func uniqueProjectName(_ baseName: String) -> String {
        let existingNames = Set(projects.map(\.name))
        if !existingNames.contains(baseName) { return baseName }

        var counter = 2
        while existingNames.contains("\(baseName) \(counter)") {
            counter += 1
        }
        return "\(baseName) \(counter)"
    }
}
