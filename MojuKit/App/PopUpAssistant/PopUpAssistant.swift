//
//  PopUpAssistant.swift
//  MyViewFactory
//
//  Created by Wanglei on 2023/10/16.
//  弹窗助理
//

import UIKit

class PopUpAssistant: NSObject {
    
    public static let shared = PopUpAssistant()
    
    var topSpacing: CGFloat = 0
    var bottomSpacing: CGFloat = 0
    weak var curCustomView: PopUpCustomView?
    
    /// 自定义弹窗
    /// - Parameters:
    ///   - customView: 自定义视图
    ///   - position: 弹窗位置
    ///   - useCover: 是否使用遮罩
    func showCustomView(_ customView: PopUpBaseView, position: PopUpAlertPosition = .center, useCover: Bool = true, canTouchCoverCloseSelf: Bool = true, tapSelfRemove: Bool = false, fatherView: UIView? = nil, bottomSpacing: CGFloat? = nil) {
        let curCustomView = PopUpCustomView()
        curCustomView.topPadding = UIConfigure.KStatusBarHeight
        curCustomView.alert(customView: customView, position: position, useCover: useCover, canTouchCoverCloseSelf: canTouchCoverCloseSelf, tapSelfRemove: tapSelfRemove, fatherView: fatherView, bottomSpacing: bottomSpacing ?? self.bottomSpacing)
        self.curCustomView = curCustomView
    }
    
    public func refreshCustomView(_ customView: PopUpBaseView) {
        if let cv = self.curCustomView {
            cv.refreshBottom(customView: customView)
        } else {
            print("There is currently no pop-up view")
        }
    }
    
    public func changeHeight(curHeight: CGFloat) {
        if let cv = self.curCustomView {
            cv.changeHeight(curHeight: curHeight)
        } else {
            print("There is currently no pop-up view")
        }
    }
}

@objc protocol PopUpAssistantDelegate {
    func didClosePopView()
    func nextStep()
}

enum PopUpAlertPosition: Int {
    case center = 0
    case bottom
    case top
}
