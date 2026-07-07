import UIKit

extension UIView {
    var mj_x: CGFloat {
        get { frame.origin.x }
        set { frame.origin.x = newValue }
    }
    var mj_y: CGFloat {
        get { frame.origin.y }
        set { frame.origin.y = newValue }
    }
    var mj_w: CGFloat {
        get { frame.size.width }
        set { frame.size.width = newValue }
    }
    var mj_h: CGFloat {
        get { frame.size.height }
        set { frame.size.height = newValue }
    }
    var width: CGFloat {
        get { frame.size.width }
        set { frame.size.width = newValue }
    }
    var height: CGFloat {
        get { frame.size.height }
        set { frame.size.height = newValue }
    }
}
