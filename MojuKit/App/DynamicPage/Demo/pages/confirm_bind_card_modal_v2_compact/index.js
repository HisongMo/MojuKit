Page({
  data: {
  },
  methods: {
    onTap_send_code_button() {
      dk.request("confirm_bind_etc_card",
      {
        params: {
          cardId: "{{selectedCardId}}"
        },
        showLoading: true,
        loadingText: "提交中",
        success: () => {
          dk.toast("绑定成功")
        },
        fail: () => {
          dk.toast("绑定失败，请稍后重试")
          dk.delay(500)
          dk.navigate(testPop)
        }
      })
    },

    onTap_cancel_button() {
      dk.back()
    }
  }
})
