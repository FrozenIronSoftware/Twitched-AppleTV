//
//  VideoGridViewController.swift
//  Twitched
//
//  Created by Rolando Islas on 4/28/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import os.log
import L10n_swift

class VideoGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private let UPDATE_INTERVAL: TimeInterval = 60 * 10
    private let MAX_PAGE: Int = 10
    @IBOutlet private weak var collectionView: UICollectionView?
    @IBOutlet private weak var messageLabel: UILabel?
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet private weak var followedLoginMessageView: UIView?
    private var lastUpdateTime: TimeInterval?
    private var streams: Array<TwitchStream>?
    private var page: Int?
    private var isLoading: Bool?
    private var initialHeaderBounds: CGRect?
    @IBInspectable var gameId: String = ""
    @IBInspectable var communityId: String = ""
    @IBInspectable var headerTitle: String = ""
    @IBInspectable var loadFollowedStreams: Bool = false
    private var isFollowButtonEnabled: Bool {
        get {
            return !gameId.isEmpty || !communityId.isEmpty
        }
    }
    private var focusGuide: UIFocusGuide?
    private var followButton: FocusTvButton?
    private var followButtonLabel: UILabel?
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [self.collectionView!]
    }
    private var isFollowing: Bool = false
    var dismissCompletion: () -> Void = {}
    private var resultsPerPageLimit: Int {
        get {
            return loadFollowedStreams ? 500 : 40
        }
    }
    public static var needsFollowsUpdate: Bool = false
    private var shouldUpdate: Bool {
        get {
            return (lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL) ||
                    (VideoGridViewController.needsFollowsUpdate && self.loadFollowedStreams) ||
                    (VideoGridViewController.needsPopularUpdate && !self.loadFollowedStreams)
        }
    }
    static var needsPopularUpdate: Bool = false

    /// View is about to appear
    /// Check if enough time has passed that the grid needs an update
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("VideoGridView will appear", type: .debug)
        if self.shouldUpdate {
            populateCollectionViewWithReset()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    // Appeared
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Save initial header position
        if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                at: IndexPath(item: 0, section: 0)) {
            self.initialHeaderBounds = header.bounds
        }
        updateLoginState()
    }

    /// Determine if login message should be shown
    private func updateLoginState() {
        if let followedLoginMessageView = self.followedLoginMessageView {
            followedLoginMessageView.alpha = 0
            followedLoginMessageView.isUserInteractionEnabled = false
            if self.loadFollowedStreams {
                TwitchApi.afterLogin(callback: { isLoggedIn in
                    if !isLoggedIn {
                        DispatchQueue.main.async(execute: {
                            followedLoginMessageView.alpha = 1
                            followedLoginMessageView.isUserInteractionEnabled = true
                            self.view.bringSubview(toFront: followedLoginMessageView)
                        })
                    }
                })
            }
        }
    }

    /// Disappeared
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Reset header position
        if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                at: IndexPath(item: 0, section: 0)) {
            if let bounds = self.initialHeaderBounds {
                header.bounds = bounds
            }
        }
    }

    /// Reset the view and populate the view
    private func populateCollectionViewWithReset() {
        page = 0
        isLoading = false
        VideoGridViewController.needsFollowsUpdate = false
        VideoGridViewController.needsPopularUpdate = false
        populateCollectionView()
    }

    /// Handle the view loading
    /// Initialize
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("VideoGridView loaded", type: .debug)
        populateCollectionViewWithReset()
    }

    /// Retrieves stream data from the API and populates the collection view
    private func populateCollectionView(offset: Int? = 0, append: Bool? = false) {
        os_log("Populating collection view", type: .debug)
        // Show the spinner if the collection view is empty
        if streams == nil || streams?.count == 0 {
            loadingIndicator?.startAnimating()
        }
        // Hide the previous message
        self.messageLabel?.text = ""
        // Set to loading
        self.isLoading = true
        // Fetch streams
        var params: Parameters = [
            "limit": resultsPerPageLimit,
            "offset": offset!
        ]
        if !self.gameId.isEmpty {
            params["game_id"] = self.gameId
        }
        if !self.communityId.isEmpty {
            params["community_id"] = self.communityId
        }
        let handleStreamData: (Array<TwitchStream>?) -> Void = { response in
            if let streams: Array<TwitchStream> = response {
                if streams.count > 0 {
                    self.lastUpdateTime = Date().timeIntervalSince1970
                }
                if (!append!) || self.streams == nil {
                    self.streams = streams
                    self.collectionView?.reloadData()
                }
                else {
                    let count: Int = (self.streams?.count)!
                    self.streams?.append(contentsOf: streams)
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < (self.streams?.count)! {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        self.collectionView?.insertItems(at: indexPaths)
                    }
                }
                self.page? += 1
                if streams.count < self.resultsPerPageLimit || self.loadFollowedStreams {
                    self.page = self.MAX_PAGE
                }
            }
            else {
                self.lastUpdateTime = 0
                if self.streams == nil || self.streams?.count == 0 {
                    self.messageLabel?.text = "message.error.api_fail".l10nf(arg: [1000])
                }
            }
            self.loadingIndicator?.stopAnimating()
            self.isLoading = false
        }
        if loadFollowedStreams {
            TwitchApi.afterLogin(callback: { isLoggedIn in
                if isLoggedIn {
                    TwitchApi.getFollowedStreams(parameters: params, callback: handleStreamData)
                }
            })
        }
        else {
            TwitchApi.getStreams(parameters: params, callback: handleStreamData)
        }
    }

    /// Handle a memory warning
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        os_log("VideoGridViewController: Memory warning not handled", type: .error)
    }

    /// Define the number of cells
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let counts = getStreamCounts()
        return section == 1 && self.loadFollowedStreams ? counts.offlineCount :
                self.loadFollowedStreams ? counts.onlineCount : counts.onlineCount + counts.offlineCount;
    }

    /// Populate cells
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) ->
            UICollectionViewCell {
        let cell: VideoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "video", for: indexPath)
                as! VideoCell
        let counts: OnlineOfflineCount = getStreamCounts()
        let streamIndex: Int = self.loadFollowedStreams && indexPath.section == 1 ?
            indexPath.item + counts.onlineCount : indexPath.item
        if let streams = self.streams, let stream = streams[safe: streamIndex] {
            cell.setStream(stream)
        }
        return cell
    }

    /// Get the online and offline stream count
    /// Index 0 will be online index 1 will be offline
    private func getStreamCounts() -> OnlineOfflineCount {
        var onlineCount: Int = 0
        var offlineCount: Int = 0
        if let streams = self.streams {
            for stream in streams {
                if stream.type == "user" || stream.type == "user_follow" {
                    offlineCount += 1;
                } else {
                    onlineCount += 1;
                }
            }
        }
        return OnlineOfflineCount(onlineCount, offlineCount)
    }

    /// Handle item selection
    /// Open the streamer page for the selected stream
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell: VideoCell = collectionView.cellForItem(at: indexPath) as! VideoCell
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            cell.getThumbnail()?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                cell.getThumbnail()?.transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: { _ in
                UIView.animate(withDuration: 0.4, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                    self.view.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                    self.view.alpha = 0
                }, completion: { _ in
                    self.view.transform = CGAffineTransform(scaleX: 1, y: 1)
                    self.view.alpha = 1
                })
                self.showStreamInfoScreen(cell.getStream())
            })
        })
    }

    /// Present the screen info screen
    private func showStreamInfoScreen(_ stream: TwitchStream?) {
        if let stream: TwitchStream = stream {
            let streamInfoViewController: StreamInfoViewController = self.storyboard?.instantiateViewController(
                    withIdentifier: "streamInfoViewController") as! StreamInfoViewController
            streamInfoViewController.setStream(stream)
            streamInfoViewController.modalPresentationStyle = .blurOverFullScreen
            streamInfoViewController.modalTransitionStyle = .crossDissolve
            streamInfoViewController.dismissCompletion = {
                if self.shouldUpdate {
                    self.populateCollectionViewWithReset()
                }
            }
            DispatchQueue.main.async(execute: {
                self.present(streamInfoViewController, animated: true)
            })
        }
    }

    /// Handle item focused
    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator) {
        // Move the header title if the cell focused is the first item
        if let indexPath = context.nextFocusedIndexPath {
            if let header = collectionView.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)) {
                if indexPath.section == 0 && (indexPath.item == 0 || (indexPath.item == 3 && isFollowButtonEnabled)) {
                    if let initialHeaderBounds =  self.initialHeaderBounds {
                        UIView.animate(withDuration: 0.2, animations: {
                            header.bounds = initialHeaderBounds.offsetBy(dx: 0, dy: 20)
                        })
                    }
                }
                else if let previousIndexPath = context.previouslyFocusedIndexPath {
                    if previousIndexPath.section == 0 && (previousIndexPath.item == 0 ||
                            (previousIndexPath.item == 3 && isFollowButtonEnabled)) {
                        if let initialHeaderBounds =  self.initialHeaderBounds {
                            UIView.animate(withDuration: 0.2, animations: {
                                header.bounds = initialHeaderBounds
                            })
                        }
                    }
                }
            }
        }
    }

    /// Handle item pre-focus
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
        // Load the next page of results if the item focused is in the last row
        if context.nextFocusedView is VideoCell {
            var indexPath: IndexPath = context.nextFocusedIndexPath!
            if let streams = self.streams {
                if indexPath.item >= streams.count - 1 - 4 && indexPath.item <= streams.count - 1 && !isLoading! &&
                           page! < MAX_PAGE {
                    populateCollectionView(offset: page, append: true)
                }
            }
        }
        // Reset the header title if the focus is not a video cell
        else {
            if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)) {
                if let bounds = self.initialHeaderBounds {
                    UIView.animate(withDuration: 0.2, animations: {
                        header.bounds = bounds
                    })
                }
            }
        }
        return true
    }

    /// Populate the header
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header: TextHeader = collectionView.dequeueReusableSupplementaryView(
                ofKind: UICollectionElementKindSectionHeader,
                withReuseIdentifier: "header", for: indexPath) as! TextHeader
        if self.loadFollowedStreams && indexPath.section == 1 {
            header.textLabel?.text = "title.offline".l10n()
        }
        else {
            header.textLabel?.text = headerTitle.l10n()
        }
        if !isFollowButtonEnabled {
            header.followButton?.isEnabled = false
            header.followButton?.isUserInteractionEnabled = false
            header.followButton?.alpha = 0
            header.followButtonView?.alpha = 0
        }
        else if indexPath.section == 0 {
            // Show
            DispatchQueue.global().async(execute: {
                while self.streams == nil {}
                DispatchQueue.main.async(execute: {
                    UIView.animate(withDuration: 0.2, animations: {
                        header.followButton?.isEnabled = true
                        header.followButton?.isUserInteractionEnabled = true
                        header.followButton?.alpha = 1
                        header.followButtonView?.alpha = 1
                        header.followButtonLabel?.alpha = 1
                    })
                })
            })
            // Create focus guide
            if let focusGuide = self.focusGuide {
                self.view.removeLayoutGuide(focusGuide)
            }
            focusGuide = UIFocusGuide()
            self.view.addLayoutGuide(focusGuide!)
            focusGuide?.preferredFocusEnvironments = [header.followButton!]
            focusGuide?.widthAnchor.constraint(equalTo: (header.textLabel?.widthAnchor)!).isActive = true
            focusGuide?.heightAnchor.constraint(equalTo: (header.textLabel?.heightAnchor)!).isActive = true
            focusGuide?.topAnchor.constraint(equalTo: (header.textLabel?.topAnchor)!).isActive = true
            focusGuide?.leftAnchor.constraint(equalTo: (header.textLabel?.leftAnchor)!).isActive = true
            // Set button style
            self.followButton = header.followButton
            self.followButtonLabel = header.followButtonLabel
            updateFollowStatus()
            // Set button callback
            header.callbackAction = onFollowButtonSelected
        }
        return header
    }

    /// Handle follow button selection
    func onFollowButtonSelected(button: Any, gesture: UIGestureRecognizer) {
        if let _: FocusTvButton = button as? FocusTvButton {
            TwitchApi.afterLogin(callback: { isLoggedIn in
                if isLoggedIn {
                    // Game
                    if !self.gameId.isEmpty {
                        if self.isFollowing {
                            TwitchApi.unfollowGame(id: self.gameId, callback: { success in
                                if success {
                                    self.updateFollowStatus(loadCache: false)
                                }
                            })
                        } else {
                            TwitchApi.followGame(id: self.gameId, callback: { success in
                                if success {
                                    self.updateFollowStatus(loadCache: false)
                                }
                            })
                        }
                        PosterItemsListViewController.needsGameUpdate = true
                    }
                    // Community
                    else if !self.communityId.isEmpty {
                        if self.isFollowing {
                            TwitchApi.unfollowCommunity(id: self.communityId, callback: { success in
                                if success {
                                    self.updateFollowStatus(loadCache: false)
                                }
                            })
                        }
                        else {
                            TwitchApi.followCommunity(id: self.communityId, callback: { success in
                                if success {
                                    self.updateFollowStatus(loadCache: false)
                                }
                            })
                        }
                        PosterItemsListViewController.needsCommunityUpdate = true
                    }
                } else {
                    let loginViewController: LoginViewController = self.storyboard?.instantiateViewController(
                            withIdentifier: "loginViewController") as! LoginViewController
                    loginViewController.modalPresentationStyle = .blurOverFullScreen
                    loginViewController.modalTransitionStyle = .crossDissolve
                    loginViewController.dismissCallback = {
                        self.populateCollectionViewWithReset()
                    }
                    DispatchQueue.main.async(execute: {
                        self.present(loginViewController, animated: true)
                    })
                }
            })
        }
    }

    /// Check if the user follows the current stream and update the follow button
    private func updateFollowStatus(loadCache: Bool = true) {
        os_log("VideoGridViewController: Updating follow status", type: .debug)
        TwitchApi.afterLogin(callback: { isLoggedIn in
            if isLoggedIn {
                // Followed games
                if !self.gameId.isEmpty {
                    TwitchApi.getFollowedGame(parameters: [
                        "id": self.gameId,
                        "no_cache": loadCache ? "false" : "true"
                    ], callback: { isFollowing in
                        self.setFollowButtonState(isFollowing)
                    })
                } else if !self.communityId.isEmpty {
                    TwitchApi.getFollowedCommunities(parameters: [
                        "to_id": self.communityId
                    ], callback: { response in
                        if let communities: Array<TwitchCommunity> = response {
                            if communities.count > 0 {
                                self.setFollowButtonState(true)
                            } else {
                                self.setFollowButtonState(false)
                            }
                        } else {
                            self.setFollowButtonState(false)
                        }
                    })
                }
            }
        })
    }

    /// Set follow button state with animation
    private func setFollowButtonState(_ following: Bool) {
        self.isFollowing = following
        UIView.animate(withDuration: 0.2, animations: {
            // Is following
            if following {
                self.followButton?.normalBackgroundColor = Constants.COLOR_FOLLOW_GREEN
                self.followButton?.normalBackgroundEndColor = Constants.COLOR_FOLLOW_GREEN
                self.followButton?.selectedBackgroundColor = Constants.COLOR_FOLLOW_RED
                self.followButton?.selectedBackgroundEndColor = Constants.COLOR_FOLLOW_RED
                self.followButton?.focusedBackgroundColor = Constants.COLOR_FOLLOW_RED
                self.followButton?.focusedBackgroundEndColor = Constants.COLOR_FOLLOW_RED
                self.followButtonLabel?.text = "button.unfollow".l10n()
            }
            // Not following
            else {
                self.followButton?.normalBackgroundColor = Constants.COLOR_TWITCH_PURPLE
                self.followButton?.normalBackgroundEndColor = Constants.COLOR_TWITCH_PURPLE
                self.followButton?.selectedBackgroundColor = Constants.COLOR_FOLLOW_GREEN
                self.followButton?.selectedBackgroundEndColor = Constants.COLOR_FOLLOW_GREEN
                self.followButton?.focusedBackgroundColor = Constants.COLOR_FOLLOW_GREEN
                self.followButton?.focusedBackgroundEndColor = Constants.COLOR_FOLLOW_GREEN
                self.followButtonLabel?.text = "button.follow".l10n()
            }
        })
    }

    /// Handle the application and this view resuming
    @objc func applicationDidBecomeActive() {
        os_log("VideoGridView active", type: .debug)
        // Update the items if needed
        if self.shouldUpdate {
            populateCollectionViewWithReset()
        }
        // Focus the active cell
        for cell in (collectionView?.visibleCells)! {
            let cell: VideoCell = cell as! VideoCell
            cell.setFocused(cell.isFocused)
        }
    }

    /// Handle dismissal
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        self.dismissCompletion()
    }

    /// Set sections
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.loadFollowedStreams ? 2 : 1;
    }

    /// Encode
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(gameId, forKey: "gameId")
        coder.encode(communityId, forKey: "communityId")
        coder.encode(headerTitle, forKey: "headerTitle")
        coder.encode(loadFollowedStreams, forKey: "loadFollowedStreams")
    }

    /// Decode
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        if let gameId = coder.decodeObject(forKey: "gameId") as? String {
            self.gameId = gameId
        }
        if let communityId = coder.decodeObject(forKey: "communityId") as? String {
            self.communityId = communityId
        }
        if let headerTitle = coder.decodeObject(forKey: "headerTitle") as? String {
            self.headerTitle = headerTitle
        }
        if let loadFollowedStreams = coder.decodeObject(forKey: "loadFollowedStreams") as? Bool {
            self.loadFollowedStreams = loadFollowedStreams
        }
    }
    
    /// Handle accout link button pressed
    @IBAction
    private func handleAccountLinkButton() {
        let loginViewController: LoginViewController = self.storyboard?.instantiateViewController(
                withIdentifier: "loginViewController") as! LoginViewController
        loginViewController.modalPresentationStyle = .blurOverFullScreen
        loginViewController.modalTransitionStyle = .crossDissolve
        loginViewController.dismissCallback = {
            DispatchQueue.main.async(execute: {
                self.updateLoginState()
                self.populateCollectionViewWithReset()
            })
        }
        DispatchQueue.main.async(execute: {
            self.present(loginViewController, animated: true)
        })
    }
}
