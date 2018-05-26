//
// Created by Rolando Islas on 5/17/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.log
import Alamofire
import L10n_swift

class StreamInfoViewController: UIViewController, UIScrollViewDelegate, ResettingViewController {

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
    private var twitchApi: TwitchApi?
    private var stream: TwitchStream?
    private var user: TwitchUser?

    /// Handle view loading
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("StreamInfoViewController did load", type: .debug)
        twitchApi = TwitchApi()
        setBackgroundColorStyle()
        setFieldData()
        addActionEvents()
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
    }

    /// Handle the presented controller being dismissed
    override func dismiss(animated flag: Bool, completion: (() -> Void)?) {
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
            previewImage?.setUrl(stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "825")
                    .replacingOccurrences(of: "{height}", with: "464"),
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
    private func loadVideoView() {
        if let stream: TwitchStream = stream {
            let videoViewController: VideoViewController = self.storyboard?.instantiateViewController(
                    withIdentifier: "videoViewController") as! VideoViewController
            videoViewController.setId(type: .STREAM, stream.userId)
            videoViewController.setTitle(stream.title)
            videoViewController.setSubTitle("title.streamer_playing_game".l10nf(arg: [
                stream.userName != nil ? (stream.userName?.displayName)! : "",
                stream.gameName != nil ? stream.gameName! : ""
            ]))
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
            twitchApi?.getUsers(parameters: [
                "id": stream.userId
            ], callback: { response in
                if let users: Array<TwitchUser> = response {
                    if users.count == 1 {
                        self.user = users[0]
                        self.backgroundImage?.setUrl((self.user?.offlineImageUrl)!,
                                errorImageName: nil)
                        self.descriptionTextView?.text = self.user?.description
                    }
                }
            })
            updateFollowStatus()
        }
    }

    /// Check if the user follows the current stream and update the follow button
    private func updateFollowStatus(loadCache: Bool = true) {
        if let stream: TwitchStream = stream {
            if (twitchApi?.isLoggedIn)! {
                twitchApi?.getFollows(parameters: [
                    "from_id": TwitchApi.userId,
                    "to_id": stream.userId,
                    "no_cache": !loadCache
                ], callback: { response in
                    if let follows: Array<TwitchUserFollow> = response {
                        // Is following
                        if follows.count == 1 {
                            self.followButton?.normalBackgroundColor = Constants.COLOR_FOLLOW_GREEN
                            self.followButton?.normalBackgroundEndColor = Constants.COLOR_FOLLOW_GREEN
                            self.followButton?.selectedBackgroundColor = Constants.COLOR_FOLLOW_RED
                            self.followButton?.selectedBackgroundEndColor = Constants.COLOR_FOLLOW_RED
                            self.followButtonLabel?.text = "button.unfollow".l10n()
                        }
                        // Not following
                        else {
                            self.followButton?.normalBackgroundColor = Constants.COLOR_TWITCH_PURPLE
                            self.followButton?.normalBackgroundEndColor = Constants.COLOR_TWITCH_PURPLE
                            self.followButton?.selectedBackgroundColor = Constants.COLOR_FOLLOW_GREEN
                            self.followButton?.selectedBackgroundEndColor = Constants.COLOR_FOLLOW_GREEN
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
    func applicationDidBecomeActive() {
        os_log("StreamInfoViewController active", type: .debug)
        setBackgroundColorStyle()
        // Propagate to the presented view
        if let presentedView: ResettingViewController = self.presentedViewController as? ResettingViewController {
            presentedView.applicationDidBecomeActive()
        }
        gameLabel?.applicationDidBecomeActive()
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
    @IBAction
    private func gameButtonSelected1(_ button: UIButton) {
        // TODO open game view
    }
    
    /// Handle the game button being selected
    @IBAction func gameButtonSelected(_ sender: FocusableLabel) {
        // TODO open game view
        print("game label selected")
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
            if (twitchApi?.isLoggedIn)! {
                twitchApi?.followUser(id: stream.userId, callback: { success in
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
}
