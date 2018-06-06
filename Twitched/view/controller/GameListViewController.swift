//
//  GameListViewController.swift
//  Twitched
//
//  Created by Rolando Islas on 4/28/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log
import L10n_swift

class GameListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let MAX_PAGES: Int = 8
    private let PAGE_LIMIT: Int = 50
    private let UPDATE_INTERVAL: TimeInterval = 60 * 10
    @IBOutlet private weak var tableView: UITableView?
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    private var topGames: Array<TwitchGame> = Array()
    private var followedGames: Array<TwitchGame> = Array()
    private var topGamesPage: Int = 0
    private var followedGamesPage: Int = 0
    private var topGamesLoading: Bool = false
    private var followedGamesLoading: Bool = false
    private var lastUpdateTime: TimeInterval?

    /// View loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("GameList did load", type: .debug)
        reset()
    }

    /// Reset the state to page zero and load followed games
    private func reset() {
        self.topGamesPage = 0
        self.followedGamesPage = 0
        self.topGamesLoading = false
        self.followedGamesLoading = false
        loadTopGames(completion: {
            self.loadFollowedGames(completion: {
                self.tableView?.reloadData()
                self.loadingIndicator?.stopAnimating()
            })
        })
    }

    /// View will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL {
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
    private func loadTopGames(append: Bool = false, completion: @escaping (() -> Void) = {}) {
        if self.topGamesPage < self.MAX_PAGES && !self.topGamesLoading {
            self.topGamesLoading = true
            TwitchApi.getTopGames(parameters: [
                "limit": self.PAGE_LIMIT,
                "offset": self.topGamesPage
            ], callback: { response in
                if let games: Array<TwitchGame> = response {
                    if append {
                        self.topGames.append(contentsOf: games)
                    } else {
                        self.topGames = games
                    }
                    self.topGamesPage += 1
                    if games.count < self.PAGE_LIMIT - 1 { // Twitch Top games endpoint returns one less than limit!?
                        self.topGamesPage = self.MAX_PAGES
                    }
                }
                self.topGamesLoading = false
                completion()
            })
        }
        else {
            completion()
        }
    }

    /// Load followed games
    private func loadFollowedGames(append: Bool = false, completion: @escaping (() -> Void) = {}) {
        if TwitchApi.isLoggedIn && self.followedGamesPage < self.MAX_PAGES && !self.followedGamesLoading {
            self.followedGamesLoading = true
            TwitchApi.getFollowedGames(parameters: [
                "limit": self.PAGE_LIMIT,
                "offset": self.followedGamesPage
            ], callback: { response in
                if let games: Array<TwitchGame> = response {
                    if append {
                        self.followedGames.append(contentsOf: games)
                    } else {
                        self.followedGames = games
                    }
                    self.followedGamesPage += 1
                    if games.count < self.PAGE_LIMIT - 1 { // Twitch Top games endpoint returns one less than limit!?
                        self.followedGamesPage = self.MAX_PAGES
                    }
                }
                self.followedGamesLoading = false
                completion()
            })
        }
        else {
            completion()
        }
    }

    /// Set table view rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows: Int = 0
        if self.followedGames.count > 0 {
            rows += 1
        }
        if self.topGames.count > 0 {
            rows += 1
        }
        return rows
    }

    /// Set table view cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: GameCollectionCell = tableView.dequeueReusableCell(withIdentifier: "gameCollectionCell",
                for: indexPath) as! GameCollectionCell
        if indexPath.item == 0 && self.topGames.count > 0 {
            cell.headerTitle = "title.games".l10n()
            cell.games = self.topGames
        }
        else if self.followedGames.count > 0 {
            cell.headerTitle = "title.followed_games".l10n()
            cell.games = self.followedGames
        }
        cell.callbackAction = onCollectionCellAction
        cell.indexPath = indexPath
        cell.collectionView?.reloadData()
        return cell
    }

    /// Handle the cells having an action
    private func onCollectionCellAction(cell: Any, gestureRecognizer: UIGestureRecognizer) {
        if let cell: GameCollectionCell = cell as? GameCollectionCell, let indexPath = cell.indexPath {
            if indexPath.item == 0 && self.topGames.count > 0 {
                let count: Int = self.topGames.count
                loadTopGames(append: true, completion: {
                    cell.games = self.topGames
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < cell.games.count {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
            else if self.followedGames.count > 0 {
                let count: Int = self.followedGames.count
                loadFollowedGames(append: true, completion: {
                    cell.games = self.followedGames
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < cell.games.count {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
        }
        else if let cell: GameCell = cell as? GameCell, let game = cell.game {
            loadGameView(game: game)
        }
    }

    /// Load the game view for the selected game
    private func loadGameView(game: TwitchGame) {
        let videoGridViewController: VideoGridViewController = self.storyboard?.instantiateViewController(
                withIdentifier: "videoGridViewController") as! VideoGridViewController
        videoGridViewController.gameId = game.id
        videoGridViewController.headerTitle = game.name
        videoGridViewController.modalPresentationStyle = .blurOverFullScreen
        videoGridViewController.modalTransitionStyle = .crossDissolve
        self.present(videoGridViewController, animated: true)
    }

    /// Handle the application and this view resuming
    @objc func applicationDidBecomeActive() {
        os_log("GameListViewController active", type: .debug)
        // Update the items if needed
        if lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL {
            reset()
        }
    }
}
