//
// Created by Rolando Islas on 5/19/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

/// Generic view that allows focus used for standalone image views
class FocusableView: UIView, CallbackActionHandler {
    var callbackAction: ((Any, UIGestureRecognizer) -> Void)?

    /// Init
    override func awakeFromNib() {
        super.awakeFromNib()
        // Add tap listener
        let tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                action: #selector(self.selected(sender:)))
        tapRecognizer.allowedPressTypes = [
            NSNumber(value: UIPress.PressType.select.rawValue),
            NSNumber(value: UIPress.PressType.playPause.rawValue)
        ]
        self.addGestureRecognizer(tapRecognizer)
    }

    /// Handle selection
    @objc private func selected(sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: { _ in
                if let callback = self.callbackAction {
                    callback(self, sender)
                }
            })
        })
    }

    /// Make focusable
    override var canBecomeFocused: Bool {
        return true
    }
}
