//
// Created by Rolando Islas on 7/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log

class ChatMessage {
    private static let EMOTE_URL = "http://static-cdn.jtvnw.net/emoticons/v1/$ID/$SIZE"
    public private(set) var name: String
    public private(set) var message: String
    public private(set) var color: UIColor
    public private(set) var badges: Array<String>
    public private(set) var emotes: Array<Emote>

    /// Construct a chat message from an IRC PRIVMSG command
    init(ircMessage message: IrcMessage) {
        self.name = message.nick
        if let displayName =  message.twitchTags["display-name"] {
            self.name = displayName
        }
        self.message = message.params[safe: 1] ?? ""
        if let colorHex = message.twitchTags["color"], let color = UIColor(hex: colorHex) {
            self.color = color
        }
        else {
            self.color = UIColor(red: 0, green: 1, blue: 0, alpha: 1)
        }
        self.badges = ChatMessage.parseTwitchBadges(message.twitchTags["badges"])
        self.emotes = ChatMessage.parseTwitchEmotes(message.twitchTags["emotes"])
    }

    /// Parse emote string into an array of emotes
    /// @param paramsRaw raw twitch tag
    private static func parseTwitchEmotes(_ paramsRaw: String?) -> Array<Emote> {
        var emotes: Array<Emote> = Array()
        if let paramsRaw = paramsRaw {
            let emoteSplit = paramsRaw.components(separatedBy: "/")
            for emoteString in emoteSplit {
                let idIndexSplit = emoteString.components(separatedBy: ":")
                if idIndexSplit.count > 1 {
                    let emoteId = idIndexSplit[0]
                    let indexSplit = idIndexSplit[1].components(separatedBy: ",")
                    for index in indexSplit {
                        let startEndSplit = index.components(separatedBy: "-")
                        if startEndSplit.count == 2 {
                            let url = EMOTE_URL.replacingOccurrences(of: "$ID", with: emoteId)
                                    .replacingOccurrences(of: "$SIZE", with: "4.0")
                            let start = Int(startEndSplit[0])
                            let end = Int(startEndSplit[1])
                            if let start = start, let end = end {
                                emotes.append(Emote(url: url, start: start, end: end))
                            }
                        }
                    }
                }
            }
        }
        // Ensure emotes are ordered bty their start index
        var ordered: Array<Emote> = Array()
        var addedSize: Int = -1
        var smallest: Emote?
        for _ in emotes {
            for emote in emotes {
                if (smallest == nil || emote.start < (smallest?.start)!) && emote.start > addedSize {
                    smallest = emote
                }
            }
            if let _smallest = smallest {
                ordered.append(_smallest)
                addedSize = _smallest.start
                smallest = nil
            }
            // Should not happen
            else {
                os_log("Failed to order emotes", type: .error)
                return ordered
            }
        }
        return ordered
    }

    /// Parse badges into an array of image urls
    /// @param badgesRaw raw twitch tag
    private static func parseTwitchBadges(_ badgesRaw: String?) -> Array<String> {
        var badges: Array<String> = Array()
        if let badgesRaw = badgesRaw, let twitchBadges = TwitchApi.chatBadges {
            let commaSplit = badgesRaw.components(separatedBy: ",")
            for badgeString in commaSplit {
                let slashSplit = badgeString.components(separatedBy: "/")
                if slashSplit.count == 2 {
                    let name: String = slashSplit[0]
                    let version: String = slashSplit[1]
                    if let badgeSet = twitchBadges.badgeSets[name], let badge = badgeSet.versions[version] {
                        badges.append(badge.imageUrl4x)
                    }
                }
            }
        }
        return badges
    }

    /// Construct a chat message
    /// @param name user name to display
    /// @param message chat message
    /// @param user name color hex string
    init(name: String, message: String, color: String) {
        self.name = name
        self.message = message
        if let color = UIColor(hex: color) {
            self.color = color
        }
        else {
            self.color = UIColor(red: 0, green: 1, blue: 0, alpha: 1)
        }
        self.emotes = Array()
        self.badges = Array()
    }
}

extension UIColor {
    /// Initialize a UIColor from a hexadecimal string (e.g. #000000)
    public convenience init?(hex: String, alpha: CGFloat = 1) {
        if let colorInt = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) {
            self.init(
                    red: (CGFloat)(((colorInt & 0xff0000) >> 16)) / (CGFloat)(255.0),
                    green: (CGFloat)(((colorInt & 0xff00) >> 8)) / (CGFloat)(255.0),
                    blue: (CGFloat)((colorInt & 0xff)) / (CGFloat)(255.0),
                    alpha: alpha)
        }
        else {
            return nil
        }
    }
}
