//
// Created by Rolando Islas on 5/23/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log
import L10n_swift

class LoginViewController: UIViewController, ResettingViewController {

    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet private weak var linkCodeLabel: UILabel?

    private var twitchApi: TwitchApi?
    private var isRequestingStatus: Bool?
    private var statusTimer: Timer?

    /// View loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("LoginViewController did load", type: .debug)
        twitchApi = TwitchApi()
        statusTimer = Timer(timeInterval: 5, target: self, selector: #selector(self.checkLinkStatus(sender:)),
                userInfo: nil, repeats: true)
        isRequestingStatus = false
        requestLink()
    }

    /// Check link status
    @objc private func checkLinkStatus(sender: Any) {
        if !self.isRequestingStatus! {
            self.isRequestingStatus = true
            self.twitchApi?.getLinkStatus(callback: { response in
                switch response {
                case .WAITING:
                    break
                default:
                    if let timer = self.statusTimer {
                        if timer.isValid {
                            timer.invalidate()
                        }
                    }
                    self.showAlert(response)
                }
                self.isRequestingStatus = false
            })
        }
    }

    /// Begin the link process
    private func requestLink() {
        twitchApi?.requestLinkCode(callback: { response in
            if let linkId: TwitchedLinkId = response {
                // Show link id
                self.loadingIndicator?.stopAnimating()
                self.linkCodeLabel?.text = linkId.id
                // Start timer
                self.statusTimer = Timer.scheduledTimer(timeInterval: 5, target: self,
                        selector: #selector(self.checkLinkStatus(sender:)), userInfo: nil, repeats: true)
            }
            else {
                self.showAlert(.FAILURE)
            }
        })
    }

    /// Show failure alert that dismisses the view
    private func showAlert(_ type: TwitchApi.LinkStatus) {
        var title: String = ""
        var message: String = ""
        switch type {
            case .FAILURE, .WAITING:
                title = "title.error.link".l10n()
                message = "message.error.link_fail".l10n()
            case .TIMEOUT:
                title = "title.error.link".l10n()
                message = "message.error.link_timeout".l10n()
            case .SUCCESS:
                title = "title.link_success".l10n()
                message = "message.link_complete".l10n()
        }
        let alert = UIAlertController(title: title, message: message,
                preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "button.confirm".l10n(),
                style: .cancel, handler: { _ in
            self.dismiss(animated: true)
        }))
        self.present(alert, animated: true)
    }

    /// Handle application becoming active
    func applicationDidBecomeActive() {
        os_log("LoginViewController active", type: .debug)
    }

    // Handle dismissal
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        if let timer = statusTimer {
            if timer.isValid {
                timer.invalidate()
            }
        }
    }
}
