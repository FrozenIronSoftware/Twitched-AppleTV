//
// Created by Rolando Islas on 7/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation

class TwitchBadge: Codable {
    public var imageUrl1x: String = ""
    public var imageUrl2x: String = ""
    public var imageUrl4x: String = ""
    public var description: String = ""
    public var title: String = ""
    public var clickAction: String = ""
    public var clickUrl: String = ""

    private enum CodingKeys: String, CodingKey {
        case imageUrl1x = "image_url_1x", imageUrl2x = "image_url_2x", imageUrl4x = "image_url_4x",
             description, title, clickAction = "click_action", clickUrl = "click_url"
    }
}
