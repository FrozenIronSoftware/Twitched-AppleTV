//
//  VideoCell.swift
//  Twitched
//
//  Created by Rolando Islas on 5/3/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import L10n_swift
import Alamofire

class VideoCell: UICollectionViewCell {

    @IBOutlet private weak var thumbnail: UIImageView?
    @IBOutlet private weak var titleLabel: MarqueeLabel?
    @IBOutlet private weak var descriptionLabel: UILabel?
    private var requests: Array<DataRequest> = Array()
    private var uuid: UUID?
    private var stream: TwitchStream?

    /// Reset
    override func prepareForReuse() {
        super.prepareForReuse()
        uuid = UUID()
        for request in requests {
            request.cancel()
        }
        requests.removeAll(keepingCapacity: false)
        thumbnail?.image = UIImage(named: Constants.IMAGE_LOADING_VIDEO_THUMBNAIL)
        titleLabel?.text = ""
        descriptionLabel?.text = ""
    }

    /// Handle focus
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        setFocused(super.isFocused)
    }

    /// Set the stream that this cell represents
    func setStream(_ stream: TwitchStream, gameThumbnail: Bool = true) {
        self.stream = stream
        titleLabel?.text = stream.title
        let isUser: Bool = stream.type == "user" || stream.type == "user_follow"
        if isUser {
            if let userName = stream.userName {
                descriptionLabel?.text = userName.displayName
            }
        }
        else {
            descriptionLabel?.text = String(format: "%@ %@ %@ %@",
                    stream.viewerCount.l10n(),
                    "inline.viewers".l10n(arg: stream.viewerCount),
                    "inline.on".l10n(),
                    stream.userName != nil ? (stream.userName?.displayName)! : "")
        }
        setThumbnail(stream.thumbnailUrl, stream.gameName != nil ? stream.gameName! : "",
                Int((self.thumbnail?.bounds.width)!),
                Int((self.thumbnail?.bounds.height)!),
                loadGame: gameThumbnail && !isUser)
    }

    /// Set the background thumbnail with the game cover layered on top
    private func setThumbnail(_ url: String, _ gameName: String, _ width: Int, _ height: Int, loadGame: Bool = true) {
        let url = url.replacingOccurrences(of: "{width}", with: width.description)
                .replacingOccurrences(of: "{height}", with: height.description)
        let gameThumbnailUrl: String = TwitchApi.getGameThumbnailUrl(gameName: gameName,
                width: Int(Double(height) * 0.8 * (5 / 7)),
                height: Int(Double(height) * 0.8))
        let mainThumbRequest: DataRequest = request(url)
        let gameThumbRequest: DataRequest = request(gameThumbnailUrl
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        requests.append(mainThumbRequest)
        requests.append(gameThumbRequest)
        let uuid = self.uuid
        mainThumbRequest.responseData { response in
            if let thumbData = response.result.value {
                if loadGame {
                    gameThumbRequest.responseData { response in
                        if let gameThumbData = response.result.value {
                            let expandedGameImage: UIImage = ImageUtil.expandImageCanvas(image: UIImage(data: gameThumbData)!,
                                    alignHoriz: ImageUtil.Alignment.RIGHT,
                                    alignVert: ImageUtil.Alignment.BOTTOM,
                                    size: CGSize(width: width, height: height))
                            let thumbImage = UIImage(data: thumbData)!
                            UIGraphicsBeginImageContextWithOptions(thumbImage.size, false, 0.0)
                            thumbImage.draw(in: CGRect(x: 0, y: 0, width: thumbImage.size.width,
                                    height: thumbImage.size.height))
                            expandedGameImage.draw(in: CGRect(x: 0, y: 0, width: thumbImage.size.width,
                                    height: thumbImage.size.height))
                            let combined = UIGraphicsGetImageFromCurrentImageContext()!
                            UIGraphicsEndImageContext()
                            self.thumbnail?.image = combined
                        }
                        else {
                            self.thumbnail?.image = UIImage(data: thumbData)
                        }
                    }
                }
                else {
                    self.thumbnail?.image = UIImage(data: thumbData)
                }
            }
            else if uuid == self.uuid {
                self.thumbnail?.image = UIImage(named: Constants.IMAGE_ERROR_VIDEO_THUMBNAIL)
            }
        }
    }

    /// Change the cell state based on if it is focused or not
    func setFocused(_ isFocused: Bool) {
        if isFocused {
            titleLabel?.textColor = UIColor.white
            titleLabel?.labelize = false
            titleLabel?.restartLabel()
        }
        else {
            if traitCollection.userInterfaceStyle == UIUserInterfaceStyle.light {
                titleLabel?.textColor = UIColor.black
            }
            titleLabel?.labelize = true
            titleLabel?.restartLabel()
        }
    }

    /// Getter for stream
    func getStream() -> TwitchStream? {
        return self.stream
    }

    /// Getter for thumbnail
    func getThumbnail() -> UIImageView? {
        return thumbnail
    }
}
