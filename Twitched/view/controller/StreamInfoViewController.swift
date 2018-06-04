//
// Created by Rolando Islas on 5/17/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log
import Alamofire
import L10n_swift

class StreamInfoViewController: UIViewController, UIScrollViewDelegate, UITableViewDelegate,
        UITableViewDataSource {
    private let MAX_VIDEO_PAGES: Int = 8
    @IBOutlet private weak var backgroundImage: UIImageView?
    @IBOutlet private weak var blurView: UIVisualEffectView?
    @IBOutlet private weak var titleLabel: UILabel?
    @IBOutlet private weak var previewImage: UIImageView?
    @IBOutlet private weak var previewImageContainerView: FocusableView?
    @IBOutlet private weak var streamerLabel: UILabel?
    @IBOutlet private weak var gameLabel: FocusableLabel?
    @IBOutlet private weak var viewersTitleLable: UILabel?
    @IBOutlet private weak var viewersLabel: UILabel?
    @IBOutlet private weak var descriptionTextView: FocusableTextView?
    @IBOutlet private weak var followButton: FocusTvButton?
    @IBOutlet private weak var followButtonLabel: UILabel?
    @IBOutlet private weak var tableView: UITableView?
    private var stream: TwitchStream?
    private var user: TwitchUser?
    private var archivedVideos: Array<TwitchStream>?
    private var highlightedVideos: Array<TwitchStream>?
    private var archivedVideosCursor: Int = 0
    private var highlightedVideosCursor: Int = 0
    private var requestingArchivedVideos: Bool = false
    private var requestingHighlightedVideos: Bool = false

    /// Handle view loading
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("StreamInfoViewController did load", type: .debug)
        setBackgroundColorStyle()
        setFieldData()
        addActionEvents()
    }

    /// Will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Handle the view appearing
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadUserInfo()
    }

    /// Handle the view disappearing
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundImage?.image = nil
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Handle the presented controller being dismissed
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }

    /// Set the fields to the appropriate values
    private func setFieldData() {
        if let stream: TwitchStream = self.stream {
            // Title
            titleLabel?.text = stream.title
            // User
            if let userName = stream.userName {
                streamerLabel?.text = userName.displayName
            }
            else {
                streamerLabel?.text = ""
            }
            // Game
            if let gameName = stream.gameName {
                gameLabel?.text = gameName
                gameLabel?.isUserInteractionEnabled = true
            }
            else {
                gameLabel?.text = ""
                gameLabel?.isUserInteractionEnabled = false
            }
            // Viewers
            viewersLabel?.text = stream.viewerCount.l10n()
            // Description
            if let user = self.user {
                descriptionTextView?.text = user.description
            }
            else {
                descriptionTextView?.text = ""
            }
            // Thumbnail
            let _ = previewImage?.setUrl(stream.thumbnailUrl.replacingOccurrences(of: "{width}",
                            with: String(Int((self.previewImage?.bounds.width)!)))
                    .replacingOccurrences(of: "{height}", with: String(Int((self.previewImage?.bounds.height)!))),
                    errorImageName: Constants.IMAGE_ERROR_VIDEO_THUMBNAIL)
        }
    }

    /// Add events for UI items
    private func addActionEvents() {
        // Preview image selected
        previewImageContainerView?.callbackAction = previewImageSelected
        // Description text view selected
        descriptionTextView?.callbackAction = showDescriptionAlert
        // Game label selected

    }

    /// Show an alert with the streamer description text and name
    private func showDescriptionAlert(view: Any, gestureRecognizer: UIGestureRecognizer) {
        if let user: TwitchUser = self.user {
            let alert: UIAlertController = UIAlertController(
                    title: user.displayName,
                    message: user.description,
                    preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: nil, style: .cancel))
            self.present(alert, animated: true)
        }
    }

    /// Handle the preview image being selected
    private func previewImageSelected(view: Any, gestureRecognizer: UIGestureRecognizer) {
        self.loadVideoView()
    }

    /// Load the video view
    private func loadVideoView(_ stream: TwitchStream? = nil, _ type: TwitchApi.VideoType = .STREAM) {
        var _stream = stream
        if _stream == nil {
            _stream = self.stream
        }
        if let stream: TwitchStream = _stream {
            let videoViewController: VideoViewController = self.storyboard?.instantiateViewController(
                    withIdentifier: "videoViewController") as! VideoViewController
            switch type {
                case .STREAM:
                    videoViewController.setId(type: .STREAM, stream.userId)
                    videoViewController.setSubTitle("title.streamer_playing_game".l10nf(arg: [
                        stream.userName != nil ? (stream.userName?.displayName)! : "",
                        stream.gameName != nil ? stream.gameName! : ""
                    ]))
                case .VIDEO:
                    videoViewController.setId(type: .VIDEO, stream.id)
                    videoViewController.setSubTitle(stream.userName != nil ? (stream.userName?.displayName)! : "")
            }
            videoViewController.setTitle(stream.title)
            if let user: TwitchUser = self.user {
                videoViewController.setThumbnailUrl(user.profileImageUrl)
            }
            if let userName = stream.userName {
                videoViewController.setLoadingTitle(userName.displayName)
            }
            videoViewController.modalPresentationStyle = .blurOverFullScreen
            videoViewController.modalTransitionStyle = .crossDissolve
            self.present(videoViewController, animated: true)
        }
    }

    /// Load info for the user to populate screen details
    private func loadUserInfo() {
        if let stream: TwitchStream = stream {
            TwitchApi.getUsers(parameters: [
                "id": stream.userId
            ], callback: { response in
                if let users: Array<TwitchUser> = response {
                    if users.count == 1 {
                        self.user = users[0]
                        let _ = self.backgroundImage?.setUrl((self.user?.offlineImageUrl)!,
                                errorImageName: nil)
                        self.descriptionTextView?.text = self.user?.description
                    }
                }
            })
            updateFollowStatus()
            loadVideos(completion: {
                self.tableView?.reloadData()
            })
        }
    }

    /// Load videos
    private func loadVideos(type: VideoType = .ALL, offset: Int? = 0, append: Bool? = false,
                            completion: (() -> Void)?) {
        let callback = completion != nil ? completion! : {}
        var completionCount = 0
        if let stream: TwitchStream = stream {
            // Request archived videos
            if (type == .ALL || type == .ARCHIVE) && !self.requestingArchivedVideos &&
                       self.archivedVideosCursor < self.MAX_VIDEO_PAGES {
                var params: Parameters = [
                    "user_id": stream.userId,
                    "type": "archive",
                    "limit": 50
                ]
                if let offset = offset {
                    params["offset"] = offset
                }
                self.requestingArchivedVideos = true
                TwitchApi.getVideos(parameters: params, callback: { response in
                    if let videos: Array<TwitchStream> = response {
                        self.requestingArchivedVideos = false
                        if let append = append {
                            if append {
                                if self.archivedVideos == nil {
                                    self.archivedVideos = Array()
                                }
                                self.archivedVideos?.append(contentsOf: videos)
                            }
                            else {
                                self.archivedVideos = videos
                            }
                        }
                        else {
                            self.archivedVideos = videos
                        }
                        self.archivedVideosCursor += 1
                    }
                    completionCount += 1
                    if completionCount == 2 || type != .ALL {
                        callback()
                    }
                })
            }
            else {
                completionCount += 1
                if type != .ALL {
                    callback()
                }
            }
            // Request highlights
            if (type == .ALL || type == .HIGHLIGHT) && !self.requestingHighlightedVideos &&
                       self.highlightedVideosCursor < self.MAX_VIDEO_PAGES {
                var params: Parameters = [
                    "user_id": stream.userId,
                    "type": "highlight",
                    "limit": 50
                ]
                if let offset = offset {
                    params["offset"] = offset
                }
                self.requestingHighlightedVideos = true
                TwitchApi.getVideos(parameters: params, callback: { response in
                    if let videos: Array<TwitchStream> = response {
                        self.requestingHighlightedVideos = false
                        if let append = append {
                            if append {
                                if self.highlightedVideos == nil {
                                    self.highlightedVideos = Array()
                                }
                                self.highlightedVideos?.append(contentsOf: videos)
                            }
                            else {
                                self.highlightedVideos = videos
                            }
                        }
                        else {
                            self.highlightedVideos = videos
                        }
                        self.highlightedVideosCursor += 1
                    }
                    completionCount += 1
                    if completionCount == 2 || type != .ALL {
                        callback()
                    }
                })
            }
            else {
                completionCount += 1
                if completionCount == 2 && type == .ALL {
                    callback()
                }
            }
        }
        else {
            callback()
        }
    }

    /// Check if the user follows the current stream and update the follow button
    private func updateFollowStatus(loadCache: Bool = true) {
        os_log("StreamInfoViewController: Updating follow status", type: .debug)
        if let stream: TwitchStream = stream {
            if TwitchApi.isLoggedIn {
                TwitchApi.getFollows(parameters: [
                    "from_id": TwitchApi.userId,
                    "to_id": stream.userId,
                    "no_cache": loadCache ? "false" : "true"
                ], callback: { response in
                    if let follows: Array<TwitchUserFollow> = response {
                        // Is following
                        if follows.count == 1 {
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
                    }
                })
            }
        }
    }

    /// Set background blur color style
    private func setBackgroundColorStyle() {
        DispatchQueue.global(qos: .background).async {
            while self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.unspecified {}
            DispatchQueue.main.async {
                if self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.light {
                    self.blurView?.effect = UIBlurEffect(style: .extraLight)
                }
                else {
                    self.blurView?.effect = UIBlurEffect(style: .extraDark)
                }
            }
        }
    }

    /// Handle application activating
    @objc func applicationDidBecomeActive() {
        os_log("StreamInfoViewController active", type: .debug)
        setBackgroundColorStyle()
    }

    /// Set stream
    func setStream(_ stream: TwitchStream) {
        self.stream = stream
    }

    /// Set the preferred view
    override var preferredFocusedView: UIView? {
        return self.previewImageContainerView
    }
    
    /// Handle the game button being selected
    @IBAction func gameButtonSelected(_ sender: FocusableLabel) {
        if let stream = self.stream, let gameId = stream.gameId, let gameName = stream.gameName {
            let videoGridViewController: VideoGridViewController = self.storyboard?.instantiateViewController(
                    withIdentifier: "videoGridViewController") as! VideoGridViewController
            videoGridViewController.gameId = gameId
            videoGridViewController.headerTitle = gameName
            videoGridViewController.modalPresentationStyle = .blurOverFullScreen
            videoGridViewController.modalTransitionStyle = .crossDissolve
            self.present(videoGridViewController, animated: true)
        }
    }
    
    /// Handle the play button being pressed
    @IBAction
    private func playButtonSelected(_ button: UIButton) {
        self.loadVideoView()
    }
    
    /// Handle the follow button being selected
    @IBAction
    private func followButtonSelected(_ button: UIButton) {
        if let stream = self.stream {
            if TwitchApi.isLoggedIn {
                TwitchApi.followUser(id: stream.userId, callback: { success in
                    if success {
                        self.updateFollowStatus(loadCache: false)
                    }
                })
            }
            else {
                let loginViewController: LoginViewController = self.storyboard?.instantiateViewController(
                        withIdentifier: "loginViewController") as! LoginViewController
                loginViewController.modalPresentationStyle = .blurOverFullScreen
                loginViewController.modalTransitionStyle = .crossDissolve
                self.present(loginViewController, animated: true)
            }
        }
    }

    /// Set table view rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows: Int = 0
        if self.archivedVideos != nil && (self.archivedVideos?.count)! > 0 {
            rows += 1
        }
        if self.highlightedVideos != nil && (self.highlightedVideos?.count)! > 0 {
            rows += 1
        }
        return rows
    }

    /// Set table view cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: VideoCollectionCell = tableView.dequeueReusableCell(withIdentifier: "collectionViewCell",
                for: indexPath) as! VideoCollectionCell
        if indexPath.item == 0 && self.archivedVideos != nil && (self.archivedVideos?.count)! > 0 {
            cell.headerTitle = "title.archived_videos".l10n()
            cell.videos = self.archivedVideos
        }
        else if self.highlightedVideos != nil && (self.highlightedVideos?.count)! > 0 {
            cell.headerTitle = "title.highlighted_videos".l10n()
            cell.videos = self.highlightedVideos
        }
        else {
            cell.headerTitle = "title.videos".l10n()
        }
        cell.callbackAction = onVideoAction
        cell.indexPath = indexPath
        return cell
    }

    /// Handle a video item being selected or selection reaching the end of the list
    func onVideoAction(videoCell: Any, gesture: UIGestureRecognizer) {
        // Video selection
        if let cell: VideoOnDemandCell = videoCell as? VideoOnDemandCell {
            loadVideoView(cell.stream, .VIDEO)
        }
        // End of list - load more
        else if let cell: VideoCollectionCell = videoCell as? VideoCollectionCell, let indexPath = cell.indexPath {
            if indexPath.item == 0 && self.archivedVideos != nil && (self.archivedVideos?.count)! > 0 {
                let count: Int = (self.archivedVideos?.count)!
                loadVideos(type: .ARCHIVE, offset: archivedVideosCursor, append: true, completion: {
                    cell.videos = self.archivedVideos
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < (self.archivedVideos?.count)! {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
            else if self.highlightedVideos != nil && (self.highlightedVideos?.count)! > 0 {
                let count: Int = (self.highlightedVideos?.count)!
                loadVideos(type: .HIGHLIGHT, offset: highlightedVideosCursor, append: true, completion: {
                    cell.videos = self.highlightedVideos
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < (self.highlightedVideos?.count)! {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        cell.collectionView?.insertItems(at: indexPaths)
                    }
                })
            }
        }
    }

    private enum VideoType {
        case ARCHIVE, HIGHLIGHT, ALL
    }
}
