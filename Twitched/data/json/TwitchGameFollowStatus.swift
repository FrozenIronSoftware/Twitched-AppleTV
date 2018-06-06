//
// Created by Rolando Islas on 6/5/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchGameFollowStatus: Codable {
    var status: Bool

    private enum CodingKeys: String, CodingKey {
        case status
    }
}
