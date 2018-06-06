//
// Created by Rolando Islas on 5/14/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class TextHeader: UICollectionReusableView, CallbackActionHandler {

    @IBOutlet weak var textLabel: UILabel?
    @IBOutlet weak var followButton: FocusTvButton?
    @IBOutlet weak var followButtonLabel: UILabel?
    @IBOutlet weak var followButtonView: UIView?
    var callbackAction: ((Any, UIGestureRecognizer) -> Void)?

    @IBAction func followButtonSelected(_ sender: FocusTvButton) {
        if let callback = callbackAction {
            callback(sender, UITapGestureRecognizer())
        }
    }

    /// Handle focus change
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedView == self.followButton {
            coordinator.addCoordinatedAnimations({

            })
            if let followButton = self.followButton, let followButtonView = self.followButtonView {
                UIView.animate(withDuration: 0.2, animations: {
                    followButtonView.bounds = followButton.bounds.offsetBy(
                            dx: followButton.bounds.width,
                            dy: 0)
                })
            }
        }
        else {
            coordinator.addCoordinatedAnimations({
                if let followButton = self.followButton, let followButtonView = self.followButtonView {
                    followButtonView.bounds = followButton.bounds
                }
            })
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.followButtonView?.bounds = (self.followButton?.bounds)!
        self.textLabel?.text = ""
        self.followButton?.normalBackgroundColor = Constants.COLOR_TWITCH_PURPLE
        self.followButton?.normalBackgroundEndColor = Constants.COLOR_TWITCH_PURPLE
        self.followButton?.selectedBackgroundColor = Constants.COLOR_TWITCH_PURPLE
        self.followButton?.selectedBackgroundEndColor = Constants.COLOR_TWITCH_PURPLE
        self.followButton?.focusedBackgroundColor = Constants.COLOR_TWITCH_PURPLE
        self.followButton?.focusedBackgroundEndColor = Constants.COLOR_TWITCH_PURPLE
    }
}
