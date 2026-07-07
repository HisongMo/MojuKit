import XCTest
@testable import DynamicPageKitCore

final class DKPageCompilerTests: XCTestCase {
    func testCompilesFourFilePageIntoDynamicPage() throws {
        let source = DKPageSource(
            dkmlText: """
            <page class="page">
              <text class="title">动态页</text>
              <button class="primary-button" bindtap="goDetail">查看详情</button>
            </page>
            """,
            dkssText: """
            .page {
              background-color: #F5F5F5;
            }

            .title {
              margin: 10 12 0 12;
              font-size: 18;
              font-weight: semibold;
              text-color: #111111;
            }

            .primary-button {
              height: 44;
              background-color: #2F80ED;
              text-color: #FFFFFF;
              corner-radius: 8;
            }
            """,
            jsText: """
            Page({
              methods: {
                goDetail() {
                  dk.navigate("Detail")
                }
              }
            })
            """,
            configJSONText: """
            {
              "schemaVersion": "1.0",
              "pageId": "home",
              "pageTitle": "首页"
            }
            """
        )

        let result = DKPageCompiler.compile(source)
        let page = try XCTUnwrap(result.page)
        XCTAssertEqual(page.pageId, "home")
        XCTAssertEqual(page.pageTitle, "首页")
        XCTAssertEqual(page.backgroundColor, "#F5F5F5")
        XCTAssertEqual(page.components.count, 2)
        XCTAssertEqual(page.components[0].type, "text")
        XCTAssertEqual(page.components[0].style?.fontSize, 18)
        XCTAssertEqual(page.components[1].action?.type, "navigate")
        XCTAssertEqual(page.components[1].action?.target, "Detail")
    }

    func testCompilesInputAndTextareaComponents() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <input class="plate-input" state-key="plateNumber" placeholder="请输入车牌号" keyboard-type="ascii" max-length="8" />
              <textarea class="remark-input" state-key="remark" placeholder="请输入备注" max-length="50">默认备注</textarea>
            </page>
            """,
            dkssText: """
            .plate-input {
              height: 44;
              padding: 0 12 0 12;
              background-color: #FFFFFF;
              text-color: #111111;
              corner-radius: 8;
            }
            """,
            jsText: "Page({ data: {}, methods: {} })",
            configJSONText: "{}"
        )

        let page = try XCTUnwrap(DKPageCompiler.compile(source).page)
        XCTAssertEqual(page.components.count, 2)
        XCTAssertEqual(page.components[0].type, "input")
        XCTAssertEqual(page.components[0].stateKey, "plateNumber")
        XCTAssertEqual(page.components[0].placeholder, "请输入车牌号")
        XCTAssertEqual(page.components[0].keyboardType, "ascii")
        XCTAssertEqual(page.components[0].maxLength, 8)
        XCTAssertEqual(page.components[0].style?.height, 44)

        XCTAssertEqual(page.components[1].type, "textarea")
        XCTAssertEqual(page.components[1].stateKey, "remark")
        XCTAssertEqual(page.components[1].placeholder, "请输入备注")
        XCTAssertEqual(page.components[1].defaultText, "默认备注")
        XCTAssertEqual(page.components[1].maxLength, 50)
    }

    func testJSSetStateParsesDatasetReference() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="selectCard">选择</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                selectCard(event) {
                  dk.setState("selectedCardId", event.dataset.id)
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let page = try XCTUnwrap(DKPageCompiler.compile(source).page)
        XCTAssertEqual(page.components.first?.action?.type, "setState")
        XCTAssertEqual(page.components.first?.action?.stateKey, "selectedCardId")
        XCTAssertEqual(page.components.first?.action?.value, .string("event.dataset.id"))
    }

    func testJSNavigateNativeParsesAsNativeAction() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="openNative">打开原生页</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                openNative() {
                  dk.navigateNative("NativeTest", {
                    source: "unit_test",
                    cardNumber: "6230 **** **** 8821"
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let page = try XCTUnwrap(DKPageCompiler.compile(source).page)
        XCTAssertEqual(page.components.first?.action?.type, "nativeNavigate")
        XCTAssertEqual(page.components.first?.action?.target, "NativeTest")
        XCTAssertEqual(page.components.first?.action?.params?["source"], .string("unit_test"))
        XCTAssertEqual(page.components.first?.action?.params?["cardNumber"], .string("6230 **** **** 8821"))
    }

    func testJSParserSupportsFunctionPropertyAndArrowMethods() throws {
        let functionSource = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="confirmBind">确认绑定</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                confirmBind: function() {
                  dk.navigate("ETCDetail", {
                    cardId: "{{selectedCardId}}"
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let functionPage = try XCTUnwrap(DKPageCompiler.compile(functionSource).page)
        XCTAssertEqual(functionPage.components.first?.action?.type, "navigate")
        XCTAssertEqual(functionPage.components.first?.action?.target, "ETCDetail")
        XCTAssertEqual(functionPage.components.first?.action?.params?["cardId"], .string("{{selectedCardId}}"))

        let arrowSource = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="showToast">提示</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                showToast: () => {
                  dk.toast("保存成功")
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let arrowPage = try XCTUnwrap(DKPageCompiler.compile(arrowSource).page)
        XCTAssertEqual(arrowPage.components.first?.action?.type, "toast")
        XCTAssertEqual(arrowPage.components.first?.action?.message, "保存成功")
    }

    func testMissingBindtapMethodProducesDiagnostic() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="missingMethod">提交</button>
            </page>
            """,
            dkssText: "",
            jsText: "Page({ methods: {} })",
            configJSONText: "{}"
        )

        let result = DKPageCompiler.compile(source)
        XCTAssertNotNil(result.page)
        XCTAssertTrue(result.diagnostics.contains { $0.contains("bindtap=\"missingMethod\"") })
        XCTAssertNil(result.page?.components.first?.action)
    }

    func testIncompleteJSStringDoesNotCrashCompiler() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="showToast">提示</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                showToast() {
                  dk.toast("
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let result = DKPageCompiler.compile(source)
        XCTAssertNotNil(result.page)
        XCTAssertNil(result.page?.components.first?.action)
        XCTAssertTrue(result.diagnostics.contains { $0.contains("showToast") })
    }

    func testIncompleteDKMLTagDoesNotHangCompiler() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <v
            </page>
            """,
            dkssText: "",
            jsText: "Page({ methods: {} })",
            configJSONText: "{}"
        )
        let result = DKPageCompiler.compile(source)
        XCTAssertNil(result.page)
    }

    func testDecompileLegacyJSONProducesEditableSource() throws {
        let page = DynamicPage(
            schemaVersion: "1.0",
            pageId: "legacy",
            pageTitle: "Legacy",
            backgroundColor: "#FFFFFF",
            components: [
                DynamicComponent(type: "text", text: "旧页面")
            ]
        )

        let source = DKPageCompiler.decompile(page: page)
        XCTAssertTrue(source.dkmlText.contains("<text"))
        XCTAssertTrue(source.dkssText.contains(".page"))
        XCTAssertTrue(source.configJSONText.contains("\"pageId\""))
        XCTAssertNotNil(DKPageCompiler.compile(source).page)
    }

    func testJSRequestWithSuccessActionCallback() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="sendSms">发送验证码</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                sendSms() {
                  dk.request("send_bind_sms_code", {
                    success: () => {
                      dk.navigate("etc_sms_verification_page_v2")
                    }
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )
        let page = try XCTUnwrap(DKPageCompiler.compile(source).page)
        let button = try XCTUnwrap(page.components.first)
        let action = try XCTUnwrap(button.action)
        XCTAssertEqual(action.type, "request")
        let request = try XCTUnwrap(action.request)
        XCTAssertEqual(request.apiKey, "send_bind_sms_code")
        let successAction = try XCTUnwrap(request.successAction)
        XCTAssertEqual(successAction.type, "navigate")
        XCTAssertEqual(successAction.target, "etc_sms_verification_page_v2")
    }

    func testJSRequestParsesOptionsAndFailureCallback() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="loadUser">加载用户</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                loadUser() {
                  dk.request("get_user_info", {
                    params: {
                      userId: "{{userId}}",
                      retryCount: 2,
                      silent: false
                    },
                    responseKey: "userInfo",
                    showLoading: true,
                    loadingText: "加载中",
                    success: () => {
                      dk.navigateNative("NativeTest", {
                        source: "request_success"
                      })
                    },
                    failure: () => {
                      dk.toast("加载失败")
                    }
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let page = try XCTUnwrap(DKPageCompiler.compile(source).page)
        let request = try XCTUnwrap(page.components.first?.action?.request)
        XCTAssertEqual(request.apiKey, "get_user_info")
        XCTAssertEqual(request.params?["userId"], .string("{{userId}}"))
        XCTAssertEqual(request.params?["retryCount"], .int(2))
        XCTAssertEqual(request.params?["silent"], .bool(false))
        XCTAssertEqual(request.responseKey, "userInfo")
        XCTAssertEqual(request.showLoading, true)
        XCTAssertEqual(request.loadingText, "加载中")
        XCTAssertEqual(request.successAction?.type, "nativeNavigate")
        XCTAssertEqual(request.successAction?.target, "NativeTest")
        XCTAssertEqual(request.successAction?.params?["source"], .string("request_success"))
        XCTAssertEqual(request.failureAction?.type, "toast")
        XCTAssertEqual(request.failureAction?.message, "加载失败")
    }

    func testJSRequestCallbackSupportsMultipleActionsInOrder() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="confirmBind">确认绑定</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                confirmBind() {
                  dk.request("confirm_bind_etc_card", {
                    params: {
                      cardId: "{{selectedCardId}}"
                    },
                    success: () => {
                      dk.toast("绑定成功")
                      dk.navigate("bind_success")
                    },
                    fail: () => {
                      dk.toast("绑定失败，请稍后重试")
                      dk.navigate("testPop")
                    }
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let request = try XCTUnwrap(DKPageCompiler.compile(source).page?.components.first?.action?.request)
        let successActions = try XCTUnwrap(request.successAction?.actions)
        XCTAssertEqual(request.successAction?.type, "sequence")
        XCTAssertEqual(successActions.count, 2)
        XCTAssertEqual(successActions[0].type, "toast")
        XCTAssertEqual(successActions[0].message, "绑定成功")
        XCTAssertEqual(successActions[1].type, "navigate")
        XCTAssertEqual(successActions[1].target, "bind_success")

        let failureActions = try XCTUnwrap(request.failureAction?.actions)
        XCTAssertEqual(request.failureAction?.type, "sequence")
        XCTAssertEqual(failureActions.count, 2)
        XCTAssertEqual(failureActions[0].type, "toast")
        XCTAssertEqual(failureActions[0].message, "绑定失败，请稍后重试")
        XCTAssertEqual(failureActions[1].type, "navigate")
        XCTAssertEqual(failureActions[1].target, "testPop")
    }

    func testJSDelayCompilesNestedCallbackAction() throws {
        let source = DKPageSource(
            dkmlText: """
            <page>
              <button bindtap="confirmBind">确认绑定</button>
            </page>
            """,
            dkssText: "",
            jsText: """
            Page({
              methods: {
                confirmBind() {
                  dk.request("confirm_bind_etc_card", {
                    fail: () => {
                      dk.toast("绑定失败，请稍后重试")
                      dk.delay(800, () => {
                        dk.navigate("testPop")
                      })
                    }
                  })
                }
              }
            })
            """,
            configJSONText: "{}"
        )

        let request = try XCTUnwrap(DKPageCompiler.compile(source).page?.components.first?.action?.request)
        let failureActions = try XCTUnwrap(request.failureAction?.actions)
        XCTAssertEqual(request.failureAction?.type, "sequence")
        XCTAssertEqual(failureActions.count, 2)
        XCTAssertEqual(failureActions[0].type, "toast")
        XCTAssertEqual(failureActions[0].message, "绑定失败，请稍后重试")
        XCTAssertEqual(failureActions[1].type, "delay")
        XCTAssertEqual(failureActions[1].delayMilliseconds, 800)

        let delayedActions = try XCTUnwrap(failureActions[1].actions)
        XCTAssertEqual(delayedActions.count, 1)
        XCTAssertEqual(delayedActions[0].type, "navigate")
        XCTAssertEqual(delayedActions[0].target, "testPop")
    }
}
