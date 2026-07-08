# MojuKit 接入文档

MojuKit 是一个面向 iOS App 的 UIKit 动态页面运行时 SDK。它负责解析页面数据、校验 schema、渲染原生界面，并把网络、路由、埋点、弹窗等业务行为回调给接入方。

本文只讲“怎么接”，组件、动作、样式、循环、列表等能力细节请看 [MojuKit 能力支持列表](./MojuKit-Capability-Support.md)。

当前源码包最低支持 iOS 15。

## 安装

在 Xcode 中通过 GitHub URL 添加 Swift Package：

```text
https://github.com/HisongMo/MojuKit.git
```

如果是本地源码调试，可以添加仓库根目录，或直接添加本仓库内的 `MojuKit/MojuKit` 目录。把 `MojuKit` 加到业务 target 后，代码中引入：

```swift
import MojuKit
```

## 最小接入

业务侧最少需要准备三件事：

1. 一份页面 JSON 或 `.dpk` 包解码出来的 `MojuPage`
2. 一个网络适配器，实现 `MojuNetworkProviding`
3. 一个页面容器，创建 `MojuPageViewController`

```swift
import UIKit
import MojuKit

final class AppNetworkProvider: MojuNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any {
        // 由业务 App 把 apiKey 映射到真实接口。
        return ["success": true]
    }
}

final class AppImageProvider: MojuImageProviding {
    func image(named name: String) -> UIImage? {
        // 如果业务有自己的图片封装，在这里接入。
        BaseImage(named: name)?.image
    }

    func systemImage(named name: String) -> UIImage? {
        // 系统 SF Symbols 继续保留。
        UIImage(systemName: name)
    }
}

func openPage(jsonData: Data, navigationController: UINavigationController) {
    do {
        let page = try MojuSchemaValidator.decodePage(from: jsonData)
        let viewController = MojuPageViewController(
            page: page,
            networkProvider: AppNetworkProvider(),
            imageProvider: AppImageProvider()
        )

        viewController.onNavigate = { target, params in
            // 加载 target 对应的页面 JSON，再 push 一个新的 MojuPageViewController。
        }

        viewController.onNativeNavigate = { target, params in
            // 映射到业务原生页面。
        }

        viewController.onShowModal = { target, params in
            // 映射到业务弹窗或动态弹窗容器。
        }

        viewController.onTrackEvent = { eventName, params in
            // 接入业务埋点。
        }

        viewController.onConfirmHighRiskRequest = { apiKey, params, completion in
            // 高风险请求由业务侧确认后再继续。
            completion(true)
        }

        navigationController.pushViewController(viewController, animated: true)
    } catch {
        // JSON 无效、schema 不支持、组件过深等错误都会在这里抛出。
    }
}
```

如果业务没有自定义图片体系，可以不传 `imageProvider`，MojuKit 会使用默认的 `UIImage(named:)` 和 `UIImage(systemName:)`。

## 图片接入

MojuKit 不假设业务 App 的图片加载方式。`MojuImageProviding` 主要负责两件事：

1. 普通图片名查找
2. 系统图标名查找

```swift
final class AppImageProvider: MojuImageProviding {
    func image(named name: String) -> UIImage? {
        BaseImage(named: name)?.image
    }

    func systemImage(named name: String) -> UIImage? {
        UIImage(systemName: name)
    }
}
```

适用场景：

- `image` 组件的占位图 `placeholderImage`
- `icon` 组件的 `iconName`
- 业务自己的图片资源命名体系

## 网络接入

MojuKit 不直接请求业务接口，只定义协议：

```swift
public protocol MojuNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any
}
```

接入建议：

- `apiKey` 只表示业务允许的能力名，不要在 JSON 里写完整 URL
- Token、签名、公共参数、设备参数由业务网络层统一注入
- 返回值建议是 `Dictionary`、`Array`、`String`、`Int`、`Bool` 这类可序列化对象

## 路由与埋点回调

MojuKit 把页面层行为回调给业务 App，由业务决定是否跳转、怎么跳转、跳到哪里。

- `onNavigate`：动态页跳转
- `onNativeNavigate`：原生页面跳转
- `onShowModal`：弹窗或模态页
- `onTrackEvent`：埋点
- `onConfirmHighRiskRequest`：高风险请求确认

这几个回调都挂在 `MojuPageViewController` 上，创建后直接赋值即可。

## JSON 和 DPK

本地调试可以直接解 JSON：

```swift
let page = try MojuSchemaValidator.decodePage(from: jsonData)
```

线上包可以用 `.dpk` 解码：

```swift
let package = try MojuDPKDecoder.decodePackage(
    from: data,
    secret: Data("your-app-secret".utf8)
)

if let page = package.activePage {
    let vc = MojuPageViewController(
        page: page,
        networkProvider: AppNetworkProvider(),
        imageProvider: AppImageProvider()
    )
}
```

如果需要按名字或 `pageId` 取指定页面：

```swift
let page = try MojuDPKDecoder.decodePage(
    named: "ETCList",
    from: data,
    secret: Data("your-app-secret".utf8)
)
```

`MojuDPKPackage` 还会带出发布信息：

- `releaseTitle`
- `releaseDescription`
- `generatedAt`

解码失败会区分格式错误、版本不支持、密钥错误、解密失败、manifest 缺失和页面不存在。密钥不要硬编码进 SDK，应该由业务 App 持有，并与插件侧配置保持一致。

## 预览工程

仓库内的预览宿主工程是：

```text
MojuKit/MojuKitPreview.xcodeproj
```

对应 scheme 和 app 名称都是 `MojuKitPreview`。VS Code 插件和预览启动流程会用这份工程来跑模拟器预览。

## 页面入口约束

`MojuPage` 需要满足这些基础约束：

- `schemaVersion` 当前主版本是 `1`
- `components` 不能为空
- 页面总组件数和层级有上限
- 未知组件、未知动作、非法 JSON 都会被判为错误

## 现在你需要记住的只有这些

1. App 负责网络、图片、路由、埋点和风控确认
2. MojuKit 负责解析、渲染、模板绑定和动作分发
3. 组件、动作、样式和循环细节都在 [MojuKit 能力支持列表](./MojuKit-Capability-Support.md)
