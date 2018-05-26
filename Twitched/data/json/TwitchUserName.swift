//
// Created by Rolando Islas on 5/12/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchUserName: Codable {
    var login: String
    var displayName: String

    private enum CodingKeys : String, CodingKey {
        case login, displayName = "display_name"
    }
}
