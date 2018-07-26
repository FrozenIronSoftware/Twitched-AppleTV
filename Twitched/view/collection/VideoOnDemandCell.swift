//
// Created by Rolando Islas on 5/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage

class VideoOnDemandCell: UICollectionViewCell {
    @IBOutlet private weak var title: MarqueeLabel?
    @IBOutlet private weak var thumbnail: UIImageView?
    var videoTitle: String = "" {
        didSet {
            self.title?.text = self.videoTitle
        }
    }
    var thumbnailRequest: RequestReceipt?
    var videoThumbnail: String = "" {
        didSet {
            let height: Int = Int((self.thumbnail?.bounds.width)!)
            let width: Int = Int(height * 16 / 9)
            thumbnailRequest = self.thumbnail?.setUrl(
                    self.videoThumbnail.replacingOccurrences(of: "{width}", with: String(width))
                    .replacingOccurrences(of: "{height}", with: String(height)),
                    errorImageName: Constants.IMAGE_ERROR_VIDEO_THUMBNAIL)
        }
    }
    var stream: TwitchStream?

    /// Reset
    override func prepareForReuse() {
        super.prepareForReuse()
        if let thumbnailRequest = thumbnailRequest {
            thumbnailRequest.request.cancel()
        }
        thumbnailRequest = nil
        thumbnail?.image = UIImage(named: Constants.IMAGE_LOADING_VIDEO_THUMBNAIL)
        title?.text = ""
    }

    /// Initialize
    override func awakeFromNib() {
        super.awakeFromNib()
        // Listen for application becoming active
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Handle application becoming active
    @objc func applicationDidBecomeActive() {
        setFocused(self.isFocused)
    }

    /// Deinit
    override func removeFromSuperview() {
        super.removeFromSuperview()
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Handle focus
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        setFocused(super.isFocused)
    }

    /// Change the cell state based on if it is focused or not
    func setFocused(_ isFocused: Bool) {
        if isFocused {
            title?.textColor = UIColor.white
            title?.labelize = false
            title?.restartLabel()
        }
        else {
            if traitCollection.userInterfaceStyle == UIUserInterfaceStyle.light {
                title?.textColor = UIColor.black
            }
            title?.labelize = true
            title?.restartLabel()
        }
    }

    /// Thumbnail getter
    func getThumbnail() -> UIImageView {
        return thumbnail!
    }
}
