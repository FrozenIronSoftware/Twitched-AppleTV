//
// Created by Rolando Islas on 7/21/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation
import Regex

class IrcMessage {
    private static var MESSAGE_REGEX: Regex?
    private static var TWITCH_TAG_REGEX: Regex?
    private static var MESSAGE_COMMAND_PARAMS_REGEX: Regex?
    public var twitchTags: Dictionary<String, String>
    public var serverName: String
    public var nick: String
    public var user: String
    public var host: String
    public var command: IrcClient.Command
    public var params: Array<String>

    /// Initialize an IRC message, parsing a raw IRC message with ending \r\n new lines
    public static func from(rawMessage message: String) -> IrcMessage? {
        generateRegex()
        if let match: Match = MESSAGE_REGEX?.findFirst(in: message) {
            let twitchTags: Dictionary<String, String> = parseTwitchTags(rawTags: match.group(named: "twitch_tags"))
            let serverNameOrNick = match.group(named: "servername_or_nick") ?? ""
            let user = match.group(named: "user") ?? ""
            let host = match.group(named: "host") ?? ""
            let command = IrcClient.Command(rawValue: match.group(named: "command") ?? "") ?? IrcClient.Command.NONE
            let params = parseParams(rawParams: match.group(named: "params_all"))
            return IrcMessage(twitchTags, serverNameOrNick, serverNameOrNick, user, host, command, params)
        }
        else {
            return nil
        }
    }

    /// Initialize
    private init(_ twitchTags: Dictionary<String, String>, _ serverName: String, _ nick: String,
                 _ user: String, _ host: String, _ command: IrcClient.Command, _ params: Array<String>) {
        self.twitchTags = twitchTags
        self.serverName = serverName
        self.nick = nick
        self.user = user
        self.host = host
        self.command = command
        self.params = params
    }

    /// Parse a raw irc params string
    private static func parseParams(rawParams: String?) -> Array<String> {
        var params: Array<String> = Array()
        if let rawParams = rawParams {
            if let matches: MatchSequence = IrcMessage.MESSAGE_COMMAND_PARAMS_REGEX?.findAll(in: rawParams) {
                for match in matches {
                    if let paramTrailing = match.group(named: "param_trailing") {
                        params.append(paramTrailing)
                    }
                    else if let paramMiddle = match.group(named: "param_middle") {
                        params.append(paramMiddle)
                    }
                }
            }
        }
        return params
    }

    /// Parse a raw Twitch tags string
    private static func parseTwitchTags(rawTags: String?) -> Dictionary<String, String> {
        var tags: Dictionary<String, String> = Dictionary()
        if let rawTags = rawTags {
            if let matches: MatchSequence = TWITCH_TAG_REGEX?.findAll(in: rawTags) {
                for match in matches {
                    if let key = match.group(named: "key"), let value = match.group(named: "value") {
                        tags[key] = value
                    }
                }
            }
        }
        return tags
    }

    /// Generate the message regex
    private static func generateRegex() {
        let messageCommandParamsRegex = "(\\s(?:(?::(.*))|(?:([^\\s]+))))"
        let twitchTagRegex = "(([^\\s;=]+)=([^\\s;]*))"
        let twitchTagsRegex = String(format: "(?:@((?:%@;?)+)\\s)?", arguments: [twitchTagRegex])
        let messageRegex = String(format: "^%@(?::([^!@\\s]+)(?:!([^@\\s]+))?(?:@([^\\s]+))?\\s)?([A-Za-z0-9]+)(%@+)?" +
                "(?:\\r?\\n?)",
                arguments: [twitchTagsRegex, messageCommandParamsRegex])
        MESSAGE_REGEX = try! Regex(pattern: messageRegex, groupNames: [
            "twitch_tags",
            "twitch_tag",
            "twitch_tag_key",
            "twitch_tag_value",
            "servername_or_nick",
            "user",
            "host",
            "command",
            "params_all",
            "params"
        ])
        TWITCH_TAG_REGEX = try! Regex(pattern: twitchTagRegex, groupNames: ["tag", "key", "value"])
        MESSAGE_COMMAND_PARAMS_REGEX = try! Regex(pattern: messageCommandParamsRegex, groupNames: [
            "params",
            "param_trailing",
            "param_middle"
        ])
    }
}
