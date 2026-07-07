Page({
  data: {
  },
  methods: {
    onTap_component_4() {
      dk.setState("pageParams.selectedCardId", "etc_1")
      dk.setState("pageParams.isETC1Selected", "true")
      dk.setState("pageParams.isETC2Selected", "false")
      dk.setState("pageParams.selectedCardNo", "6230 **** **** 8821")
      dk.setState("pageParams.selectedPlateNo", "京A1****6")
      dk.setState("pageParams.selectedActivationDate", "2025年11月26日")
    },
    onTap_component_12() {
      dk.setState("pageParams.selectedCardId", "etc_2")
      dk.setState("pageParams.isETC1Selected", "false")
      dk.setState("pageParams.isETC2Selected", "true")
      dk.setState("pageParams.selectedCardNo", "6230 **** **** 9952")
      dk.setState("pageParams.selectedPlateNo", "粤B5****8")
      dk.setState("pageParams.selectedActivationDate", "2025年11月26日")
    },
    onTap_component_24() {
      dk.navigate("etc_verification")
    },
    onTap_component_28() {
      dk.showModal("confirm_bind_card_modal_v2_compact",
      {
        cardNo: "{{pageParams.selectedCardNo}}",
        plateNo: "{{pageParams.selectedPlateNo}}",
        activationDate: "{{pageParams.selectedActivationDate}}",
        modal_height: 300,
        modal_width: "{{UIConfigure.width-20}}",
        modal_bottomSpacing: 10,
        modal_topRadius: 20,
      })
    }
  }
})
