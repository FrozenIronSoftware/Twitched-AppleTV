//
// Created by Rolando Islas on 5/28/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class VideoCollectionCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate,
        CallbackActionHandler {
    @IBOutlet private weak var title: UILabel?
    @IBOutlet weak var collectionView: UICollectionView?

    var callbackAction: ((Any, UIGestureRecognizer) -> Void)? = nil
    var headerTitle: String = "" {
        didSet {
            self.title?.text = headerTitle
        }
    }
    var videos: Array<TwitchStream>?
    var indexPath: IndexPath?

    /// Determine the collection view cell count
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.videos != nil ? (self.videos?.count)! : 0
    }

    /// Populate the collection view cells
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
                    -> UICollectionViewCell {
        let cell: VideoOnDemandCell = collectionView.dequeueReusableCell(withReuseIdentifier: "videoCell",
                for: indexPath) as! VideoOnDemandCell
        if let video = self.videos?[indexPath.item] {
            cell.videoTitle = video.title
            cell.videoThumbnail = video.thumbnailUrl
            cell.stream = video
        }
        return cell
    }

    /// Handle collection view cell pre-focus
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
        if let videos = self.videos, let indexPath = context.nextFocusedIndexPath, let callback = self.callbackAction {
            if indexPath.item == videos.count - 1 {
                callback(self, UISwipeGestureRecognizer())
            }
        }
        return true
    }

    /// Handle item selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell: VideoOnDemandCell = collectionView.cellForItem(at: indexPath) as! VideoOnDemandCell
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            cell.getThumbnail().transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                cell.getThumbnail().transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: { _ in
                if let callback = self.callbackAction {
                    callback(cell, UITapGestureRecognizer())
                }
            })
        })
    }

    /// Do not allow the table view cell to become focused, so the collection view can
    override var canBecomeFocused: Bool {
        return false
    }

    /// Reload the collection view data
    func reloadCollection() {
        self.collectionView?.reloadData()
    }
}
