//
// Created by Rolando Islas on 9/27/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

class TwitchVideoAccessToken: Codable {
    var token: String
    var sig: String
    var mobileRestricted: Bool?

    private enum CodingKeys: String, CodingKey {
        case token, sig, mobileRestricted
    }
}
