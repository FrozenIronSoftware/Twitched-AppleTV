//
// Created by Rolando Islas on 6/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation
import os.log
import SocketSwift
import L10n_swift

class IrcClient {
    private var socket: Socket?
    private var buffer: Array<UInt8> = Array()
    private var bytesRead: Int = 0
    private var channel: String?
    private var isRunning: Bool = false

    /// Connect to the IRC server
    /// @param login Streamer login name
    func connect(login _login: String? = nil) {
        let login = (_login ?? channel) ?? "twitchedapp"
        os_log("IRC socket connecting to %@", type: .debug, login)
        disconnect()
        createSocket()
        sendCommand(.CAP, "REQ", "twitch.tv/tags")
        if let twitchAccessToken = TwitchApi.accessToken, let accessToken = twitchAccessToken.accessToken,
           let login = TwitchApi.userLogin {
            sendCommand(.PASS, "oauth:" + accessToken)
            sendCommand(.NICK, login)
        }
        else {
            sendCommand(.NICK, "justinfan" + String(arc4random_uniform(0x7fffffff)))
        }
        sendCommand(.JOIN, "#" + login)
        DispatchQueue.global().async(qos: .userInitiated, execute: {
            while self.isRunning {
                self.readFromSocket()
                self.parseData()
            }
        })
    }

    /// Send an IRC command
    /// @param command command to send
    /// @param args command arguments
    private func sendCommand(_ command: Command, _ args: String...) {
        if let socket = socket {
            var formattedArgs: String = ""
            var argIndex: Int = 0
            for arg in args {
                if argIndex == args.count - 1 {
                    formattedArgs += ":" + arg
                }
                else {
                    formattedArgs += arg + " "
                }
                argIndex += 1
            }
            let data: Array<UInt8> = Array(String(format: "%@ %@\r\n",
                    arguments: [command.rawValue, formattedArgs]).utf8)
            os_log("IRC Command: %{public}@ %@", type: .debug, command.rawValue, formattedArgs)
            do {
                try socket.write(data)
            }
            catch {
                os_log("IRC socket command write failed: %@", type: .debug, error.localizedDescription)
                disconnect()
            }
        }
    }

    /// Parse the buffer data
    private func parseData() {
        if buffer.count == 0 {
            return
        }
        if let data = String(bytes: buffer, encoding: .utf8) {
            var split: Array<String> = Array()
            data.enumerateLines(invoking: { line, _ in
                split.append(String(format: "%@\r\n", arguments: [line]))
            })
            if data.last != Character("\r\n") && split.count > 0 {
                buffer = Array(split.removeLast().dropLast(2).utf8)
            } else {
                buffer.removeAll(keepingCapacity: false)
            }
            for message in split {
                os_log("%@", type: .debug, message)
                if let ircMessage = IrcMessage.from(rawMessage: message) {
                    if ircMessage.command == Command.PING {
                        if let pingParam = ircMessage.params[safe: 0] {
                            sendCommand(.PONG, pingParam)
                        }
                    }
                    else if ircMessage.command == Command.PRIVMSG {
                        NotificationCenter.default.post(name: .IrcChatMessage, object: self,
                                userInfo: ["message": ChatMessage(ircMessage: ircMessage)])
                    }
                    else if ircMessage.command == Command.NOTICE {
                        var notice: String = ""
                        for param in ircMessage.params {
                            notice = String(format: "%@%@ ", arguments: [notice, param])
                        }
                        os_log("IRC Notice: %@", type: .debug, notice)
                    }
                    else if ircMessage.command == Command.JOIN {
                        self.channel = ircMessage.params[safe: 0]
                        NotificationCenter.default.post(name: .IrcChatMessage, object: self,
                                userInfo: ["message":
                                    ChatMessage(name: "twitched".l10n(), message: "message_irc_connected".l10n(),
                                            color: "#ffffff")
                                ])
                    }
                    else if ircMessage.command == Command.PART {
                        NotificationCenter.default.post(name: .IrcChatMessage, object: self,
                                userInfo: ["message":
                                ChatMessage(name: "twitched".l10n(), message: "message_irc_disconnected".l10n(),
                                        color: "#ffffff")
                                ])
                    }
                }
            }
        }
    }

    /// Attempt to read data from the socket
    private func readFromSocket() {
        if let socket = self.socket {
            do {
                let canRead = try socket.wait(for: .read, timeout: 0, retryOnInterrupt: false)
                if canRead {
                    var buffer: Array<UInt8> = Array<UInt8>(repeating: 0, count: 1024)
                    let bytesRead: Int = try socket.read(&buffer, size: 1024)
                    if bytesRead > 0 {
                        self.buffer.append(contentsOf: buffer[0...bytesRead - 1])
                    }
                }
            }
            catch {
                os_log("IRC socket read failed: %{public}@", type: .debug, error.localizedDescription)
                disconnect()
            }
        }
    }

    /// Construct a socket
    private func createSocket() {
        do {
            socket = try Socket(.inet, type: .stream, protocol: .tcp)
            if let ip = hostToIp("irc.chat.twitch.tv") {
                try socket?.connect(port: 6667, address: ip)
                self.isRunning = true
            }
            else {
                os_log("IRC socket failed to resolve IP or twitch IRC server", type: .debug)
                disconnect()
            }
        }
        catch {
            os_log("IRC socket failed to create new socket: %@", type: .debug, error.localizedDescription)
            disconnect()
        }
    }

    /// Get an ip address from DNS for a domain name
    private func hostToIp(_ hostname: String)  -> String? {
        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
           let address = addresses.firstObject as? NSData {
            var hostnameCharArray = Array<CChar>(repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(address.length),
                    &hostnameCharArray, socklen_t(hostnameCharArray.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: hostnameCharArray)
            }
        }
        return nil
    }

    /// Disconnect from the IRC server
    func disconnect() {
        os_log("IRC socket disconnected", type: .debug)
        self.isRunning = false
        if let socket = socket {
            socket.close()
        }
        socket = nil
        buffer.removeAll(keepingCapacity: true)
        bytesRead = 0
    }
}

extension Notification.Name {
    static let IrcChatMessage = Notification.Name("com.frozenironsoftware.twitched.IrcChatMessage")
}

extension IrcClient {
    /// Irc Commands
    public enum Command: String {
        case NONE = "NONE"
        case PASS = "PASS"
        case NICK = "NICK"
        case JOIN = "JOIN"
        case PING = "PING"
        case PONG = "PONG"
        case PRIVMSG = "PRIVMSG"
        case PART = "PART"
        case MOTD_START = "RPL_MOTDSTART"
        case MOTD_START_D = "375"
        case MOTD = "RPL_MOTD"
        case MOTD_D = "372"
        case MOTD_END = "RPL_ENDOFMOTD"
        case MOTD_END_D = "376"
        case CAP = "CAP"
        case MOTD_TWITCH_1 = "001"
        case MOTD_TWITCH_2 = "002"
        case MOTD_TWITCH_3 = "003"
        case MOTD_TWITCH_4 = "004"
        case NAMES_D = "353"
        case NOTICE = "NOTICE"
    }
}