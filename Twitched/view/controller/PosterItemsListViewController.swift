//
//  PosterItemsListViewController.swift
//  Twitched
//
//  Created by Rolando Islas on 4/28/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log
import L10n_swift

class PosterItemsListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let MAX_PAGES: Int = 8
    private let PAGE_LIMIT: Int = 50
    private let UPDATE_INTERVAL: TimeInterval = 60 * 10
    @IBOutlet private weak var tableView: UITableView?
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    /// If enabled, communities will be loaded instead of games
    @IBInspectable private var loadCommunityData: Bool = false
    private var topItems: Array<Any> = Array()
    private var followedItems: Array<Any> = Array()
    private var topItemsPage: Int = 0
    private var followedItemsPage: Int = 0
    private var topItemsLoading: Bool = false
    private var followedItemsLoading: Bool = false
    private var lastUpdateTime: TimeInterval?
    public static var needsGameUpdate: Bool = false
    public static var needsCommunityUpdate: Bool = false
    private var shouldReload: Bool {
        get {
            return (lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL) ||
                    (PosterItemsListViewController.needsGameUpdate && !loadCommunityData) ||
                    (PosterItemsListViewController.needsCommunityUpdate && loadCommunityData)
        }
    }

    /// View loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("GameList did load: Community data: %@", type: .debug, loadCommunityData.description)
        reset()
    }

    /// Reset the state to page zero and load followed games
    private func reset() {
        self.topItemsPage = 0
        self.followedItemsPage = 0
        self.topItemsLoading = false
        self.followedItemsLoading = false
        self.topItems = []
        self.followedItems = []
        if PosterItemsListViewController.needsGameUpdate && !self.loadCommunityData {
            PosterItemsListViewController.needsGameUpdate = false
        }
        else if PosterItemsListViewController.needsCommunityUpdate && self.loadCommunityData {
            PosterItemsListViewController.needsCommunityUpdate = false
        }
        loadTopItems(completion: {
            self.loadFollowedItems(completion: {
                if self.topItems.count > 0 {
                    self.lastUpdateTime = Date().timeIntervalSince1970
                }
                DispatchQueue.main.async(execute: {
                    self.tableView?.reloadData()
                    self.loadingIndicator?.stopAnimating()
                })
            })
        })
    }

    /// View will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.shouldReload {
            reset()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Load top games
    private func loadTopItems(append: Bool = false, completion: @escaping (() -> Void) = {}) {
        if self.topItemsPage < self.MAX_PAGES && !self.topItemsLoading {
            self.topItemsLoading = true
            let onTopItemData: (Array<Any>?) -> Void = { response in
                if let games: Array<Any> = response {
                    if append {
                        self.topItems.append(contentsOf: games)
                    }
                    else {
                        self.topItems = games
                    }
                    self.topItemsPage += 1
                    if games.count < self.PAGE_LIMIT - 1 { // Twitch Top games endpoint returns one less than limit!?
                        self.topItemsPage = self.MAX_PAGES
                    }
                }
                self.topItemsLoading = false
                completion()
            }
            if self.loadCommunityData {
                TwitchApi.getTopCommunities(parameters: [
                    "limit": self.PAGE_LIMIT,
                    "offset": self.topItemsPage
                ], callback: onTopItemData)
            }
            else {
                TwitchApi.getTopGames(parameters: [
                    "limit": self.PAGE_LIMIT,
                    "offset": self.topItemsPage
                ], callback: onTopItemData)
            }
        }
        else {
            completion()
        }
    }

    /// Load followed games
    private func loadFollowedItems(append: Bool = false, completion: @escaping (() -> Void) = {}) {
        TwitchApi.afterLogin(callback: { isLoggedIn in
            if isLoggedIn && self.followedItemsPage < self.MAX_PAGES && !self.followedItemsLoading {
                self.followedItemsLoading = true
                let onFollowedItemData: (Array<Any>?) -> Void = { response in
                    if let games: Array<Any> = response {
                        if append {
                            self.followedItems.append(contentsOf: games)
                        } else {
                            self.followedItems = games
                        }
                        self.followedItemsPage += 1
                        if games.count < self.PAGE_LIMIT - 1 { // Twitch Top games endpoint returns one less than limit!?
                            self.followedItemsPage = self.MAX_PAGES
                        }
                    }
                    self.followedItemsLoading = false
                    completion()
                }
                if self.loadCommunityData {
                    TwitchApi.getFollowedCommunities(parameters: [
                        "limit": self.PAGE_LIMIT,
                        "offset": self.followedItemsPage
                    ], callback: onFollowedItemData)
                } else {
                    TwitchApi.getFollowedGames(parameters: [
                        "limit": self.PAGE_LIMIT,
                        "offset": self.followedItemsPage
                    ], callback: onFollowedItemData)
                }
            } else {
                completion()
            }
        })
    }

    /// Set table view rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows: Int = 0
        if self.followedItems.count > 0 {
            rows += 1
        }
        if self.topItems.count > 0 {
            rows += 1
        }
        return rows
    }

    /// Set table view cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PosterItemCollectionCell = tableView.dequeueReusableCell(withIdentifier: "gameCollectionCell",
                for: indexPath) as! PosterItemCollectionCell
        if indexPath.item == 0 && self.topItems.count > 0 {
            if !self.loadCommunityData {
                cell.headerTitle = "title.games".l10n()
            }
            else {
                cell.headerTitle = "title.communities".l10n()
            }
            cell.items = self.topItems
        }
        else if self.followedItems.count > 0 {
            if !self.loadCommunityData {
                cell.headerTitle = "title.followed_games".l10n()
            }
            else {
                cell.headerTitle = "title.followed_communities".l10n()
            }
            cell.items = self.followedItems
        }
        cell.callbackAction = onCollectionCellAction
        cell.indexPath = indexPath
        DispatchQueue.main.async(execute: {
            cell.collectionView?.reloadData()
        })
        return cell
    }

    /// Handle the cells having an action
    private func onCollectionCellAction(cell: Any, gestureRecognizer: UIGestureRecognizer) {
        if let cell: PosterItemCollectionCell = cell as? PosterItemCollectionCell, let indexPath = cell.indexPath {
            if indexPath.item == 0 && self.topItems.count > 0 {
                let count: Int = self.topItems.count
                loadTopItems(append: true, completion: {
                    cell.items = self.topItems
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < cell.items.count {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
            else if self.followedItems.count > 0 {
                let count: Int = self.followedItems.count
                loadFollowedItems(append: true, completion: {
                    cell.items = self.followedItems
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < cell.items.count {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
        }
        else if let cell: PosterItemCell = cell as? PosterItemCell, let item = cell.item {
            if let game: TwitchGame = item as? TwitchGame {
                loadGridView(game: game)
            }
            else if let community: TwitchCommunity = item as? TwitchCommunity {
                loadGridView(community: community)
            }

        }
    }

    /// Load the game view for the selected game
    private func loadGridView(game: TwitchGame? = nil, community: TwitchCommunity? = nil) {
        let videoGridViewController: VideoGridViewController = self.storyboard?.instantiateViewController(
                withIdentifier: "videoGridViewController") as! VideoGridViewController
        if let game = game {
            videoGridViewController.gameId = game.id
            videoGridViewController.headerTitle = game.name
        }
        else if let community = community {
            videoGridViewController.communityId = community.id
            videoGridViewController.headerTitle = community.safeName
        }
        else {
            os_log("PosterItemListView: loadGridView: No community or game passed", type: .debug)
            return
        }
        videoGridViewController.modalPresentationStyle = .blurOverFullScreen
        videoGridViewController.modalTransitionStyle = .crossDissolve
        videoGridViewController.dismissCompletion = {
            if self.shouldReload {
                self.reset()
            }
        }
        self.present(videoGridViewController, animated: true)
    }

    /// Handle the application and this view resuming
    @objc func applicationDidBecomeActive() {
        os_log("GameListViewController active: Community data: %@", type: .debug, loadCommunityData.description)
        // Update the items if needed
        if shouldReload {
            reset()
        }
    }

    /// Encode
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(loadCommunityData, forKey: "loadCommunityData")
    }

    /// Decode
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        if let loadCommunityData = coder.decodeObject(forKey: "loadCommunityData") as? Bool {
            self.loadCommunityData = loadCommunityData
        }
    }
}
