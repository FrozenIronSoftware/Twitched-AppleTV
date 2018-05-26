//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchUserFollow: Codable {

    var fromId: String
    var toId: String
    var followedAt: String?

    private enum CodingKeys: String, CodingKey {
        case fromId = "from_id", toId = "to_id", followedAt = "followed_at"
    }
}
