import SwiftUI

struct PreviewControlView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actions
                statusSection
                urlsSection
                pageSection
                logSection
            }
            .padding(18)
        }
        .navigationTitle("Simulator")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("iPhone Simulator Preview", systemImage: "iphone")
                .font(.headline)
            Text("Studio 编译并发布 runtime JSON，真实 UIKit 页面由 iPhone Simulator 中的 Preview Host 渲染。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.startSimulatorPreview()
            } label: {
                Label("启动 iPhone 预览", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.simulatorPreview.isWorking)

            HStack(spacing: 8) {
                Button {
                    store.relaunchSimulatorHost()
                } label: {
                    Label("重启 Host", systemImage: "arrow.clockwise")
                }
                .disabled(store.simulatorPreview.isWorking)

                Button {
                    store.refreshSimulatorPreview()
                } label: {
                    Label("刷新当前页", systemImage: "bolt.circle")
                }
                .disabled(store.selectedDocument == nil)
            }
            .controlSize(.small)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("状态")
            statusRow(
                title: "Studio 服务",
                value: store.previewServer.isRunning ? "运行中" : "未运行",
                systemImage: store.previewServer.isRunning ? "checkmark.circle.fill" : "xmark.circle",
                color: store.previewServer.isRunning ? .green : .secondary
            )
            statusRow(
                title: "Revision",
                value: "\(store.previewServer.revision)",
                systemImage: "number.circle",
                color: .secondary
            )
            statusRow(
                title: "Simulator",
                value: store.simulatorPreview.selectedDeviceName,
                systemImage: "iphone.gen3",
                color: .secondary
            )
            statusRow(
                title: "Host",
                value: store.simulatorPreview.statusText,
                systemImage: store.simulatorPreview.isWorking ? "hourglass" : "app.connected.to.app.below.fill",
                color: store.simulatorPreview.isWorking ? .orange : .secondary
            )
        }
    }

    private var urlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("本地服务")
            monoValue("Active", store.previewServer.activePageURL)
            monoValue("Events", store.previewServer.eventsURL)
            monoValue("Manifest", "http://127.0.0.1:\(store.previewServer.port)/manifest.json")
        }
    }

    private var pageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("当前页面")
            labeledValue("文件", store.selectedDocument?.displayName ?? "-")
            labeledValue("标题", store.selectedPage?.pageTitle ?? "-")
            labeledValue("Page ID", store.selectedPage?.pageId ?? "-")
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("最近日志")
            Text(store.simulatorPreview.lastLog.isEmpty ? "暂无日志" : store.simulatorPreview.lastLog)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            monoValue("日志文件", store.simulatorPreview.lastLogFilePath)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
    }

    private func statusRow(title: String, value: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private func monoValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}
