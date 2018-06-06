//
// Created by Rolando Islas on 6/4/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class GameCollectionCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, CallbackActionHandler {
    @IBOutlet private weak var title: UILabel?
    @IBOutlet weak var collectionView: UICollectionView?
    var callbackAction: ((Any, UIGestureRecognizer) -> Void)?
    var headerTitle: String = "" {
        didSet {
            self.title?.text = self.headerTitle
        }
    }
    var games: Array<TwitchGame> = Array()
    var indexPath: IndexPath?

    /// Determine the collection view cell count
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return games.count
    }

    /// Populate the collection view cells
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
                    -> UICollectionViewCell {
        let cell: GameCell = collectionView.dequeueReusableCell(withReuseIdentifier: "gameCell",
                for: indexPath) as! GameCell
        if let game = games[safe: indexPath.item] {
            cell.game = game
        }
        return cell
    }

    /// Do not allow the table view cell to become focused, so the collection view can
    override var canBecomeFocused: Bool {
        return false
    }

    /// Handle item pre-focus
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
        if let indexPath = context.nextFocusedIndexPath, let callback = self.callbackAction {
            if indexPath.item == games.count - 1 {
                callback(self, UISwipeGestureRecognizer())
            }
        }
        return true
    }

    /// Handle item selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell: GameCell = collectionView.cellForItem(at: indexPath) as! GameCell
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
}

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}