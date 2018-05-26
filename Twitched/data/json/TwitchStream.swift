//
// Created by Rolando Islas on 5/11/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import L10n_swift

struct TwitchStream: Codable {
    // Stream
    var id: String
    var userId: String
    var gameId: String?
    var communityIds: Array<String>?
    var type: String
    private var _title: String
    var title: String {
        get {
            if self._title.isEmpty {
                return "title.no_title".l10n()
            }
            else {
                return self._title
            }
        }
        set {
            self._title = newValue
        }
    }
    var viewerCount: Int
    var startedAt: String
    var language: String
    var thumbnailUrl: String

    // VOD
    var description: String?
    var createdAt: String?
    var publishedAt: String?
    var url: String?
    var viewable: String?
    var viewCount: Int
    var duration: String?

    // Twitched
    var userName: TwitchUserName?
    var gameName: String? {
        didSet {
            if let gameName = gameName {
                if gameName.isEmpty {
                    self.gameName = "Unknown"
                }
            }
            else {
                gameName = "Unknown"
            }
        }
    }
    var durationSeconds: Int
    var online: Bool

    private enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", gameId = "game_id", type, _title = "title", viewerCount = "viewer_count",
             startedAt = "started_at", language, thumbnailUrl = "thumbnail_url", viewCount = "view_count",
                userName = "user_name", gameName = "game_name", durationSeconds = "duration_seconds", online,
                communityIds = "community_id", description, createdAt = "created_at", publishedAt = "published_at",
                url, viewable
    }
}
