import SwiftUI

struct DiagnosticsView: View {
    let document: DynamicPageDocument

    var body: some View {
        List {
            Section("诊断信息") {
                if document.diagnostics.isEmpty {
                    Text("暂无诊断")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(document.diagnostics, id: \.self) { message in
                        Label(message, systemImage: message.contains("失败") ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(message.contains("失败") ? .orange : .primary)
                    }
                }
            }

            Section("文件") {
                Text(document.dkmlURL.path(percentEncoded: false))
                    .textSelection(.enabled)
                Text(document.dkssURL.path(percentEncoded: false))
                    .textSelection(.enabled)
                Text(document.jsURL.path(percentEncoded: false))
                    .textSelection(.enabled)
                Text(document.configJSONURL.path(percentEncoded: false))
                    .textSelection(.enabled)
                Text(document.dynamicJSONURL.path(percentEncoded: false))
                    .textSelection(.enabled)
            }
        }
    }
}
