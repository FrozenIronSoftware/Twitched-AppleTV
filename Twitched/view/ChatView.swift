//
// Created by Rolando Islas on 6/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log

class ChatView: UIView {
    private var irc: IrcClient?
    private var chatMessages: Array<UILabel> = Array()
    private let addQueue: DispatchQueue = DispatchQueue(label: "org.twitched.twitched.chatview.addmessage",
            attributes: .concurrent)
    private var test: Int = 0

    /// Init
    override func awakeFromNib() {
        super.awakeFromNib()
        // Listen for application becoming active
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
        setBackgroundColor()
    }

    /// Deinit
    override func removeFromSuperview() {
        super.removeFromSuperview()
        NotificationCenter.default.removeObserver(self, name: .IrcChatMessage, object: irc)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        disconnect()
    }

    /// Not focusable
    override var canBecomeFocused: Bool {
        return false
    }

    /// Disconnect from the IRC server
    func disconnect() {
        if let irc = irc {
            NotificationCenter.default.removeObserver(self, name: .IrcChatMessage, object: irc)
            irc.disconnect()
        }
    }

    /// Connect to the IRC server
    func connect(_ login: String) {
        disconnect()
        irc = IrcClient()
        // Listen for IRC messages
        NotificationCenter.default.addObserver(self, selector: #selector(onIrcMessage), name: .IrcChatMessage,
                object: irc!)
        irc?.connect(login: login)
    }

    /// Handle a message
    @objc private func onIrcMessage(notification: Notification) {
        if let userInfo = notification.userInfo, let message = userInfo["message"] as? ChatMessage {
            var urls: Array<String> = Array()
            urls.append(contentsOf: message.badges)
            for emote in message.emotes {
                urls.append(emote.url)
            }
            let _ = UIImage.loadAllFromUrl(urls: urls, completion: { images in
                let size: CGFloat = 25
                let margin: CGFloat = 5
                let label = UILabel(frame: CGRect(
                        x: self.frame.minX + 20,
                        y: self.frame.minY + 20,
                        width: self.frame.width - 40,
                        height: self.frame.height))
                label.preferredMaxLayoutWidth = self.frame.width
                label.font = UIFont(name: "Helvetica Neue", size: size)
                label.textColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark ? UIColor.white :
                        UIColor.black
                label.textAlignment = .left
                label.numberOfLines = 30
                label.isUserInteractionEnabled = false
                let attributedMessage = NSMutableAttributedString()
                // Add badges
                var badgeIndex: Int = 0
                for badge in message.badges {
                    if let badgeImage = images[badge] {
                        let badgeAttachment = NSTextAttachment()
                        badgeAttachment.image = badgeImage
                        badgeAttachment.bounds = CGRect(x: badgeIndex > 0 ? margin : 0, y: 0, width: size, height: size)
                        attributedMessage.append(NSAttributedString(attachment: badgeAttachment))
                    }
                    badgeIndex += 1
                }
                // Add name
                if message.badges.count > 0 {
                    attributedMessage.append(NSAttributedString(string: "\t"))
                }
                let name = NSAttributedString(string: message.name,
                        attributes: [
                            NSAttributedStringKey.foregroundColor: self.shiftColorForStyle(message.color),
                            NSAttributedStringKey.backgroundColor: UIColor.clear
                        ])
                attributedMessage.append(name)
                // Add emotes
                if message.emotes.count == 0 {
                    attributedMessage.append(NSAttributedString(string: "\t" + message.message))
                }
                else {
                    var lastPos: Int = 0
                    for emote in message.emotes {
                        // Append pre
                        let start = message.message.index(message.message.startIndex, offsetBy: lastPos)
                        let end = message.message.index(message.message.startIndex, offsetBy: emote.start)
                        lastPos = emote.end + 1
                        attributedMessage.append(NSAttributedString(string: "\t" +
                                String(message.message[start..<end])))
                        if let emoteImage = images[emote.url] {
                            let emoteAttachment = NSTextAttachment()
                            emoteAttachment.image = emoteImage
                            let imageWidthScaled = emoteImage != nil ?
                                size * emoteImage!.size.height / emoteImage!.size.width : size
                            emoteAttachment.bounds = CGRect(x: margin, y: 0, width: size, height: imageWidthScaled)
                            attributedMessage.append(NSAttributedString(attachment: emoteAttachment))
                        }
                    }
                    // Append post
                    if lastPos <= message.message.count {
                        let start = message.message.index(message.message.startIndex, offsetBy: lastPos)
                        attributedMessage.append(NSAttributedString(string: String(message.message.suffix(from: start))))
                    }
                }
                label.isHidden = false
                label.isEnabled = true
                label.isOpaque = true
                label.attributedText = attributedMessage
                if Thread.isMainThread {
                    self.addMessage(label: label)
                }
                else {
                    DispatchQueue.main.sync(execute: {
                        self.addMessage(label: label)
                    })
                }
            })
        }
    }

    /// Darken a color if the user style is light or return the same color if the user style is dark
    private func shiftColorForStyle(_ color: UIColor) -> UIColor {
        switch self.traitCollection.userInterfaceStyle {
            case .light:
                if let rgba = color.cgColor.components {
                    if rgba.count >= 3 {
                        let d: CGFloat = 0.5
                        return UIColor(
                                red: max(rgba[0] - d, 0),
                                green: max(rgba[1] - d - 0.2, 0),
                                blue: max(rgba[2] - d, 0),
                                alpha: 1)
                    }
                }
            case .dark:
                break
            case .unspecified:
                break
        }
        return color
    }

    /// Add a label to the chat
    private func addMessage(label: UILabel) {
        label.sizeToFit()
        // Position after last message
        if let lastMessage = self.chatMessages.last {
            label.frame = CGRect(
                    x: label.frame.minX,
                    y: lastMessage.frame.maxY,
                    width: label.frame.width,
                    height: label.frame.height)
        }
        // Add label
        self.chatMessages.append(label)
        self.addSubview(label)
        // Push all other labels up if this label cannot fit on screen
        if label.frame.maxY > self.frame.maxY - 20 {
            let moveAmount = label.frame.maxY - self.frame.maxY + 20
            UIView.animate(withDuration: 0.1, animations: {
                for existingLabel in self.chatMessages {
                    existingLabel.frame = existingLabel.frame.offsetBy(dx: 0, dy: -moveAmount)
                }
            })
        }
        // Remove first message if it is off the screen
        if let firstMessage = self.chatMessages.first {
            if firstMessage.frame.maxY < self.frame.minY {
                firstMessage.removeFromSuperview()
                self.chatMessages.remove(at: 0)
            }
        }
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
            var waiting = true
            while waiting {
                DispatchQueue.main.async {
                    waiting = self.traitCollection.userInterfaceStyle == .unspecified
                }
                sleep(1)
            }
            DispatchQueue.main.async {
                completion(self.traitCollection.userInterfaceStyle)
            }
        }
    }
}
