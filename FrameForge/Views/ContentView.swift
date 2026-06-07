import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProjectsView { project in
                navigationPath.append(project)
            }
            .navigationDestination(for: Project.self) { project in
                EditorView(project: project) {
                    navigationPath.removeLast()
                }
                .navigationBarBackButtonHidden(true)
                .toolbarBackground(.hidden, for: .navigationBar)
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
