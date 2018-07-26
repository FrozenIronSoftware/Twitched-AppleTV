//
// Created by Rolando Islas on 7/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation

class TwitchBadges: Codable {
    public var badgeSets: Dictionary<String, TwitchBadgeSet> = Dictionary()

    private enum CodingKeys: String, CodingKey {
        case badgeSets = "badge_sets"
    }
}
