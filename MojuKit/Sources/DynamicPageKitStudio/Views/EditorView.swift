import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            if let document = store.selectedDocument {
                editorHeader(for: document)

                Picker("编辑模式", selection: $store.editorMode) {
                    ForEach(ProjectStore.EditorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top], 12)

                switch store.editorMode {
                case .dkml:
                    CodeEditorView(text: dkmlBinding)
                case .dkss:
                    CodeEditorView(text: dkssBinding)
                case .js:
                    CodeEditorView(text: jsBinding)
                case .config:
                    CodeEditorView(text: configBinding)
                case .compiled:
                    CodeEditorView(text: compiledBinding, isEditable: false)
                case .diagnostics:
                    DiagnosticsView(document: document)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("没有选中页面")
                        .font(.title3)
                    Text("打开项目文件夹或新建页面后开始编辑")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(store.selectedDocument?.displayName ?? "编辑器")
    }

    private func editorHeader(for document: DynamicPageDocument) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayName)
                    .font(.headline)
                Text(document.pageDirectoryURL.path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(document.dirtyState.rawValue)
                .font(.caption)
                .foregroundStyle(document.dirtyState == .dirty ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(12)
        .background(.bar)
    }

    private var dkmlBinding: Binding<String> {
        Binding(
            get: { store.selectedDocument?.dkmlText ?? "" },
            set: { store.updateSelectedDKML($0) }
        )
    }

    private var dkssBinding: Binding<String> {
        Binding(
            get: { store.selectedDocument?.dkssText ?? "" },
            set: { store.updateSelectedDKSS($0) }
        )
    }

    private var jsBinding: Binding<String> {
        Binding(
            get: { store.selectedDocument?.jsText ?? "" },
            set: { store.updateSelectedJS($0) }
        )
    }

    private var configBinding: Binding<String> {
        Binding(
            get: { store.selectedDocument?.configJSONText ?? "" },
            set: { store.updateSelectedConfigJSON($0) }
        )
    }

    private var compiledBinding: Binding<String> {
        Binding(
            get: { store.selectedDocument?.compiledJSONText ?? "" },
            set: { _ in }
        )
    }
}

private struct CodeEditorView: View {
    @Binding var text: String
    var isEditable = true

    var body: some View {
        PlainTextEditor(text: $text, isEditable: isEditable)
            .padding(12)
    }
}
