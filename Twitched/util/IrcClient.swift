//
// Created by Rolando Islas on 6/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation

class IrcClient {
    func connect(_ login: String) {
        NotificationCenter.default.post(name: .IrcChatMessage, object: self, userInfo: ["test": "Testing"])
    }

    func disconnect() {

    }
}

extension Notification.Name {
    static let IrcChatMessage = Notification.Name("com.frozenironsoftware.twitched.IrcChatMessage")
}
