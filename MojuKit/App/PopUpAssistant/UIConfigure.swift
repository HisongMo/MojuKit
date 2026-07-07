import UIKit

public class UIConfigure {
    public static var Width: CGFloat {
        return UIScreen.main.bounds.size.width
    }
    public static var Height: CGFloat {
        return UIScreen.main.bounds.size.height
    }
    public static var SizeScale: CGFloat {
        return UIScreen.main.bounds.size.width / 375.0
    }
    public static var KStatusBarHeight: CGFloat {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            return windowScene?.statusBarManager?.statusBarFrame.height ?? 20
        } else {
            return UIApplication.shared.statusBarFrame.size.height
        }
    }
}

extension UIScreen {
    var realCornerRadius: CGFloat {
        if let cornerRadius = self.value(forKey: "_displayCornerRadius") as? CGFloat {
            return cornerRadius
        }
        return 0
    }
}
