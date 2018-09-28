//
// Created by Rolando Islas on 6/4/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage

class PosterItemCell: UICollectionViewCell {
    @IBOutlet private weak var title: MarqueeLabel?
    @IBOutlet private weak var thumbnail: UIImageView?
    private var thumbnailRequest: RequestReceipt?
    var item: Any? {
        didSet {
            if let game: TwitchGame = item as? TwitchGame {
                self.title?.text = game.name
                self.thumbnailRequest = self.thumbnail?.setUrl(game.boxArtUrl
                        .replacingOccurrences(of: "{width}", with: String(Int((self.thumbnail?.bounds.width)!)))
                        .replacingOccurrences(of: "{height}", with: String(Int((self.thumbnail?.bounds.height)!))),
                        errorImageName: Constants.IMAGE_ERROR_GAME_THUMBNAIL)
            }
            else if let community: TwitchCommunity = item as? TwitchCommunity {
                self.title?.text = community.safeName
                self.thumbnailRequest = self.thumbnail?.setUrl(community.avatarImageUrl
                        .replacingOccurrences(of: "{width}", with: String(Int((self.thumbnail?.bounds.width)!)))
                        .replacingOccurrences(of: "{height}", with: String(Int((self.thumbnail?.bounds.height)!))),
                        errorImageName: Constants.IMAGE_ERROR_GAME_THUMBNAIL)
            }
        }
    }

    /// Reset
    override func prepareForReuse() {
        super.prepareForReuse()
        if let thumbnailRequest = thumbnailRequest {
            ImageUtil.imageDownloader.cancelRequest(with: thumbnailRequest)
        }
        thumbnailRequest = nil
        thumbnail?.image = UIImage(named: Constants.IMAGE_LOADING_GAME_THUMBNAIL)
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

    /// Getter for thumbnail
    func getThumbnail() -> UIImageView {
        return thumbnail!
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
}
