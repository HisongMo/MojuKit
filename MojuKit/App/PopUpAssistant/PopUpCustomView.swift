//
//  PopUpCustomView.swift
//  MyViewFactory
//
//  Created by Wanglei on 2023/10/26.
//

import UIKit

class PopUpCustomView: UIView, PopUpAssistantDelegate, UIGestureRecognizerDelegate {

    func didClosePopView() {
        self.closeSelf()
    }
    
    func nextStep() {
        print("nextStep")
    }
    
    //MARK: - 声明区
    //-----UI-----
    var coverView = UIView()
    var customView = PopUpBaseView()
    var tapGes: UITapGestureRecognizer?
    //-----Block-----
    var closeBlock: (() -> Void)?
    //-----Data-----
    /* 外部参数(从外部传入的数据) */
    var position = PopUpAlertPosition.center
    var isFrame = Bool()
    var view_w = CGFloat()
    var viewHeight = CGFloat()
    var topPadding = UIConfigure.KStatusBarHeight + UIConfigure.SizeScale * 10
    var bottomSpacing = CGFloat()
    /* 内部参数(从接口获取的数据以及其他内部数据) */
    var panGes: UIPanGestureRecognizer?
    var canTouchCoverCloseSelf = Bool()
    
    //MARK: - 逻辑区
    /// 提示弹窗
    func alert(customView: PopUpBaseView, position: PopUpAlertPosition, useCover: Bool = true, canTouchCoverCloseSelf: Bool = true, tapSelfRemove: Bool = false, fatherView: UIView? = nil, bottomSpacing: CGFloat = 0) {
        self.canTouchCoverCloseSelf = canTouchCoverCloseSelf
        self.bottomSpacing = bottomSpacing
        self.customView = customView
        customView.popDelegate = self
        // 1.将弹出位置保存一下
        self.position = position
        // 2.是否由frame弹出
        self.isFrame = customView.width > 0
        // 3.遮罩
        if useCover {
            coverView.backgroundColor = UIColor(white: 0, alpha: 0.3)
            coverView.alpha = 0
            if canTouchCoverCloseSelf {
                let tap = UITapGestureRecognizer(target: self, action: #selector(removeSelf))
                coverView.addGestureRecognizer(tap)
                coverView.isUserInteractionEnabled = true
            }
            if fatherView != nil {
                fatherView?.addSubview(coverView)
            } else {
                self.popupContainerView.addSubview(coverView)
            }
            
            coverView.translatesAutoresizingMaskIntoConstraints = false
            if let superview = coverView.superview {
                NSLayoutConstraint.activate([
                    coverView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    coverView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    coverView.topAnchor.constraint(equalTo: superview.topAnchor),
                    coverView.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                ])
            }
        } else {
            self.layer.shadowOffset = CGSize(width: 0, height: 0)
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = 0.3
            self.layer.shadowRadius = 20
            self.layer.cornerRadius = UIConfigure.SizeScale * 10
            if tapSelfRemove {
                self.tapGes = UITapGestureRecognizer(target: self, action: #selector(removeSelf))
                customView.addGestureRecognizer(self.tapGes!)
            }
        }
        self.addSubview(customView)
        
        switch position {
        case .center:
            self.popFromCenter(customView: customView)
        case .bottom:
            self.popFromBottom(customView: customView, fatherView: fatherView)
        case .top:
            self.popFromTop(customView: customView)
        }
    }
    
    @objc func removeSelf() {
        self.closeSelf()
        if self.tapGes != nil {
            PopUpWindowManager.shared.getPopupWindow().removeGestureRecognizer(self.tapGes!)
        }
    }
    
    func closeSelf() {
        switch self.position {
        case .center:
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                self.coverView.alpha = 0
            }) { _ in
                self.coverView.removeFromSuperview()
                self.removeFromSuperview()
                self.transform = .identity
                self.alpha = 1.0
                self.coverView.alpha = 1.0
                // 隐藏弹窗窗口
                PopUpWindowManager.shared.hideWindow()
            }
        case .bottom:
            if self.superview != nil && self.superview != PopUpWindowManager.shared.getPopupWindow() && self.superview != self.popupContainerView {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                    if let superview = self.superview {
                        self.translatesAutoresizingMaskIntoConstraints = false
                        let constraints = superview.constraints.filter { 
                            ($0.firstItem as? UIView == self) || ($0.secondItem as? UIView == self) 
                        }
                        NSLayoutConstraint.deactivate(constraints)
                        
                        NSLayoutConstraint.activate([
                            self.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                            self.widthAnchor.constraint(equalToConstant: self.view_w),
                            self.heightAnchor.constraint(equalToConstant: self.viewHeight),
                            self.topAnchor.constraint(equalTo: superview.bottomAnchor)
                        ])
                    }
                    self.coverView.alpha = 0
                    self.superview?.layoutIfNeeded()
                }) { isSuccess in
                    self.coverView.removeFromSuperview()
                    self.removeFromSuperview()
                    self.coverView.alpha = 1.0
                    PopUpWindowManager.shared.hideWindow()
                }
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                    self.mj_y = UIConfigure.Height
                    self.coverView.alpha = 0
                }) { isSuccess in
                    self.coverView.removeFromSuperview()
                    self.removeFromSuperview()
                    self.coverView.alpha = 1.0
                    // 隐藏弹窗窗口
                    PopUpWindowManager.shared.hideWindow()
                }
            }
        case .top:
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                self.mj_y = -self.viewHeight
                self.coverView.alpha = 0
            }) { isSuccess in
                self.coverView.removeFromSuperview()
                self.removeFromSuperview()
                self.coverView.alpha = 1.0
                // 隐藏弹窗窗口
                PopUpWindowManager.shared.hideWindow()
            }
        }
    }
    
    func popFromBottom(customView: PopUpBaseView, fatherView: UIView? = nil) {
        customView.hiddenAndShowBlock = { [weak self] isHidden in
            guard let `self` = self else { return }
            self.hiddenAndShow(isShow: !isHidden)
        }
        // 如果 isFrame 为 true，则使用 frame-based 动画
        if self.isFrame {
            // 计算自定义视图的宽度和高度
            self.view_w = customView.width
            self.viewHeight = customView.height
            
            if let fView = fatherView {
                fView.addSubview(self)
                self.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    self.centerXAnchor.constraint(equalTo: fView.centerXAnchor),
                    self.widthAnchor.constraint(equalToConstant: view_w),
                    self.heightAnchor.constraint(equalToConstant: viewHeight),
                    self.topAnchor.constraint(equalTo: fView.bottomAnchor)
                ])
                fView.layoutIfNeeded()
                
                if self.canTouchCoverCloseSelf {
                    // 只有底部弹出的才添加下滑关闭手势
                    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
                    self.panGes = pan
                    pan.delegate = self
                    self.addGestureRecognizer(pan)
                }
                
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    let constraints = fView.constraints.filter { 
                        ($0.firstItem as? UIView == self) || ($0.secondItem as? UIView == self) 
                    }
                    NSLayoutConstraint.deactivate(constraints)
                    NSLayoutConstraint.activate([
                        self.centerXAnchor.constraint(equalTo: fView.centerXAnchor),
                        self.widthAnchor.constraint(equalToConstant: self.view_w),
                        self.heightAnchor.constraint(equalToConstant: self.viewHeight),
                        self.bottomAnchor.constraint(equalTo: fView.bottomAnchor, constant: -self.bottomSpacing)
                    ])
                    self.coverView.alpha = 1.0
                    fView.layoutIfNeeded()
                }, completion: nil)
            } else {
                let father_w = UIConfigure.Width
                let father_h = UIConfigure.Height
                // 计算自定义视图的初始 x 位置，使其位于屏幕中央
                let view_x = (father_w - view_w) / 2.0
                
                // 计算自定义视图在底部显示时的最终 y 位置
                let pop_y = father_h - viewHeight - self.bottomSpacing
                
                // 使用独立弹窗窗口
                PopUpWindowManager.shared.showWindow()
                self.popupContainerView.addSubview(self)
                
                // 设置视图的初始位置，使其位于屏幕底部以外
                self.frame = CGRect(x: view_x, y: UIConfigure.Height, width: view_w, height: viewHeight)
                if self.canTouchCoverCloseSelf {
                    // 只有底部弹出的才添加下滑关闭手势
                    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
                    self.panGes = pan
                    pan.delegate = self
                    self.addGestureRecognizer(pan)
                }
                // 使用 UIView.animate 执行动画，使视图从底部滑入
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    self.mj_y = pop_y
                    self.coverView.alpha = 1.0
                }, completion: nil)
            }
        } else {
            // 如果 isFrame 为 false，则直接使用 Autolayout 来设置约束
            PopUpWindowManager.shared.showWindow()
            self.popupContainerView.addSubview(self)
            
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                customView.topAnchor.constraint(equalTo: self.topAnchor),
                customView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            
            self.translatesAutoresizingMaskIntoConstraints = false
            if let superview = self.superview {
                NSLayoutConstraint.activate([
                    self.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                    self.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                ])
            }
            
            self.popupContainerView.layoutIfNeeded()
            let originY = self.frame.origin.y
            self.frame.origin.y = UIConfigure.Height
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.frame.origin.y = originY
                self.coverView.alpha = 1.0
            }, completion: nil)
        }
    }

    func refreshBottom(customView: PopUpBaseView) {
        customView.hiddenAndShowBlock = { [weak self] isHidden in
            guard let `self` = self else { return }
            self.hiddenAndShow(isShow: !isHidden)
        }
        
        self.isFrame = customView.width > 0
        // 如果 isFrame 为 true，则使用 frame-based 动画
        if self.isFrame {
            // 计算自定义视图的宽度和高度
            self.view_w = customView.width
            self.viewHeight = customView.height
            
            if self.superview != nil && self.superview != PopUpWindowManager.shared.getPopupWindow() && self.superview != self.popupContainerView {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    if let superview = self.superview {
                        self.translatesAutoresizingMaskIntoConstraints = false
                        let constraints = superview.constraints.filter { 
                            ($0.firstItem as? UIView == self) || ($0.secondItem as? UIView == self) 
                        }
                        NSLayoutConstraint.deactivate(constraints)
                        NSLayoutConstraint.activate([
                            self.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                            self.widthAnchor.constraint(equalToConstant: self.view_w),
                            self.heightAnchor.constraint(equalToConstant: self.viewHeight),
                            self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -self.bottomSpacing)
                        ])
                    }
                    self.superview?.layoutIfNeeded()
                }, completion: nil)
            } else {
                let view_x = (UIConfigure.Width - view_w) / 2.0
                let pop_y = UIConfigure.Height - viewHeight - self.bottomSpacing
                self.frame = CGRect(x: view_x, y: self.mj_y, width: view_w, height: viewHeight)
                
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    self.mj_y = pop_y
                }, completion: nil)
            }
        } else {
            customView.translatesAutoresizingMaskIntoConstraints = false
            let cvConstraints = self.constraints.filter {
                ($0.firstItem as? UIView == customView) || ($0.secondItem as? UIView == customView)
            }
            NSLayoutConstraint.deactivate(cvConstraints)
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                customView.topAnchor.constraint(equalTo: self.topAnchor),
                customView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            
            if let superview = self.superview {
                self.translatesAutoresizingMaskIntoConstraints = false
                let selfConstraints = superview.constraints.filter {
                    ($0.firstItem as? UIView == self) || ($0.secondItem as? UIView == self)
                }
                NSLayoutConstraint.deactivate(selfConstraints)
                NSLayoutConstraint.activate([
                    self.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                    self.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
                ])
            }
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.superview?.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    func changeHeight(curHeight: CGFloat) {
        if self.viewHeight == curHeight {return}
        if self.superview != nil && self.superview != PopUpWindowManager.shared.getPopupWindow() && self.superview != self.popupContainerView {
            self.viewHeight = curHeight
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                if let heightConstraint = self.constraints.first(where: { $0.firstItem as? UIView == self && $0.firstAttribute == .height }) {
                    heightConstraint.constant = curHeight
                } else if let superview = self.superview, let heightConstraint = superview.constraints.first(where: { $0.firstItem as? UIView == self && $0.firstAttribute == .height }) {
                    heightConstraint.constant = curHeight
                }
                self.superview?.layoutIfNeeded()
            }, completion: nil)
        } else {
            let pop_y = UIConfigure.Height - curHeight - self.bottomSpacing
            if self.viewHeight > curHeight {
                self.viewHeight = curHeight
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    self.mj_y = pop_y
                }) { success in
                    if success {
                        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                            self.mj_h = self.viewHeight
                            self.customView.mj_h = self.viewHeight
                        }, completion: nil)
                    }
                }
            } else {
                self.viewHeight = curHeight
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    self.mj_h = self.viewHeight
                    self.customView.mj_h = self.viewHeight
                }, completion: nil)
                
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                    self.mj_y = pop_y
                }, completion: nil)
            }
        }
    }
    
    func popFromCenter(customView: PopUpBaseView) {
        customView.hiddenAndShowBlock = { [weak self] isHidden in
            guard let `self` = self else { return }
            self.hiddenAndShow(isShow: !isHidden)
        }
        if isFrame {
            self.view_w = customView.width
            self.viewHeight = customView.height
            
            let view_x = (UIConfigure.Width - view_w) / 2.0
            let view_y = (UIConfigure.Height - viewHeight) / 2.0
            
            PopUpWindowManager.shared.showWindow()
            self.popupContainerView.addSubview(self)
            
            self.frame = CGRect(x: view_x, y: view_y, width: self.view_w, height: self.viewHeight)
            
            self.isHidden = false
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.alpha = 1.0
                self.transform = .identity
                self.coverView.alpha = 1.0
            }, completion: nil)
        } else {
            PopUpWindowManager.shared.showWindow()
            self.popupContainerView.addSubview(self)
            
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                customView.topAnchor.constraint(equalTo: self.topAnchor),
                customView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            
            self.translatesAutoresizingMaskIntoConstraints = false
            if let superview = self.superview {
                NSLayoutConstraint.activate([
                    self.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                    self.centerYAnchor.constraint(equalTo: superview.centerYAnchor)
                ])
            }
            
            self.popupContainerView.layoutIfNeeded()
            
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.alpha = 1.0
                self.transform = .identity
                self.coverView.alpha = 1.0
            }, completion: nil)
        }
    }
    
    func popFromTop(customView: PopUpBaseView) {
        customView.hiddenAndShowBlock = { [weak self] isHidden in
            guard let `self` = self else { return }
            self.hiddenAndShow(isShow: !isHidden)
        }
        if isFrame {
            self.view_w = customView.width
            self.viewHeight = customView.height
            
            let view_x = (UIConfigure.Width - view_w) / 2.0
            let view_y = -viewHeight
            
            PopUpWindowManager.shared.showWindow()
            self.popupContainerView.addSubview(self)
            
            self.frame = CGRect(x: view_x, y: view_y, width: view_w, height: viewHeight)
            
            self.isHidden = false
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.frame = CGRect(x: view_x, y: UIConfigure.KStatusBarHeight + PopUpAssistant.shared.topSpacing, width: self.view_w, height: self.viewHeight)
                self.coverView.alpha = 1.0
            }, completion: nil)
        } else {
            PopUpWindowManager.shared.showWindow()
            self.popupContainerView.addSubview(self)
            
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                customView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                customView.topAnchor.constraint(equalTo: self.topAnchor),
                customView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            
            self.translatesAutoresizingMaskIntoConstraints = false
            if let superview = self.superview {
                NSLayoutConstraint.activate([
                    self.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    self.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    self.topAnchor.constraint(equalTo: superview.topAnchor)
                ])
            }
            
            self.popupContainerView.layoutIfNeeded()
            let originY = self.frame.origin.y
            self.frame.origin.y = -self.frame.height
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                self.frame.origin.y = originY
                self.coverView.alpha = 1.0
            }, completion: nil)
        }
    }
    
    func hiddenAndShow(isShow: Bool) {
        if !isShow {
            self.isHidden = true
            self.coverView.isHidden = true
        } else {
            self.isHidden = false
            self.coverView.isHidden = false
        }
    }
    
    //MARK: - 手势交互逻辑
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .changed:
            if translation.y >= 0 {
                self.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self)
            if velocity.y > 1200 {
                animateDismiss(currentTranslation: translation.y)
                return
            }
            let dismissThreshold = self.viewHeight / 2.0
            
            if translation.y > dismissThreshold {
                animateDismiss(currentTranslation: translation.y)
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    self.transform = .identity
                }
            }
            
        default:
            break
        }
    }

    func animateDismiss(currentTranslation: CGFloat) {
        let remainingDistance = self.viewHeight - currentTranslation
        let duration = TimeInterval(remainingDistance / self.viewHeight) * 0.3
        
        UIView.animate(withDuration: max(0.2, duration), animations: {
            self.transform = CGAffineTransform(translationX: 0, y: self.viewHeight + self.bottomSpacing)
            self.coverView.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.coverView.removeFromSuperview()
            self.transform = .identity
            
            PopUpWindowManager.shared.hideWindow()
            
            self.closeBlock?()
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.panGes {
            let velocity = self.panGes?.velocity(in: self) ?? .zero
            if velocity.y < 0 {
                return false
            }
            
            let location = self.panGes?.location(in: self) ?? .zero
            if let touchedView = self.hitTest(location, with: nil) {
                var nextView: UIView? = touchedView
                while let currentView = nextView {
                    if let scrollView = currentView as? UIScrollView {
                        if scrollView.isScrollEnabled && scrollView.contentSize.height > scrollView.bounds.height {
                            if scrollView.contentOffset.y > 0 {
                                return false
                            }
                        }
                    }
                    if currentView == self { break }
                    nextView = currentView.superview
                }
            }
        }
        return true
    }

    //MARK: - 生命区
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Extension for Safe Window Auto Layout Layout Guide
private extension PopUpCustomView {
    var popupContainerView: UIView {
        return PopUpWindowManager.shared.getPopupWindow().rootViewController?.view ?? PopUpWindowManager.shared.getPopupWindow()
    }
}
