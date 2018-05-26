//
// Created by Rolando Islas on 5/20/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import os.log

class VideoViewController: UIViewController, AVPlayerViewControllerDelegate, ResettingViewController {

    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet private weak var titleLabel: UILabel?
    private var twitchApi: TwitchApi?
    private var idType: TwitchApi.VideoType?
    private var id: String?
    private var titleMeta: String?
    private var subTitle: String?
    private var loadingTitle: String?
    private var thumbnail: UIImage?
    private var thumbnailUrl: String?

    /// Loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        self.twitchApi = TwitchApi()
        self.titleLabel?.text = loadingTitle
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
                    twitchApi?.getStreams(parameters: [
                        "user_id": id
                    ], callback: { response in
                        if let streams: Array<TwitchStream> = response {
                            if streams.count == 1 {
                                let stream: TwitchStream = streams[0]
                                if stream.online {
                                    let hlsUrl: String = (self.twitchApi?.getHlsUrl(type: .STREAM, id: stream.userId))!
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
                    print("todo")
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
            "AVURLAssetHTTPHeaderFieldsKey": twitchApi?.generateHeaders() as Any
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
        player.play()
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

    /// Activated
    func applicationDidBecomeActive() {
        os_log("VideoViewController active", type: .debug)
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
}
