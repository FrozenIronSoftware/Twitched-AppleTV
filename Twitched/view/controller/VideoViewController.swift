//
// Created by Rolando Islas on 5/20/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import os.log

class VideoViewController: UIViewController, AVPlayerViewControllerDelegate {

    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet private weak var titleLabel: UILabel?
    private var idType: TwitchApi.VideoType?
    private var id: String?
    private var titleMeta: String?
    private var subTitle: String?
    private var loadingTitle: String?
    private var thumbnail: UIImage?
    private var thumbnailUrl: String?
    private var player: AVPlayer?

    /// Loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleLabel?.text = loadingTitle
    }

    /// Will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    @objc func applicationDidBecomeActive() {
        os_log("VideoViewController: active", type: .debug)
    }

    /// Disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        if let player = player {
            player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
            if let item = player.currentItem {
                item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            }
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewErrorLogEntry, object: player)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: player)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player)
        }
    }

    /// Appeared
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadStreamInfo()
    }

    /// Start the load process
    private func loadStreamInfo() {
        if let id: String = id, let idType: TwitchApi.VideoType = idType {
            switch idType {
                case .STREAM:
                    TwitchApi.getStreams(parameters: [
                        "user_id": id
                    ], callback: { response in
                        if let streams: Array<TwitchStream> = response {
                            if streams.count == 1 {
                                let stream: TwitchStream = streams[0]
                                if stream.online {
                                    let hlsUrl: String = TwitchApi.getHlsUrl(type: .STREAM, id: stream.userId)
                                    self.fetchThumbnailThenPlayVideo(hlsUrl)
                                }
                                else {
                                    self.showOfflineAlert()
                                }
                            }
                            // No streams - streamer is offline
                            else {
                                self.showOfflineAlert()
                            }
                        }
                        // Invalid data
                        else {
                            self.showApiErrorAlert()
                        }
                    })
                case .VIDEO:
                    let hlsUrl: String = TwitchApi.getHlsUrl(type: .VIDEO, id: id)
                    self.fetchThumbnailThenPlayVideo(hlsUrl)
            }
        }
    }

    /// Show an api error alert
    private func showApiErrorAlert() {
        showAlert(title: "title.error", message: "message.error.api_fail", args: [2000])
    }

    /// Shows an offline alert that dismisses this controller when exited
    private func showOfflineAlert() {
        showAlert(title: "title.stream_offline", message: "message.stream_offline")
    }

    /// Show a video error alert
    private func showVideoErrorAlert() {
        showAlert(title: "title.error.video_fail", message: "message.error.video_fail")
    }

    /// Show an alert that dismisses this presented view
    private func showAlert(title: String, message: String, args: [CVarArg]? = nil) {
        let alert: UIAlertController = UIAlertController(
                title: title.l10n(),
                message: args == nil ? message.l10n() : message.l10nf(arg: args!),
                preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "button.confirm".l10n(),
                style: .cancel, handler: { _ in
            self.dismiss(animated: true)
        }))
        self.present(alert, animated: true)
    }

    /// Fetch the thumbnal and play the video
    private func fetchThumbnailThenPlayVideo(_ url: String) {
        if let thumbnailUrl: String = self.thumbnailUrl {
            ImageUtil.imageFromUrl(url: thumbnailUrl, completion: { response in
                if let image: UIImage = response {
                    self.thumbnail = image
                }
                self.playVideo(url)
            })
        }
        else {
            playVideo(url)
        }
    }

    /// Play a video
    private func playVideo(_ url: String) {
        let playerAsset: AVURLAsset =  AVURLAsset(url: URL(
                string: url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!, options: [
            "AVURLAssetHTTPHeaderFieldsKey": TwitchApi.generateHeaders() as Any
        ])
        let playerItem: AVPlayerItem = AVPlayerItem(asset: playerAsset)
        playerItem.externalMetadata = generateMetadata()
        let player: AVPlayer = AVPlayer(playerItem: playerItem)
        let playerViewController: AVPlayerViewController = AVPlayerViewController()
        playerViewController.restorationIdentifier = "playerViewController"
        playerViewController.player = player
        playerViewController.view.frame = self.view.bounds
        playerViewController.allowedSubtitleOptionLanguages = [""]
        playerViewController.isSkipBackwardEnabled = false
        playerViewController.isSkipForwardEnabled = false
        self.addChildViewController(playerViewController)
        self.view.addSubview(playerViewController.view)
        playerViewController.didMove(toParentViewController: self)
        playerViewController.delegate = self
        // Add observers
        self.player = player
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: .new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoError),
                name: .AVPlayerItemNewErrorLogEntry, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoError),
                name: .AVPlayerItemFailedToPlayToEndTime, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoFinish),
                name: .AVPlayerItemDidPlayToEndTime, object: player)
        player.play()
    }

    /// Handle video finish
    @objc func handleVideoFinish() {
        self.dismiss(animated: true)
    }

    /// Handle a video error
    @objc func handleVideoError() {
        if let idType = self.idType {
            switch idType {
            case .VIDEO:
                showVideoErrorAlert()
            case .STREAM:
                showOfflineAlert()
            }
        }
        else {
            dismiss(animated: false)
        }
    }

    // Observe value changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) || keyPath == #keyPath(AVPlayer.status) {
            if let change = change {
                if let statusRawValue: Int = change[.newKey] as? Int {
                    if let status: AVPlayerStatus = AVPlayerStatus(rawValue: statusRawValue) {
                        handleVideoStatusChange(status)
                    }
                    else if let status: AVPlayerItemStatus = AVPlayerItemStatus(rawValue: statusRawValue) {
                        handleVideoItemStatusChange(status)
                    }
                }
            }
        }
    }

    /// Handle the player item status change
    private func handleVideoItemStatusChange(_ status: AVPlayerItemStatus) {
        switch status {
            case .failed, .unknown:
                handleVideoError()
            case .readyToPlay:
                break
        }
    }

    /// Handle the player's status change
    private func handleVideoStatusChange(_ status: AVPlayerStatus) {
        handleVideoItemStatusChange(AVPlayerItemStatus(rawValue: status.rawValue)!)
    }

    /// Set thumbnail url
    func setThumbnailUrl(_ url: String) {
        self.thumbnailUrl = url
    }

    /// Set the title used for the loading screen
    func setLoadingTitle(_ loadingTitle: String) {
        self.loadingTitle = loadingTitle
    }

    /// Set the meta data subtitle
    func setSubTitle(_ subTitle: String) {
        self.subTitle = subTitle
    }

    /// Generate metadata for video
    private func generateMetadata() -> [AVMetadataItem] {
        var metadata: Array<AVMetadataItem> = Array()
        // Title
        if let titleMeta: String = self.titleMeta {
            let title: AVMutableMetadataItem = AVMutableMetadataItem()
            title.key = NSString(string: AVMetadataKey.commonKeyTitle.rawValue)
            title.identifier = AVMetadataIdentifier.commonIdentifierTitle
            title.keySpace = .common
            title.locale = .current
            title.value = NSString(string: titleMeta)
            metadata.append(title)
        }
        // Subtitle
        if let subTitleMeta: String = self.subTitle {
            let subTitle: AVMutableMetadataItem = AVMutableMetadataItem()
            subTitle.key = NSString(string: AVMetadataKey.commonKeyDescription.rawValue)
            subTitle.identifier = AVMetadataIdentifier.commonIdentifierDescription
            subTitle.keySpace = .common
            subTitle.locale = .current
            subTitle.value = NSString(string: subTitleMeta)
            metadata.append(subTitle)
        }
        // Thumbnail
        if let thumbnailMeta: UIImage = self.thumbnail {
            let thumbnail: AVMutableMetadataItem = AVMutableMetadataItem()
            thumbnail.key = NSString(string: AVMetadataKey.commonKeyArtwork.rawValue)
            thumbnail.identifier = AVMetadataIdentifier.commonIdentifierArtwork
            thumbnail.keySpace = .common
            thumbnail.locale = .current
            thumbnail.value = NSData(data: UIImagePNGRepresentation(thumbnailMeta)!)
            metadata.append(thumbnail)
        }
        return metadata
    }

    /// Set the metadata title
    func setTitle(_ title: String) {
        self.titleMeta = title
    }

    /// Set video/stream id
    func setId(type: TwitchApi.VideoType, _ id: String) {
        self.idType = type
        self.id = id
    }

    /// Save stream
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let idType = idType {
            coder.encode(idType.rawValue, forKey: "idType")
        }
        coder.encode(id, forKey: "id")
        coder.encode(subTitle, forKey: "subTitle")
        coder.encode(titleMeta, forKey: "titleMeta")
        coder.encode(thumbnailUrl, forKey: "thumbnailUrl")
        coder.encode(loadingTitle, forKey: "loadingTitle")
    }

    /// Load stream
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        id = coder.decodeObject(forKey: "id") as? String
        subTitle = coder.decodeObject(forKey: "subTitle") as? String
        titleMeta = coder.decodeObject(forKey: "titleMeta") as? String
        thumbnailUrl = coder.decodeObject(forKey: "thumbnailUrl") as? String
        loadingTitle = coder.decodeObject(forKey: "loadingTitle") as? String
    }
}
