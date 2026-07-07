//
//  PopUpWindow.swift
//  eHighSpeed
//
//  Created by Wanglei on 2025/12/19.
//  专用弹窗窗口，避免与第三方SDK冲突
//

import UIKit

/// 弹窗专用窗口管理器
class PopUpWindowManager {
    
    // MARK: - 单例
    static let shared = PopUpWindowManager()
    
    // MARK: - 属性
    /// 弹窗专用窗口
    private var popupWindow: UIWindow?
    
    /// 当前显示的弹窗数量
    private var popupCount = 0
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 公开方法
    
    /// 获取弹窗窗口
    /// - Returns: 弹窗专用窗口
    func getPopupWindow() -> UIWindow {
        if let window = popupWindow {
            return window
        }
        
        // 创建新窗口
        let window: UIWindow
        if #available(iOS 13.0, *) {
            // iOS 13+ 需要使用 windowScene
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                window = UIWindow(windowScene: windowScene)
            } else {
                // 降级方案：使用第一个可用的 scene
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    window = UIWindow(windowScene: windowScene)
                } else {
                    window = UIWindow(frame: UIScreen.main.bounds)
                }
            }
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        
        // 配置窗口
        window.windowLevel = .alert + 1 // 确保在 alert 之上
        window.backgroundColor = .clear
        
        // 创建透明的根视图控制器
        let rootVC = PopUpRootViewController()
        window.rootViewController = rootVC
        
        self.popupWindow = window
        return window
    }
    
    /// 显示弹窗窗口
    func showWindow() {
        popupCount += 1
        let window = getPopupWindow()
        window.isHidden = false
        window.makeKeyAndVisible()
        
        // 恢复主窗口的 key 状态（避免影响主界面交互）
        DispatchQueue.main.async {
            UIApplication.shared.wl_mainWindow?.makeKey()
        }
    }
    
    /// 隐藏弹窗窗口
    func hideWindow() {
        popupCount = max(0, popupCount - 1)
        
        // 只有当没有弹窗时才隐藏窗口
        if popupCount == 0 {
            popupWindow?.isHidden = true
            popupWindow = nil
            
            // 恢复主窗口
            UIApplication.shared.wl_mainWindow?.makeKeyAndVisible()
        }
    }
    
    /// 强制隐藏所有弹窗
    func forceHideAll() {
        popupCount = 0
        popupWindow?.isHidden = true
        popupWindow = nil
        UIApplication.shared.wl_mainWindow?.makeKeyAndVisible()
    }
}

// MARK: - 弹窗根视图控制器
/// 透明的根视图控制器，用于承载弹窗
private class PopUpRootViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    
    override var shouldAutorotate: Bool {
        // 跟随主窗口的旋转设置
        return UIApplication.shared.wl_mainWindow?.rootViewController?.shouldAutorotate ?? false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // 跟随主窗口的方向设置
        return UIApplication.shared.wl_mainWindow?.rootViewController?.supportedInterfaceOrientations ?? .portrait
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        // 跟随主窗口的状态栏样式
        return UIApplication.shared.wl_mainWindow?.rootViewController?.preferredStatusBarStyle ?? .default
    }
}

// MARK: - UIApplication Extension
private extension UIApplication {
    var wl_mainWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            return connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first(where: { $0.isKeyWindow })
        } else {
            return keyWindow
        }
    }
}
