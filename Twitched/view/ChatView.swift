//
// Created by Rolando Islas on 6/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class ChatView: UIView {
    private let irc: IrcClient = IrcClient()

    /// Init
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(onIrcMessage), name: .IrcChatMessage,
                object: irc)
        // Listen for application becoming active
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
        setBackgroundColor()
    }

    /// Deinit
    override func removeFromSuperview() {
        super.removeFromSuperview()
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Not focusable
    override var canBecomeFocused: Bool {
        return false
    }

    /// Disconnect from the IRC server
    func disconnect() {
        irc.disconnect()
    }

    /// Connect to the IRC server
    func connect(_ login: String) {
        irc.connect(login)
        DispatchQueue.global().async(qos: .background, execute: {

        })
    }

    /// Handle a message
    @objc private func onIrcMessage(notification: Notification) {
        print(notification.userInfo)
    }

    /// Handle application becoming active
    @objc private func applicationDidBecomeActive() {
        setBackgroundColor()
    }

    /// Set background color based on user interface style
    private func setBackgroundColor() {
        self.onUserInterfaceStyle(completion: { userInterfaceStyle in
            if userInterfaceStyle == UIUserInterfaceStyle.light {
                self.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
            }
            else {
                self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
            }
        })
    }
}

extension UIView {
    /// Wait for the user interface style to be populated
    func onUserInterfaceStyle(completion: @escaping (UIUserInterfaceStyle) -> Void) {
        DispatchQueue.global(qos: .background).async {
            while self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.unspecified {}
            DispatchQueue.main.async {
                completion(self.traitCollection.userInterfaceStyle)
            }
        }
    }
}