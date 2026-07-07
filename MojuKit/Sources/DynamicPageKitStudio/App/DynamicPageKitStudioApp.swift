import AppKit
import SwiftUI

final class DynamicPageKitStudioAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct DynamicPageKitStudioApp: App {
    @NSApplicationDelegateAdaptor(DynamicPageKitStudioAppDelegate.self) private var appDelegate
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 720)
                .task {
                    store.startPreviewServer()
                    store.loadDefaultProjectIfNeeded()
                }
        }
        .commands {
            CommandMenu("DynamicPageKit") {
                Button("加载项目路径") {
                    store.openProjectFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("打开当前工程") {
                    store.loadDevelopmentProjectFromBundle()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("导入 JSON...") {
                    store.importJSON()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("新建页面") {
                    store.createPage()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Divider()

                Button("保存") {
                    store.saveSelected()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("格式化当前代码") {
                    store.formatSelectedCode()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("校验") {
                    store.validateSelected()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
}
