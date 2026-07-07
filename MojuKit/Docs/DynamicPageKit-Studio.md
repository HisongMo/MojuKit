# DynamicPageKit Studio

DynamicPageKit Studio 是一个内部开发工具，用四文件结构编辑动态页面，再编译为现有 `DynamicPage` runtime JSON，由 Studio 预览和 iOS Preview Host 渲染。

## 页面结构

推荐项目结构：

```text
MyDynamicPages/
└── pages/
    └── ETCList/
        ├── index.dkml
        ├── index.dkss
        ├── index.js
        ├── index.json
        └── index.dynamic.json
```

- `index.dkml`：页面结构。
- `index.dkss`：样式，映射到 `DynamicStyle`。
- `index.js`：受控逻辑 DSL，不执行任意 JavaScript。
- `index.json`：页面配置，如 `pageId`、`pageTitle`、`backgroundColor`。
- `index.dynamic.json`：保存时生成的编译结果，方便调试。

Studio 仍兼容旧版 `.json` 页面。导入或打开旧 JSON 时，会在内存中反编译成四文件结构；保存后落盘为页面目录。

## DKML

示例：

```xml
<page class="page">
  <view class="notice">
    <text>为您找到 {{cards.count}} 张ETC卡</text>
  </view>

  <card class="etc-card" bindtap="selectCard">
    <text class="card-number">{{item.cardNumber}}</text>
    <text class="expire-date">{{item.expireDate}}</text>
  </card>

  <button class="confirm-button" bindtap="confirmBind">确认绑定</button>
</page>
```

第一版支持标签：

`page`、`view`、`text`、`image`、`input`、`textarea`、`button`、`card`、`row`、`column`、`icon`、`space`、`selectable-card`

常用属性：

- `class`
- `bindtap`
- `src`
- `placeholder`
- `name`
- `slot="fixedBottom"`
- `state-key`
- `value`
- `default` / `default-text`
- `keyboard-type`
- `max-length`
- `dk:if` 目前会编译为 visible 表达式字符串，由运行时模板能力继续处理。

输入框示例：

```xml
<page class="page">
  <text class="label">车牌号</text>
  <input
    class="input"
    state-key="plateNumber"
    placeholder="请输入车牌号"
    keyboard-type="ascii"
    max-length="8" />

  <text class="label">备注</text>
  <textarea
    class="textarea"
    state-key="remark"
    placeholder="请输入备注"
    max-length="50"></textarea>

  <button class="primary-button" bindtap="submitForm">提交</button>
</page>
```

`input` / `textarea` 会自动把输入值写入 `state-key`。例如上面的 `plateNumber` 和 `remark`，后续可在 JS 请求参数中用 `{{plateNumber}}`、`{{remark}}` 读取。第一版暂不支持 `bindinput(event)`，实时校验和 `event.detail.value` 后续扩展。

## DKSS

示例：

```css
.page {
  background-color: #F5F5F5;
}

.etc-card {
  margin: 12 16 0 16;
  padding: 18 18 18 18;
  background-color: #2F80ED;
  corner-radius: 8;
}

.confirm-button {
  height: 44;
  margin: 32 16 0 16;
  background-color: #42AB6F;
  text-color: #FFFFFF;
  corner-radius: 22;
}
```

第一版支持常用属性：`width`、`height`、`margin`、`padding`、`background-color`、`text-color`、`font-size`、`font-weight`、`corner-radius`、`border-width`、`border-color`、`alignment`、`stack-alignment`、`distribution`、`spacing`、`content-mode`、`number-of-lines`、`hidden`。

## JS

`index.js` 不会被执行，只会被 Studio 解析为 `DynamicAction`。

```js
Page({
  data: {
    selectedCardId: ""
  },

  methods: {
    selectCard(event) {
      dk.setState("selectedCardId", event.dataset.id)
    },

    confirmBind() {
      dk.navigate("ETCDetail", {
        cardId: "{{selectedCardId}}"
      })
    },

    submitForm() {
      dk.request("submit_plate_form", {
        params: {
          plateNumber: "{{plateNumber}}",
          remark: "{{remark}}"
        },
        showLoading: true,
        loadingText: "提交中",
        success: () => {
          dk.toast("提交成功")
          dk.delay(800, () => {
            dk.navigate("SubmitResult")
          })
        },
        fail: () => {
          dk.toast("提交失败，请稍后重试")
        }
      })
    }
  }
})
```

第一版支持：

- `dk.navigate("Target")`
- `dk.back()`
- `dk.toast("message")`
- `dk.track("event")`
- `dk.setState("key", "value")`
- `dk.request("apiKey", options)`
- `dk.delay(milliseconds)`
- `dk.delay(milliseconds, () => { ... })`
- `dk.navigateNative("Target", params)`
- `dk.showModal("Target", params)`

`dk.request` 支持的 options：

```js
dk.request("api_key", {
  params: {
    id: "{{pageParams.id}}"
  },
  responseKey: "detail",
  showLoading: true,
  loadingText: "加载中",
  success: () => {
    dk.toast("成功")
  },
  fail: () => {
    dk.toast("失败")
  }
})
```

同一个回调中写多个 `dk.xxx` 调用时，会编译为顺序动作：

```js
success: () => {
  dk.toast("绑定成功")
  dk.delay(800, () => {
    dk.navigate("bind_success")
  })
}
```

常用受控能力：

- `dk.navigate`：跳转动态页。
- `dk.navigateNative`：跳转 App 原生页面。
- `dk.showModal`：打开动态弹窗或业务弹窗。
- `dk.request`：调用白名单接口。
- `dk.setState`：更新本地状态。
- `dk.delay`：延迟后继续执行。

## 启动

直接双击：

```text
/Users/wangleihaoshuaio/Developer/Demo/StudioApp/Build/DynamicPageKit Studio.app
```

如果修改了 Studio 源码，需要重新生成 `.app`：

```bash
/Users/wangleihaoshuaio/Developer/Demo/StudioApp/build_app.sh
```

Studio 会启动本地预览服务：

- `GET http://127.0.0.1:8088/active-page.json`
- `GET http://127.0.0.1:8088/events`

iOS Demo 首页点击 `连接 Studio 预览` 后，会读取这个编译后的 runtime JSON。

## 编辑行为

- 右侧编辑器包含 `DKML`、`DKSS`、`JS`、`JSON`、`Compiled`、`诊断`。
- 四个源文件使用独立 draft buffer，输入时不互相覆盖。
- 修改后 300ms debounce 编译，编译结果刷新 Studio 预览和本地服务。
- `Compiled` 只读，展示当前 runtime JSON。
- 保存会写入四个源文件，并生成 `index.dynamic.json`。
- 预览画布只负责展示、选中和跳转；页面内容统一在右侧源文件中编辑。

## VS Code 插件打包

VS Code 插件提供 `DynamicPageKit: Export Runtime JSON Package` 命令，也可以在 DynamicPageKit Pages 视图右上角点击打包按钮。

打包流程：

1. 保存当前工作区文件。
2. 调用 Swift CLI 编译当前项目下所有页面。
3. 选择一个父目录。
4. 输入导出文件夹名称，默认 `DynamicPageKitRuntimeJSON`。
5. 插件创建一个新的只包含 JSON 的目录，写入每个页面的 runtime JSON 和 `manifest.json`。

导出结果示例：

```text
DynamicPageKitRuntimeJSON/
├── ETCList.json
├── ETCDetail.json
└── manifest.json
```
