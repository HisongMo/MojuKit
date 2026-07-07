# MojuKit 接入文档

MojuKit 是一个面向 iOS App 的 UIKit 动态页面运行时 SDK。它消费已经编译好的 runtime JSON，负责解析、校验、渲染原生页面，并把网络请求、路由、埋点、弹窗等业务行为回调给接入方。

MojuKit 第一版不包含编辑器、VS Code 插件、DKML 编译器、Preview Host，也不内置后台远程拉取客户端。

当前源码包最低支持 iOS 15。

## 安装

### 本地 Swift Package

在 Xcode 中选择：

```text
File -> Add Package Dependencies...
```

选择本地路径：

```text
/Users/wangleihaoshuaio/Developer/Demo/MojuKit/MojuKit
```

然后在业务 target 中添加 product：

```text
MojuKit
```

业务代码中引入：

```swift
import MojuKit
```

## 打开本地 JSON 页面

```swift
import UIKit
import MojuKit

final class AppNetworkProvider: MojuNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any {
        // 由业务 App 按 apiKey 路由到真实接口。
        return ["success": true]
    }
}

final class AppImageProvider: MojuImageProviding {
    func image(named name: String) -> UIImage? {
        // 如果业务 App 有自己的图片体系，可以在这里接入。
        UIImage(named: name)
    }

    func systemImage(named name: String) -> UIImage? {
        UIImage(systemName: name)
    }
}

func openMojuPage(jsonData: Data, navigationController: UINavigationController) {
    do {
        let page = try MojuSchemaValidator.decodePage(from: jsonData)
        let viewController = MojuPageViewController(
            page: page,
            networkProvider: AppNetworkProvider(),
            imageProvider: AppImageProvider()
        )

        viewController.onNavigate = { target, params in
            // target 可以是另一个 runtime JSON 页面 ID。
        }

        viewController.onNativeNavigate = { target, params in
            // target 可以映射到业务原生页面。
        }

        viewController.onShowModal = { target, params in
            // target 可以映射到一个 modal runtime JSON。
        }

        viewController.onTrackEvent = { eventName, params in
            // 接入业务埋点。
        }

        viewController.onConfirmHighRiskRequest = { apiKey, params, completion in
            // 高风险请求确认。确认后调用 completion(true)。
            completion(true)
        }

        navigationController.pushViewController(viewController, animated: true)
    } catch {
        // JSON 无效、schema 不支持、组件过深等错误会在这里抛出。
    }
}
```

如果业务 App 没有自定义图片体系，可以省略 `imageProvider`，MojuKit 会默认使用 `UIImage(named:)` 和 `UIImage(systemName:)`。

## 业务需要实现的能力

### 网络请求

MojuKit 不直接访问业务接口。页面 JSON 中的 request action 会调用：

```swift
func request(apiKey: String, params: [String: Any]) async throws -> Any
```

业务 App 根据 `apiKey` 分发到真实接口，并返回可以被 JSON 序列化的数据结构，例如：

```swift
return [
    "cardId": "card_10001",
    "status": "success"
]
```

如果接口没有返回值，可以返回：

```swift
return [:]
```

### 动态页跳转

当 JSON 触发：

```json
{ "type": "navigate", "target": "ETCDetail" }
```

SDK 会回调：

```swift
viewController.onNavigate = { target, params in
    // 业务侧加载 target 对应 JSON，再 push 新的 MojuPageViewController。
}
```

一个 `MojuPageViewController` 类可以承载多个页面。每次跳转创建一个新的 `MojuPageViewController` 实例即可。

### 跳转原生页面

当 JSON 触发：

```json
{ "type": "nativeNavigate", "target": "NativeTest" }
```

SDK 会回调：

```swift
viewController.onNativeNavigate = { target, params in
    // 业务 App 自己打开原生 UIViewController。
}
```

### 弹窗

当 JSON 触发：

```json
{ "type": "showModal", "target": "confirm_bind_card_modal" }
```

SDK 会回调：

```swift
viewController.onShowModal = { target, params in
    // 业务侧加载 modal JSON 并用自定义容器展示。
}
```

## Runtime JSON 包结构

VS Code 插件打包后会生成只包含 runtime JSON 的目录：

```text
DynamicPageKitRuntimeJSON/
├── manifest.json
├── ETCList.json
└── ETCDetail.json
```

`manifest.json` 示例：

```json
{
  "name": "DynamicPageKitRuntimeJSON",
  "generatedAt": "2026-07-06T00:00:00.000Z",
  "sourceProject": "/path/to/project",
  "activePage": "ETCList",
  "pages": [
    {
      "name": "ETCList",
      "pageId": "etc_list",
      "file": "ETCList.json"
    }
  ]
}
```

MojuKit 第一版不负责拉取后台接口。业务 App 可以自己从后台下载 `manifest.json` 和页面 JSON，然后调用：

```swift
let page = try MojuSchemaValidator.decodePage(from: data)
```

## 当前限制

- 不执行任意 JavaScript。
- 不内置远程下发客户端。
- 不包含 Studio、VS Code 插件、CLI、Preview Host。
- 不内置业务接口实现，所有请求必须由接入 App 的 `MojuNetworkProviding` 提供。
- 当前组件和布局能力以 runtime JSON 支持范围为准，不等同完整 H5/CSS。
