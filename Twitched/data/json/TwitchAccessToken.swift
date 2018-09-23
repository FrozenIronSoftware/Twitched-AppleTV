//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchAccessToken: Codable {

    var accessToken: String? {
        get {
            if _accessToken != nil {
                return _accessToken
            }
            else if token != nil {
                return token
            }
            else {
                return nil
            }
        }
        set {
            _accessToken = newValue
        }
    }
    private var _accessToken: String?
    var token: String?
    var refreshToken: String?
    var expiresIn: Int?
    var scope: String?
    var error: AnyCodable?
    var complete: Bool?
    var message: String?

    private enum CodingKeys: String, CodingKey {
        case _accessToken = "access_token", refreshToken = "refresh_token", expiresIn = "expires_in", scope, error,
                complete, token, message
    }
}
