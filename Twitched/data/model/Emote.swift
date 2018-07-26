//
// Created by Rolando Islas on 7/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation

class Emote {
    public var url: String
    public var start: Int
    public var end: Int

    init(url: String, start: Int, end: Int) {
        self.url = url
        self.start = start
        self.end = end
    }
}
