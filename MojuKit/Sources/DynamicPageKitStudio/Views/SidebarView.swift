import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            projectHeader
            pathLoader

            List(selection: selectionBinding) {
                Section("Pages") {
                    ForEach(store.documents) { document in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(document.displayName)
                                .lineLimit(1)
                            Spacer()
                            if document.dirtyState == .dirty {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .tag(document.id)
                    }
                }
            }

            Text(store.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.bar)
        }
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DynamicPageKit Studio")
                .font(.headline)
            Text(store.projectURL?.path(percentEncoded: false) ?? "未打开项目")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var pathLoader: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("项目文件夹路径", text: $store.projectPathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .onSubmit {
                    store.loadProjectPath(store.projectPathText)
                }

            HStack(spacing: 8) {
                Button {
                    store.loadProjectPath(store.projectPathText)
                } label: {
                    Label("加载", systemImage: "arrow.right.circle")
                }
                .disabled(store.projectPathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    store.loadDevelopmentProjectFromBundle()
                } label: {
                    Label("当前工程", systemImage: "shippingbox")
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                guard let url else { return }
                Task { @MainActor in
                    store.projectPathText = url.path(percentEncoded: false)
                    store.loadProjectPath(store.projectPathText)
                }
            }
            return true
        }
    }

    private var selectionBinding: Binding<DynamicPageDocument.ID?> {
        Binding(
            get: { store.selectedDocumentID },
            set: { store.select($0) }
        )
    }
}
