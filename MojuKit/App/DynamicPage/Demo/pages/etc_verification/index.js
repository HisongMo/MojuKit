Page({
  data: {},

  methods: {
    onTap_sms_resend_countdown_button() {
      dk.request("resend_bind_sms_code", { "params": { "cardNo": "{{pageParams.cardNo}}", "plateNo": "{{pageParams.plateNo}}" }, "responseKey": "api.resendSms", "showLoading": true, "loadingText": "发送中...", "success": () => { dk.toast("验证码已重新发送") }, "fail": () => { dk.toast("发送失败，请稍后重试") } })
    },

    onTap_confirm_etc_binding_button() {
      dk.request("confirm_bind_etc_card", { "params": { "plateNo": "{{pageParams.plateNo}}", "smsCode": "{{verificationCode}}", "cardNo": "{{pageParams.cardNo}}" }, "responseKey": "api.bindResult", "showLoading": true, "loadingText": "绑定中...", "success": () => { dk.toast("绑定成功") }, "fail": () => { dk.toast("绑定失败，请稍后重试") } })
    }
  }
})