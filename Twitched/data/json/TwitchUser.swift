//
// Created by Rolando Islas on 5/18/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import L10n_swift

struct TwitchUser: Codable {

    var id: String
    var login: String
    var displayName: String
    var type: String
    var broadcasterType: String
    private var _description: String
    var description: String {
        get {
            if self._description.isEmpty {
                return "message.no_description".l10n()
            }
            else {
                return self._description
            }
        }
        set {
            self._description = newValue
        }
    }
    var profileImageUrl: String
    var offlineImageUrl: String
    var viewCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, login, displayName = "display_name", type, broadcasterType = "broadcaster_type",
             _description = "description", profileImageUrl = "profile_image_url", offlineImageUrl = "offline_image_url",
             viewCount = "view_count"
    }
}
