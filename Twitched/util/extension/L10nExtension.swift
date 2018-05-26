//
// Created by Rolando Islas on 5/18/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import Foundation
import L10n_swift

extension String {
    /// Translate a string using args as formatting arguments
    public  func l10nf(_ instance: L10n = .shared, resource: String? = nil, arg: [CVarArg]) -> String {
        return String(format: instance.string(for: self, resource: resource), arguments: arg)
    }
}
