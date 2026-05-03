import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedProject: Project?
    @State private var showEditor = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let project = selectedProject, showEditor {
                EditorView(project: project) {
                    withAnimation(.spring(response: 0.3)) {
                        showEditor = false
                        selectedProject = nil
                    }
                }
                .transition(.move(edge: .trailing))
            } else {
                ProjectsView { project in
                    selectedProject = project
                    withAnimation(.spring(response: 0.3)) {
                        showEditor = true
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [Project.self])
}
