//
// Created by Rolando Islas on 6/4/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchGame: Codable {

    var id: String
    var name: String
    var boxArtUrl: String
    var viewers: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, boxArtUrl = "box_art_url", viewers
    }
}
