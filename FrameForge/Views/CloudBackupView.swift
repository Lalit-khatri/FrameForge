import SwiftUI

struct CloudBackupView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var syncManager = CloudSyncManager()
    @State private var isAccountAvailable = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if !isAccountAvailable {
                    noAccountView
                } else if syncManager.isSyncing {
                    syncingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Cloud Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
        .task {
            isAccountAvailable = await syncManager.checkAccountStatus()
            if isAccountAvailable {
                await syncManager.fetchCloudProjects()
            }
        }
    }

    private var noAccountView: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.4))
            Text("iCloud Not Available")
                .font(.headline)
                .foregroundColor(.white)
            Text("Sign in to iCloud in Settings to enable cloud backup.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var syncingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: syncManager.syncProgress)
                .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
                .scaleEffect(x: 1, y: 2)
            Text("Syncing to iCloud...")
                .font(.headline)
                .foregroundColor(.white)
            Text("\(Int(syncManager.syncProgress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                Text("iCloud Backup")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let date = syncManager.lastSyncDate {
                    Text("Last: \(date, style: .relative)")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)

            Button(action: { backupCurrent() }) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Backup Current Project")
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

            if !syncManager.cloudProjects.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cloud Projects")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(syncManager.cloudProjects) { project in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                                    VStack(alignment: .leading) {
                                        Text(project.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Text(project.lastModified, style: .date)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(project.sizeBytes), countStyle: .file))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            if let error = syncManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private func backupCurrent() {
        guard let project = viewModel.currentProject else { return }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(project) else { return }
        Task {
            await syncManager.backupProject(name: project.name, data: data)
            HapticManager.shared.success()
        }
    }
}
