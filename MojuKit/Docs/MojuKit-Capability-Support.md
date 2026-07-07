# MojuKit 能力支持列表

这份文档只回答一件事：MojuKit 运行时到底支持什么、怎么写、怎么接。

页面接入和初始化方式请看 [MojuKit 接入文档](./MojuKit-Integration.md)。

## 读法

每个能力都按下面的方式说明：

- 它解决什么问题
- JSON 里用哪些字段
- 业务 App 要实现什么
- 常见用法
- 边界和限制

## 1. 页面基础能力

### `schemaVersion`

作用：声明页面 schema 主版本。当前运行时只接受主版本 `1`。

用法：

```json
{
  "schemaVersion": "1.0"
}
```

注意：

- 主版本不是 `1` 时会直接判为不支持
- 小版本号可以用于演进，但不能破坏当前解析器

### `pageId`、`pageTitle`、`backgroundColor`

作用：

- `pageId`：页面唯一标识
- `pageTitle`：导航栏标题
- `backgroundColor`：页面背景色

用法：

```json
{
  "pageId": "vip_center",
  "pageTitle": "会员中心",
  "backgroundColor": "#F7F8FA"
}
```

注意：

- `backgroundColor` 支持十六进制颜色字符串
- `pageTitle` 会同步到 `MojuPageViewController.title`

### `pageParams`

作用：页面初始参数。适合放入口来源、业务 id、开关位、上下文信息。

用法：

```json
{
  "pageParams": {
    "source": "home",
    "cardId": "card_10001"
  }
}
```

使用指南：

- 在模板里用 `{{pageParams.source}}` 读取
- 在 `request`、`navigate`、`setState` 里也可以继续引用
- 支持字符串、数字、布尔、对象、数组和空值

### `onLoad`

作用：页面加载完成后自动执行的一组请求。

用法：

```json
{
  "onLoad": [
    {
      "id": "load_vip_info",
      "apiKey": "vipInfo",
      "params": {
        "source": "{{pageParams.source}}"
      },
      "responseKey": "vipData",
      "showLoading": true,
      "loadingText": "加载中"
    }
  ]
}
```

使用指南：

- 按顺序执行
- 每个请求都由业务侧的 `MojuNetworkProviding` 处理
- 如果有 `responseKey`，响应会写入运行时数据，后续模板可直接读取

### `navigationBar`

作用：页面级导航栏配置。

字段：

- `backgroundColor`
- `textColor`
- `hidden`
- `hideBackButton`
- `backButton`
- `rightButtons`

`backButton` 和 `rightButtons` 的按钮字段：

- `id`
- `iconName`
- `text`
- `action`

用法：

```json
{
  "navigationBar": {
    "backgroundColor": "#FFFFFF",
    "textColor": "#111111",
    "hideBackButton": false,
    "rightButtons": [
      {
        "id": "share",
        "iconName": "share",
        "action": {
          "type": "track",
          "trackEvent": "share_click"
        }
      }
    ]
  }
}
```

使用指南：

- `hidden` 为 `true` 时隐藏整个导航栏
- `hideBackButton` 只隐藏系统返回按钮
- 按钮动作仍然走统一动作系统

### `fixedBottomComponents`

作用：固定底部区域，不随正文滚动。

用法：

```json
{
  "fixedBottomComponents": [
    {
      "type": "button",
      "text": "立即开通",
      "action": {
        "type": "request",
        "request": {
          "apiKey": "openVip"
        }
      }
    }
  ]
}
```

使用指南：

- 适合放主按钮、底部确认区、固定操作条
- 渲染逻辑和正文组件一致，只是容器不同

## 2. 数据和模板

### `MojuValue`

作用：统一表达 JSON 里的值类型。

支持类型：

- `string`
- `int`
- `double`
- `bool`
- `object`
- `array`
- `null`

使用指南：

- 模板解析会尽量把值转成可读字符串
- `setState` 和 `request` 返回值都可以携带结构化数据
- 对象和数组可以继续嵌套访问

### 模板绑定

作用：在字符串里引用页面数据。

支持写法：

```json
{
  "text": "{{pageParams.userName}}"
}
```

使用指南：

- `{{pageParams.xxx}}` 读取页面参数
- `{{responseKey.xxx}}` 读取请求结果
- `{{stateKey}}` 读取本地状态
- 循环里还可以读取局部变量 `item`、`index`

### 局部变量

作用：在循环渲染时提供当前项和索引。

默认变量名：

- `item`
- `index`

可自定义：

- `forItem`
- `forIndex`

用法：

```json
{
  "type": "text",
  "text": "{{index}}. {{item.title}}",
  "forEach": "{{pageParams.items}}",
  "forItem": "item",
  "forIndex": "index"
}
```

使用指南：

- 局部变量优先于全局数据
- 不存在局部变量时，模板会回退到页面数据仓库

## 3. 通用组件属性

大部分组件都支持这些通用属性：

- `id`
- `style`
- `selectedStyle`
- `action`
- `visible`
- `stateKey`
- `value`
- `children`

### `visible`

作用：动态控制组件显示与隐藏。

用法：

```json
{
  "visible": "{{pageParams.isLoggedIn}}"
}
```

使用指南：

- `false`、`0`、空字符串、`null` 都会被视为不显示
- 对象和数组会被视为显示

### `stateKey` 与 `value`

作用：做选择态或本地状态绑定。

常见场景：

- 单选卡片
- 选中高亮
- 输入框写回本地状态

用法：

```json
{
  "type": "selectableCard",
  "stateKey": "pageParams.selectedId",
  "value": "card_1"
}
```

使用指南：

- 当前 `stateKey` 的值和 `value` 匹配时，视为选中
- `selectedStyle` 会在选中时叠加到 `style` 上

## 4. 组件支持

### `text`

作用：显示文本。

字段：

- `text`
- `defaultText`

使用指南：

- `text` 会先做模板解析
- 如果解析后为空，回退到 `defaultText`
- 适合标题、说明、标签、状态文案

示例：

```json
{
  "type": "text",
  "text": "{{vipData.name}}",
  "defaultText": "会员中心"
}
```

### `image`

作用：显示网络图片。

字段：

- `imageUrl`
- `placeholderImage`

使用指南：

- `imageUrl` 只负责 `http` / `https` 图片地址
- `placeholderImage` 用作加载前占位图
- 业务图片体系由 `MojuImageProviding.image(named:)` 提供占位图加载

示例：

```json
{
  "type": "image",
  "imageUrl": "{{pageParams.avatarUrl}}",
  "placeholderImage": "avatar_placeholder"
}
```

### `icon`

作用：显示图标，优先支持系统图标，兼容业务图标资源。

字段：

- `iconName`

使用指南：

- 先调用 `systemImage(named:)`
- 如果没有系统图标，再调用 `image(named:)`
- 适合按钮图标、状态图标、导航图标

示例：

```json
{
  "type": "icon",
  "iconName": "share"
}
```

### `button`

作用：可点击的主操作按钮。

字段：

- `text`
- `action`

使用指南：

- 使用系统 filled button 样式
- 点击后会执行 `action`
- 执行期间按钮会临时禁用，避免重复触发

示例：

```json
{
  "type": "button",
  "text": "立即开通",
  "action": {
    "type": "request",
    "request": {
      "apiKey": "openVip",
      "showLoading": true
    }
  }
}
```

### `input`

作用：单行输入框。

字段：

- `placeholder`
- `keyboardType`
- `maxLength`
- `stateKey`
- `text`
- `defaultText`

使用指南：

- `stateKey` 会自动接住当前输入值
- `text` 或 `defaultText` 可作为初始值
- `maxLength` 会在输入时截断

示例：

```json
{
  "type": "input",
  "placeholder": "请输入手机号",
  "keyboardType": "phone",
  "maxLength": 11,
  "stateKey": "phoneNumber"
}
```

### `textarea`

作用：多行输入框。

字段：

- `placeholder`
- `keyboardType`
- `maxLength`
- `stateKey`
- `text`
- `defaultText`

使用指南：

- 输入内容会自动写回 `stateKey`
- 默认自动增高，不需要手动处理换行高度
- 适合备注、说明、反馈文案

### `space`

作用：空白占位。

使用指南：

- 通常只配合 `style.width`、`style.height`、`style.spacing`
- 适合补空隙，不承载交互

### `card`

作用：纵向容器。

使用指南：

- 用来包一组竖排子组件
- `children` 会按顺序垂直渲染
- 适合卡片内容、分组内容、详情块

### `row`

作用：横向容器。

使用指南：

- `children` 会按顺序横向渲染
- 默认 `spacing` 为 `8`
- 适合左右布局、标签行、信息摘要行

### `selectableCard`

作用：可选中卡片。

使用指南：

- 选中态由 `stateKey + value` 决定
- 选中后叠加 `selectedStyle`
- 点击后先更新选中态，再执行 `action`

示例：

```json
{
  "type": "selectableCard",
  "stateKey": "pageParams.selectedCardId",
  "value": "card_1",
  "selectedStyle": {
    "borderColor": "#1677FF",
    "borderWidth": 2
  }
}
```

### `tableView`

作用：纵向列表容器。

使用指南：

- `forEach` 提供数组数据
- `children` 作为每个 cell 的模板
- 默认按一列纵向重复渲染

示例：

```json
{
  "type": "tableView",
  "forEach": "{{pageParams.cards}}",
  "forItem": "card",
  "forIndex": "cardIndex",
  "children": [
    {
      "type": "row",
      "children": [
        { "type": "text", "text": "{{cardIndex}}. " },
        { "type": "text", "text": "{{card.title}}" }
      ]
    }
  ]
}
```

### `collectionView`

作用：多列网格容器。

字段：

- `forEach`
- `forItem`
- `forIndex`
- `columns`
- `children`

使用指南：

- `columns` 默认是 `2`
- 每个 item 都按 `children` 渲染成一个网格 cell
- 不足列数时会补空白 cell，保持布局整齐

示例：

```json
{
  "type": "collectionView",
  "forEach": "{{pageParams.products}}",
  "forItem": "product",
  "columns": 3,
  "children": [
    { "type": "image", "imageUrl": "{{product.icon}}" },
    { "type": "text", "text": "{{product.name}}" }
  ]
}
```

## 5. 循环能力

### `forEach`

作用：让任意组件按数组重复渲染。

使用指南：

- 可写在普通组件上，也可写在 `tableView` 和 `collectionView` 上
- 运行时会把 `item` 和 `index` 注入到局部模板上下文
- 普通组件的 `forEach` 适合纵向重复单项

示例：

```json
{
  "type": "text",
  "text": "{{index}}. {{item.title}}",
  "forEach": "{{pageParams.items}}"
}
```

### `forItem`、`forIndex`

作用：自定义循环局部变量名。

使用指南：

- 默认值分别是 `item` 和 `index`
- 当页面里已有同名字段时，建议自定义，避免覆盖

示例：

```json
{
  "type": "text",
  "text": "{{i}} - {{row.title}}",
  "forEach": "{{pageParams.items}}",
  "forItem": "row",
  "forIndex": "i"
}
```

### `columns`

作用：控制 `collectionView` 的列数。

使用指南：

- 最小值会被修正为 `1`
- 默认值是 `2`
- 它只对 `collectionView` 生效

## 6. 动作支持

### `navigate`

作用：跳转到另一个动态页。

使用指南：

- 目标页由业务侧负责加载
- 参数通过 `params` 传递
- 对应回调是 `onNavigate`

示例：

```json
{
  "type": "navigate",
  "target": "vipDetail",
  "params": {
    "vipId": "{{vipData.id}}"
  }
}
```

### `nativeNavigate`

作用：跳转业务原生页面。

使用指南：

- 对应回调是 `onNativeNavigate`
- 适合不想用动态页承载的复杂原生流程

### `showModal`

作用：打开动态弹窗或业务模态页。

使用指南：

- 对应回调是 `onShowModal`
- 常用于确认弹窗、底部弹层、说明弹层

### `openUrl`

作用：打开外部链接。

使用指南：

- 仅接受 `http` 和 `https`
- 非法 URL 会被忽略
- 运行时通过系统浏览器打开

### `toast`

作用：显示短提示。

使用指南：

- 适合成功、失败、轻量反馈
- 空字符串不会显示

### `track`

作用：上报埋点。

使用指南：

- 对应回调是 `onTrackEvent`
- `params` 会一起传给业务埋点系统

### `setState`

作用：更新运行时本地状态。

使用指南：

- 写入后页面会重新渲染
- 常用于选择态、表单联动、结果展示
- `stateKey` 可以是类似 `pageParams.xxx` 的路径

### `request`

作用：发起业务接口请求，并把结果写回运行时数据。

字段：

- `id`
- `apiKey`
- `params`
- `responseKey`
- `showLoading`
- `loadingText`
- `successAction`
- `failureAction`

使用指南：

- `apiKey` 只表示业务接口能力，不代表真实 URL
- `params` 会先做模板解析
- 成功后如果有 `responseKey`，响应会写入数据仓库
- 成功和失败后都可以继续编排动作

示例：

```json
{
  "type": "request",
  "request": {
    "id": "load_vip_info",
    "apiKey": "vipInfo",
    "params": {
      "source": "{{pageParams.source}}"
    },
    "responseKey": "vipData",
    "showLoading": true,
    "loadingText": "加载中",
    "successAction": {
      "type": "toast",
      "message": "加载成功"
    },
    "failureAction": {
      "type": "toast",
      "message": "加载失败"
    }
  }
}
```

### `delay`

作用：延迟后继续执行动作。

使用指南：

- `delayMilliseconds` 单位是毫秒
- 常和 `sequence` 一起使用
- 适合 toast 后延迟跳转、请求后延迟收起提示

示例：

```json
{
  "type": "delay",
  "delayMilliseconds": 500,
  "actions": [
    {
      "type": "navigate",
      "target": "success"
    }
  ]
}
```

### `sequence`

作用：按顺序执行多个动作。

使用指南：

- 子动作按数组顺序执行
- 适合“先提示，再刷新，再跳转”的流程

示例：

```json
{
  "type": "sequence",
  "actions": [
    {
      "type": "toast",
      "message": "提交成功"
    },
    {
      "type": "delay",
      "delayMilliseconds": 800,
      "actions": [
        {
          "type": "navigate",
          "target": "result"
        }
      ]
    }
  ]
}
```

## 7. 样式支持

### 支持字段

`MojuStyle` 当前支持这些字段：

- `width`
- `widthMode`
- `height`
- `marginTop`
- `marginBottom`
- `marginLeft`
- `marginRight`
- `paddingTop`
- `paddingBottom`
- `paddingLeft`
- `paddingRight`
- `backgroundColor`
- `textColor`
- `fontSize`
- `fontWeight`
- `cornerRadius`
- `borderWidth`
- `borderColor`
- `alignment`
- `stackAlignment`
- `distribution`
- `spacing`
- `contentMode`
- `numberOfLines`
- `hidden`

### 使用指南

- `widthMode` 支持 `fit-content`、`hug-content`、`content`
- `alignment` 影响文本和输入控件对齐
- `stackAlignment` 和 `distribution` 影响容器布局
- `contentMode` 影响 `image` 和 `icon`
- `hidden` 会直接隐藏当前组件

### 颜色和字体

使用指南：

- 颜色使用十六进制字符串，支持 `#RGB`、`#RGBA`、`#RRGGBB`、`#RRGGBBAA`
- `fontWeight` 支持 `regular`、`medium`、`semibold`、`bold`
- `fontSize` 不传时默认 `15`

## 8. 组合能力

### `children`

作用：把多个子组件组合在一个容器里。

适用组件：

- `card`
- `row`
- `selectableCard`
- `tableView`
- `collectionView`

使用指南：

- `card` 和 `row` 会把子组件作为布局单元
- `tableView` 和 `collectionView` 会把 `children` 当成 cell 模板

## 9. 支持边界

### 运行时限制

- 单页最大组件数：`200`
- 最大递归深度：`10`
- 单次请求最大响应体：`1MB`
- 最大并发请求数：`5`
- 请求超时时间：`15s`

### 不支持的内容

- 任意 JavaScript 或脚本执行
- 任意 Swift/Objective-C 代码下发
- 未注册的接口能力
- 非 `http` / `https` 的外链打开

### 错误类型

MojuKit 会把常见失败归类成这些错误：

- `invalidJSON`
- `unsupportedSchemaVersion`
- `tooManyComponents`
- `recursionTooDeep`
- `unsupportedComponent`
- `unsupportedAction`
- `unsupportedAPI`
- `invalidURL`
- `invalidParameters`
- `requestFailed`
- `invalidResponse`
- `tooManyConcurrentRequests`
- `forbiddenAPI`
- `highRiskRequestRejected`

## 10. DPK 支持

### `MojuDPKDecoder`

作用：读取加密的 `.dpk` 包。

使用指南：

- 使用 `decodePackage(from:secret:)` 读取整个包
- 使用 `decodePage(named:from:secret:)` 按名字或 `pageId` 读取单页
- 密钥由接入 App 传入，SDK 不内置固定密钥

### `MojuDPKPackage`

包级可读信息：

- `manifest`
- `pages`
- `releaseTitle`
- `releaseDescription`
- `generatedAt`
- `activePage`

### `MojuDPKError`

错误分类：

- `invalidFormat`
- `unsupportedVersion`
- `invalidSecret`
- `decryptionFailed`
- `manifestMissing`
- `pageNotFound`

## 11. 预览和工具链

### `MojuKitPreview`

作用：本地预览宿主工程。

说明：

- 预览工程名是 `MojuKitPreview`
- scheme 也是 `MojuKitPreview`
- 它不属于业务 App 必须接入的运行时能力

### Studio / VS Code

作用：

- 把 DKML、样式和受控逻辑编译成 runtime JSON
- 生成 `.dpk`
- 本地跑预览

## 12. 一句话总结

MojuKit 当前支持的是“原生组件 + 受控动作 + 模板绑定 + 循环容器 + 加密包”，不是完整 H5 引擎。
