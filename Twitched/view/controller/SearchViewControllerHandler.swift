//
// Created by Rolando Islas on 9/6/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class SearchViewControllerHandler: UIViewController, UISearchResultsUpdating, UISearchBarDelegate {

    /// Handle search
    func updateSearchResults(for searchController: UISearchController) {
        NotificationCenter.default.post(name: .SearchTextUpdate, object: self,
                userInfo: ["query": searchController.searchBar.text ?? ""])
    }
}

extension Notification.Name {
    static let SearchTextUpdate = Notification.Name("com.frozenironsoftware.twitched.view.controller." +
            "SearchViewControllerHandler.SearchTextUpdate")
}
