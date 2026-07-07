import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var isProjectSheetPresented = false
    @State private var isNewPageSheetPresented = false
    @State private var newPageMode: NewPageSheet.Mode = .blank

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } content: {
            PreviewControlView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            EditorView()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isProjectSheetPresented = true
                } label: {
                    Label("打开文件夹", systemImage: "folder")
                }

                Button {
                    store.loadDevelopmentProjectFromBundle()
                } label: {
                    Label("当前工程", systemImage: "shippingbox")
                }

                Button {
                    newPageMode = .importJSON
                    isNewPageSheetPresented = true
                } label: {
                    Label("导入 JSON", systemImage: "square.and.arrow.down")
                }

                Button {
                    newPageMode = .blank
                    isNewPageSheetPresented = true
                } label: {
                    Label("新建页面", systemImage: "doc.badge.plus")
                }

                Divider()

                Button {
                    store.saveSelected()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(store.selectedDocument == nil)

                Button {
                    store.formatSelectedCode()
                } label: {
                    Label("格式化", systemImage: "wand.and.stars")
                }
                .disabled(store.selectedDocument == nil)

                Button {
                    store.validateSelected()
                } label: {
                    Label("校验", systemImage: "checkmark.seal")
                }
                .disabled(store.selectedDocument == nil)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Label(
                        store.previewServer.isRunning ? "预览服务运行中" : "预览服务未运行",
                        systemImage: store.previewServer.isRunning ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(store.previewServer.isRunning ? .green : .secondary)

                    Text("rev \(store.previewServer.revision)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        store.startPreviewServer()
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .disabled(store.previewServer.isRunning)
                    .help("启动预览服务")

                    Button {
                        store.previewServer.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .disabled(!store.previewServer.isRunning)
                    .help("停止预览服务")
                }
                .controlSize(.small)
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            store.checkExternalChanges()
        }
        .alert("检测到外部修改", isPresented: externalChangeBinding) {
            Button("从磁盘刷新") {
                store.reloadSelectedFromDisk()
            }
            Button("保留当前编辑", role: .cancel) {
                store.externalChangeMessage = nil
            }
        } message: {
            Text(store.externalChangeMessage ?? "")
        }
        .sheet(isPresented: $isProjectSheetPresented) {
            OpenProjectSheet(isPresented: $isProjectSheetPresented)
                .environmentObject(store)
        }
        .sheet(isPresented: $isNewPageSheetPresented) {
            NewPageSheet(isPresented: $isNewPageSheetPresented, initialMode: newPageMode)
                .environmentObject(store)
        }
    }

    private var externalChangeBinding: Binding<Bool> {
        Binding(
            get: { store.externalChangeMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.externalChangeMessage = nil
                }
            }
        )
    }
}

struct OpenProjectSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Binding var isPresented: Bool
    @State private var pathText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("打开项目文件夹")
                .font(.headline)

            Text("选择一个文件夹作为 DynamicPageKit 项目。项目内的页面会放在 pages/ 下，页面之间可以通过 navigate 互相跳转。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            dropTarget(
                title: "拖入项目文件夹",
                subtitle: "也可以在下面粘贴文件夹路径"
            ) { url in
                pathText = url.path(percentEncoded: false)
            }

            TextField("项目文件夹路径", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit(load)

            HStack {
                Button("当前工程") {
                    store.loadDevelopmentProjectFromBundle()
                    pathText = store.projectPathText
                    isPresented = false
                }
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                Button("打开") {
                    load()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear {
            pathText = store.projectPathText
        }
    }

    private func load() {
        store.projectPathText = pathText
        store.loadProjectPath(pathText)
        if store.projectURL != nil {
            isPresented = false
        }
    }
}

struct NewPageSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case blank = "空白页面"
        case importJSON = "从 JSON 导入"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: ProjectStore
    @Binding var isPresented: Bool
    let initialMode: Mode
    @State private var mode: Mode = .blank
    @State private var pageName = "NewPage"
    @State private var jsonPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建页面")
                .font(.headline)

            Picker("类型", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if mode == .blank {
                TextField("页面目录名，例如 ETCList", text: $pageName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(create)
            } else {
                dropTarget(
                    title: "拖入 JSON 文件",
                    subtitle: "JSON 会转换成 dkml/dkss/js/json 四文件结构"
                ) { url in
                    jsonPath = url.path(percentEncoded: false)
                }

                TextField("JSON 文件路径", text: $jsonPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(create)
            }

            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                Button(mode == .blank ? "创建" : "导入") {
                    create()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPrimaryDisabled)
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear {
            mode = initialMode
        }
    }

    private var isPrimaryDisabled: Bool {
        switch mode {
        case .blank:
            return pageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .importJSON:
            return jsonPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func create() {
        let beforeCount = store.documents.count
        switch mode {
        case .blank:
            store.createPage(named: pageName)
        case .importJSON:
            store.importJSONPath(jsonPath)
        }
        if store.documents.count > beforeCount {
            isPresented = false
        }
    }
}

private func dropTarget(title: String, subtitle: String, onDropURL: @escaping (URL) -> Void) -> some View {
    VStack(spacing: 6) {
        Image(systemName: "tray.and.arrow.down")
            .font(.title2)
            .foregroundStyle(.secondary)
        Text(title)
            .font(.callout.weight(.medium))
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(Color(nsColor: .textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay {
        RoundedRectangle(cornerRadius: 8)
            .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
    }
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
                onDropURL(url)
            }
        }
        return true
    }
}
