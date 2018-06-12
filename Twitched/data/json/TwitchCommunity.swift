//
// Created by Rolando Islas on 6/10/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

struct TwitchCommunity: Codable {

    var id: String
    var avatarImageUrl: String
    var coverImageUrl: String
    var description: String
    var descriptionHtml: String
    var language: String
    var ownerId: String
    var rules: String
    var rulesHtml: String
    var summary: String
    var channels: Int
    var name: String
    var viewers: Int
    var modified: Int
    var displayName: String

    /// Attempts to return display name if available, otherwise the normal name is returned
    var safeName: String {
        get {
            if !displayName.isEmpty {
                return displayName
            }
            else {
                return name
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, avatarImageUrl = "avatar_image_url", coverImageUrl = "cover_image_url", description,
             descriptionHtml = "description_html", language, ownerId = "owner_id", rules, rulesHtml = "rules_html",
             summary, channels, name, viewers, modified, displayName = "display_name"
    }
}
