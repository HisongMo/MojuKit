# DynamicPageKit 接入文档

DynamicPageKit 是一个 JSON 驱动的 UIKit 原生页面渲染模块。业务 App 提供 JSON、网络适配、路由适配和安全策略，DynamicPageKit 负责解析配置、渲染 UIKit 组件、处理模板绑定和分发受控动作。

## 能力边界

DynamicPageKit 可以做：

- 根据 JSON 渲染原生 UIKit 页面
- 支持基础组件：`text`、`image`、`input`、`textarea`、`button`、`space`、`card`、`row`、`icon`、`selectableCard`
- 支持页面 `onLoad` 请求
- 支持按钮或组件点击触发 `request`、`navigate`、`nativeNavigate`、`showModal`、`openUrl`、`toast`、`track`、`setState`、`delay`、`sequence`
- 支持 `{{pageParams.xxx}}`、`{{responseKey.xxx}}` 模板绑定
- 支持输入框内容通过 `stateKey` 写入本地状态，并在请求参数中使用 `{{stateKey}}`
- 支持多页面跳转：一个 `DynamicPageViewController` 类，多份 JSON，多实例 push
- 支持固定底部区域：`fixedBottomComponents`

DynamicPageKit 不做：

- 不执行任意 Swift、Objective-C、JavaScript 或脚本
- 不允许 JSON 配置完整接口 Host
- 不允许 JSON 配置 Token、Authorization、Cookie 或敏感 Header
- 不直接依赖业务网络层、登录态、路由、Toast、埋点
- 不替代业务风控确认，支付、下单、删除、实名等高风险动作必须由业务原生代码确认

## 目录建议

如果作为 SDK 拆分，建议目录命名为：

```text
DynamicPageKit/
├── Model/
├── Render/
├── Action/
├── Data/
├── Network/
├── View/
└── Demo/
```

当前 Demo 工程中对应路径是：

```text
MojuKit/App/DynamicPage/
```

后续作为 SDK 发布时，可以把命名空间从 `DynamicPage` 逐步调整为 `DynamicPageKit`，例如：

```swift
DynamicPageViewController
DynamicPageRenderer
DynamicActionHandler
DynamicNetworkProviding
```

可以保留这些类名，也可以在正式 SDK 化时改成：

```swift
DynamicPageKitViewController
DynamicPageKitRenderer
DynamicPageKitActionHandler
DynamicPageKitNetworkProviding
```

## 最小接入

业务方需要准备三件事：

- 一份页面 JSON
- 一个网络适配器，实现 `DynamicNetworkProviding`
- 一个路由回调，实现 `onNavigate`

示例：

```swift
let page = try DynamicSchemaValidator.decodePage(from: jsonData)

let viewController = DynamicPageViewController(
    page: page,
    networkProvider: AppDynamicNetworkProvider()
)

viewController.onNavigate = { target, params in
    AppRouter.shared.route(target: target, params: params)
}

viewController.onTrackEvent = { eventName, params in
    Analytics.track(eventName, params: params)
}

viewController.onConfirmHighRiskRequest = { apiKey, params, completion in
    RiskControl.confirm(apiKey: apiKey, params: params) { approved in
        completion(approved)
    }
}

navigationController?.pushViewController(viewController, animated: true)
```

## 网络接入

DynamicPageKit 不直接请求业务接口，只定义协议：

```swift
protocol DynamicNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any
}
```

业务方实现协议，把 `apiKey` 映射到现有网络层：

```swift
final class AppDynamicNetworkProvider: DynamicNetworkProviding {
    func request(apiKey: String, params: [String: Any]) async throws -> Any {
        guard let endpoint = DynamicAPIRegistry.endpoint(for: apiKey) else {
            throw DynamicNetworkError.unsupportedAPI
        }

        return try await NetworkManager.shared.request(
            path: endpoint.path,
            method: endpoint.method.rawValue,
            parameters: params
        )
    }
}
```

注意：

- Token、签名、公共参数、设备参数由业务网络层统一添加
- JSON 只能写 `apiKey`，不能写完整 URL
- 未注册的 `apiKey` 必须拒绝执行

## 注册接口白名单

在 `DynamicAPIRegistry` 中注册允许动态页调用的接口：

```swift
enum DynamicAPIKey: String {
    case vipInfo
    case openVip
    case couponList
    case receiveCoupon
}
```

```swift
enum DynamicAPIRegistry {
    static func endpoint(for apiKey: String) -> DynamicAPIEndpoint? {
        guard let key = DynamicAPIKey(rawValue: apiKey) else {
            return nil
        }

        switch key {
        case .vipInfo:
            return DynamicAPIEndpoint(
                path: "/api/v1/vip/info",
                method: .get,
                requiresLogin: true,
                riskLevel: .normal
            )
        case .openVip:
            return DynamicAPIEndpoint(
                path: "/api/v1/vip/open",
                method: .post,
                requiresLogin: true,
                riskLevel: .confirmationRequired
            )
        case .couponList:
            return DynamicAPIEndpoint(
                path: "/api/v1/coupon/list",
                method: .get,
                requiresLogin: true,
                riskLevel: .normal
            )
        case .receiveCoupon:
            return DynamicAPIEndpoint(
                path: "/api/v1/coupon/receive",
                method: .post,
                requiresLogin: true,
                riskLevel: .normal
            )
        }
    }
}
```

## 页面 JSON 示例

```json
{
  "schemaVersion": "1.0",
  "pageId": "vip_center",
  "pageTitle": "会员中心",
  "backgroundColor": "#F7F8FA",
  "pageParams": {
    "source": "home"
  },
  "onLoad": [
    {
      "id": "load_vip_info",
      "apiKey": "vipInfo",
      "params": {
        "source": "{{pageParams.source}}"
      },
      "responseKey": "vipData",
      "showLoading": true
    }
  ],
  "components": [
    {
      "id": "title",
      "type": "text",
      "text": "{{vipData.name}}",
      "defaultText": "会员中心",
      "style": {
        "fontSize": 20,
        "fontWeight": "bold",
        "textColor": "#222222",
        "marginTop": 16,
        "marginLeft": 16,
        "marginRight": 16
      }
    },
    {
      "id": "button",
      "type": "button",
      "text": "查看详情",
      "action": {
        "type": "navigate",
        "target": "vipDetail",
        "params": {
          "vipId": "{{vipData.id}}"
        }
      }
    }
  ]
}
```

## 多页面跳转

DynamicPageKit 只需要一个页面容器类：

```swift
DynamicPageViewController
```

多个页面通过多个实例实现：

```text
DynamicPageViewController(page: List.json)
DynamicPageViewController(page: Detail.json)
DynamicPageViewController(page: Confirm.json)
```

JSON 中声明跳转：

```json
{
  "type": "button",
  "text": "查看详情",
  "action": {
    "type": "navigate",
    "target": "navigationDetail",
    "params": {
      "itemId": "item_10001",
      "source": "{{pageParams.source}}"
    }
  }
}
```

业务方在 `onNavigate` 中实现路由：

```swift
viewController.onNavigate = { [weak navigationController] target, params in
    switch target {
    case "navigationDetail":
        let page = loadDynamicPage(named: "DynamicPageNavigationDetailDemo", params: params)
        let detailVC = DynamicPageViewController(
            page: page,
            networkProvider: networkProvider
        )
        navigationController?.pushViewController(detailVC, animated: true)

    case "back":
        navigationController?.popViewController(animated: true)

    default:
        break
    }
}
```

原则：

- JSON 只写 `target` 和 `params`
- JSON 不写 Swift 类名
- JSON 不直接创建页面
- App 原生路由决定 target 对应哪个页面

## 页面参数传递

跳转参数会成为下一个页面的 `pageParams`：

```json
{
  "text": "收到参数 itemId：{{pageParams.itemId}}"
}
```

业务方可以在加载下一页 JSON 后合并参数：

```swift
let nextPage = page.mergingPageParams(params)
```

当前 Demo 已在 `DynamicPageDemoViewController` 中提供了这种示例。

## 支持的组件

| type | UIKit 实现 | 用途 |
| --- | --- | --- |
| `text` | `UILabel` | 文本 |
| `image` | `UIImageView` | 网络图片或本地图预留 |
| `input` | `UITextField` | 单行文本输入 |
| `textarea` | `UITextView` | 多行文本输入 |
| `button` | `UIButton` | 按钮动作 |
| `space` | `UIView` | 固定空白 |
| `card` | `UIView + UIStackView` | 纵向容器 |
| `row` | `UIStackView` | 横向容器 |
| `icon` | `UIImageView` | SF Symbol 或本地图标 |
| `selectableCard` | `UIView + UIStackView` | 可选卡片 |

## 输入组件

`input` 和 `textarea` 通过 `stateKey` 自动绑定本地页面状态。用户输入后，值会写入 `DynamicDataStore`，后续请求参数、文本模板和动作参数可以通过 `{{stateKey}}` 读取。

单行输入：

```json
{
  "type": "input",
  "stateKey": "plateNumber",
  "placeholder": "请输入车牌号",
  "keyboardType": "ascii",
  "maxLength": 8,
  "style": {
    "height": 44,
    "marginLeft": 16,
    "marginRight": 16,
    "paddingLeft": 12,
    "paddingRight": 12,
    "backgroundColor": "#FFFFFF",
    "textColor": "#111111",
    "fontSize": 16,
    "cornerRadius": 8
  }
}
```

多行输入：

```json
{
  "type": "textarea",
  "stateKey": "remark",
  "placeholder": "请输入备注",
  "maxLength": 50,
  "style": {
    "height": 96,
    "marginLeft": 16,
    "marginRight": 16,
    "paddingTop": 12,
    "paddingBottom": 12,
    "paddingLeft": 12,
    "paddingRight": 12,
    "backgroundColor": "#FFFFFF",
    "textColor": "#111111",
    "fontSize": 16,
    "cornerRadius": 8
  }
}
```

提交时读取输入值：

```json
{
  "type": "button",
  "text": "提交",
  "action": {
    "type": "request",
    "request": {
      "apiKey": "submit_plate_form",
      "params": {
        "plateNumber": "{{plateNumber}}",
        "remark": "{{remark}}"
      },
      "showLoading": true,
      "loadingText": "提交中",
      "successAction": {
        "type": "toast",
        "message": "提交成功"
      },
      "failureAction": {
        "type": "toast",
        "message": "提交失败，请稍后重试"
      }
    }
  }
}
```

支持的输入字段：

| 字段 | 说明 |
| --- | --- |
| `stateKey` | 输入值写入的本地状态 key，支持 `pageParams.xxx` 形式 |
| `placeholder` | 占位文案 |
| `text` | 初始值，可使用模板 |
| `defaultText` | 没有 `text` 且 state 为空时的默认值 |
| `keyboardType` | 键盘类型：`default`、`ascii`、`number`、`decimal`、`phone`、`email`、`url` |
| `maxLength` | 最大输入长度 |

第一版输入组件采用自动 state 绑定，不执行任意 JS，也不会在每次输入时重渲染整页。实时校验、`bindinput(event)` 和 `event.detail.value` 可作为后续扩展。

## 支持的动作

| action.type | 说明 |
| --- | --- |
| `navigate` | 交给业务路由 |
| `nativeNavigate` | 交给业务原生路由，跳转非动态原生页面 |
| `showModal` | 打开动态弹窗或业务弹窗 |
| `openUrl` | 安全打开 `http` / `https` 链接 |
| `toast` | 展示 Toast |
| `request` | 调用白名单接口 |
| `track` | 交给业务埋点 |
| `setState` | 更新本地页面状态并重渲染 |
| `sequence` | 按顺序执行多个动作 |
| `delay` | 延迟一段时间后继续执行子动作 |

## 请求回调和动作编排

`request` 支持成功和失败回调。回调里可以执行一个动作，也可以通过 `sequence` 顺序执行多个动作：

```json
{
  "type": "request",
  "request": {
    "apiKey": "confirm_bind_etc_card",
    "params": {
      "cardId": "{{selectedCardId}}"
    },
    "showLoading": true,
    "loadingText": "提交中",
    "successAction": {
      "type": "sequence",
      "actions": [
        {
          "type": "toast",
          "message": "绑定成功"
        },
        {
          "type": "delay",
          "delayMilliseconds": 800,
          "actions": [
            {
              "type": "navigate",
              "target": "bind_success"
            }
          ]
        }
      ]
    },
    "failureAction": {
      "type": "toast",
      "message": "绑定失败，请稍后重试"
    }
  }
}
```

`delayMilliseconds` 单位是毫秒。`delay` 可以单独等待，也可以携带 `actions`，等待结束后继续执行。

## 样式字段

常用样式：

```json
{
  "style": {
    "width": 120,
    "height": 48,
    "marginTop": 12,
    "marginLeft": 16,
    "marginRight": 16,
    "paddingTop": 8,
    "paddingBottom": 8,
    "paddingLeft": 12,
    "paddingRight": 12,
    "backgroundColor": "#FFFFFF",
    "textColor": "#222222",
    "fontSize": 16,
    "fontWeight": "medium",
    "cornerRadius": 8,
    "borderWidth": 1,
    "borderColor": "#E5E7EB",
    "alignment": "center",
    "stackAlignment": "center",
    "distribution": "fill",
    "spacing": 8,
    "contentMode": "aspectFill",
    "numberOfLines": 0
  }
}
```

颜色支持：

```text
#RGB
#RGBA
#RRGGBB
#RRGGBBAA
```

## 固定底部按钮

页面可配置 `fixedBottomComponents`：

```json
{
  "fixedBottomComponents": [
    {
      "type": "button",
      "text": "确认绑定",
      "style": {
        "height": 48,
        "backgroundColor": "#43A86B",
        "textColor": "#FFFFFF",
        "cornerRadius": 24,
        "marginLeft": 28,
        "marginRight": 28,
        "marginBottom": 18
      },
      "action": {
        "type": "toast",
        "message": "操作成功"
      }
    }
  ]
}
```

## 本地状态

`setState` 可以更新页面本地状态：

```json
{
  "type": "button",
  "text": "选择卡片",
  "action": {
    "type": "setState",
    "stateKey": "pageParams.selectedCardId",
    "value": "card_1"
  }
}
```

`selectableCard` 可以根据状态展示选中样式：

```json
{
  "type": "selectableCard",
  "stateKey": "pageParams.selectedCardId",
  "value": "card_1",
  "style": {
    "backgroundColor": "#2F80ED"
  },
  "selectedStyle": {
    "borderWidth": 2,
    "borderColor": "#FFFFFF"
  }
}
```

## 安全建议

上线前建议保持以下限制：

- 单页 JSON 不超过 1 MB
- 单页组件数不超过 200
- children 递归深度不超过 10
- 单页并发请求不超过 5
- 接口返回数据大小受限
- 未知组件不崩溃
- 未知 action 不执行
- 未知 apiKey 不请求
- `openUrl` 只允许 `http` / `https`
- 高风险接口必须原生确认
- 页面销毁后取消未完成请求和图片加载

## App Store 审核注意事项

DynamicPageKit 应定位为“配置化原生页面渲染”，避免对外描述成：

- 热更新代码
- 动态执行代码
- 脚本引擎
- 绕过审核发布功能

推荐描述：

```text
基于配置的原生页面渲染模块，用于活动页、运营页、信息展示页。
所有网络接口、登录态、权限、风控和业务动作均由 App 原生白名单控制。
```

## Demo 文件

当前工程内置示例：

- `DynamicPageDemo.json`：基础页面
- `DynamicPageAllComponentsDemo.json`：全组件展示
- `DynamicPageETCBindingDemo.json`：复杂 ETC 绑定页
- `DynamicPageNavigationListDemo.json`：跳转入口页
- `DynamicPageNavigationDetailDemo.json`：跳转详情页

Demo 首页提供：

- 基础 JSON 示例
- 全组件能力示例
- ETC 绑定复杂页示例
- 多页面跳转示例
- 上传 JSON 文件

## 后续 SDK 化待办

- 将核心类型访问级别改为 `public`
- 将 Demo 代码移出 SDK target
- 支持 Swift Package Manager
- 支持 CocoaPods 或 XCFramework 分发
- 增加正式单元测试 target
- 增加 JSON Schema 文档
- 增加组件注册机制，允许业务方注册自定义组件
- 增加路由注册表，减少业务方 switch 分发代码
- 增加图片加载协议，接入业务图片库
- 增加 Toast 协议，接入业务 Toast 工具
