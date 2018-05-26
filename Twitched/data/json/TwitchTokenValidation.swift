//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchTokenValidation: Codable {

    var clientId: String
    var login: String
    var scopes: Array<String>
    var userId: String

    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id", login, scopes, userId = "user_id"
    }
}
