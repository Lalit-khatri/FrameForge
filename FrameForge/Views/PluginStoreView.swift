import SwiftUI

struct PluginStoreView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pluginManager = PluginManager()
    @State private var selectedType: FrameForgePlugin.PluginType?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    typePicker
                    pluginList
                }
            }
            .navigationTitle("Plugins")
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
    }

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", icon: "square.grid.2x2", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(FrameForgePlugin.PluginType.allCases, id: \.self) { type in
                    filterChip(title: type.rawValue, icon: type.icon, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private func filterChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(red: 0.42, green: 0.36, blue: 0.91) : Color.white.opacity(0.06))
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(16)
        }
    }

    private var filteredPlugins: [FrameForgePlugin] {
        if let type = selectedType {
            return pluginManager.plugins.filter { $0.type == type }
        }
        return pluginManager.plugins
    }

    private var pluginList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredPlugins) { plugin in
                    pluginCard(plugin)
                }
            }
            .padding(.horizontal)
        }
    }

    private func pluginCard(_ plugin: FrameForgePlugin) -> some View {
        HStack {
            Image(systemName: plugin.type.icon)
                .font(.title3)
                .foregroundColor(Color(red: 0.42, green: 0.36, blue: 0.91))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(plugin.pluginDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Label(plugin.version, systemImage: "tag")
                    Label(plugin.author, systemImage: "person")
                }
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { _ in pluginManager.togglePlugin(plugin.id) }
            ))
            .labelsHidden()
            .tint(Color(red: 0.42, green: 0.36, blue: 0.91))
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}
