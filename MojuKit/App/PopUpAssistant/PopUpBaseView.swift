//
//  PopUpBaseView.swift
//  MyViewFactory
//
//  Created by Wanglei on 2023/10/27.
//

import UIKit

///PopUpBaseView
class PopUpBaseView: UIView {
    
    //-----Block-----
    var closeBlock: (() -> Void)?
    var nextBlock: (() -> Void)?
    var hiddenAndShowBlock: ((_ isHidden: Bool) -> Void)?
    
    /* 内部参数 */
    weak var popDelegate: PopUpAssistantDelegate?
    
    @objc func closeAction() {
        if let block = self.closeBlock {
            block()
        }
    }
    
    @objc func nextAction() {
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
