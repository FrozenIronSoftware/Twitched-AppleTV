//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

/// A UITextView that can be focused
class FocusableTextView: UITextView, CallbackActionHandler {
    var callbackAction: ((Any, UIGestureRecognizer) -> Void)? = { _, _ in }

    /// Handle initialization
    override func awakeFromNib() {
        super.awakeFromNib()
        // Force selectable and scroll disabled
        self.isSelectable = true
        self.isScrollEnabled = false
        // Setup tap recognizer
        let tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                action: #selector(self.selected(sender:)))
        tapRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        self.addGestureRecognizer(tapRecognizer)
    }

    /// Handle the view being selected
    @objc private func selected(sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                if self.isFocused {
                    self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }
                else {
                    self.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
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

    /// Handle focus
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        //super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView == self {
            coordinator.addCoordinatedAnimations({
                self.layer.backgroundColor = UIColor.black.withAlphaComponent(0.2).cgColor
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            })
        }
        else {
            coordinator.addCoordinatedAnimations({
                self.layer.backgroundColor = UIColor.clear.cgColor
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
        }
    }
}
