//
// Created by Rolando Islas on 5/23/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchedLinkId: Codable {

    var id: String
    var version: Int

    private enum CodingKeys: String, CodingKey {
        case id, version
    }

}
