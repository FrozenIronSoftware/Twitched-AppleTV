//
// Created by Rolando Islas on 7/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation

class TwitchBadgeSet: Codable {
    public var versions: Dictionary<String, TwitchBadge> = Dictionary()

    private enum CodingKeys: String, CodingKey {
        case versions
    }
}
