//
//  PopularListViewController.swift
//  Twitched
//
//  Created by Rolando Islas on 4/28/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import os.log
import L10n_swift

class PopularListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
        ResettingViewController {

    private let UPDATE_INTERVAL: TimeInterval = 60 * 10
    private let MAX_PAGE: Int = 10
    private var twitchApi: TwitchApi?
    @IBOutlet private weak var collectionView: UICollectionView?
    @IBOutlet private weak var messageLabel: UILabel?
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    private var lastUpdateTime: TimeInterval?
    private var streams: Array<TwitchStream>?
    private var page: Int?
    private var isLoading: Bool?

    /// View is about to appear
    /// Check if enough time has passed that the grid needs an update
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("PopularListView will appear", type: .debug)
        if lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL {
            populateCollectionViewWithReset()
        }
    }

    /// Reset the view and populate the view
    private func populateCollectionViewWithReset() {
        page = 0
        isLoading = false
        populateCollectionView()
    }

    /// Handle the view loading
    /// Initialize
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("PopularListView loaded", type: .debug)
        twitchApi = TwitchApi()
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
        let params: Parameters = [
            "limit": 40,
            "offset": offset!
        ]
        twitchApi?.getStreams(parameters: params, callback: { response in
            if let streams: Array<TwitchStream> = response {
                self.lastUpdateTime = Date().timeIntervalSince1970
                if (!append!) || self.streams == nil {
                    self.streams = streams
                }
                else {
                    self.streams?.append(contentsOf: streams)
                }
                self.collectionView?.reloadData()
            }
            else {
                self.lastUpdateTime = 0
                if self.streams == nil || self.streams?.count == 0 {
                    self.messageLabel?.text = "message.error.api_fail".l10nf(arg: [1000])
                }
            }
            self.loadingIndicator?.stopAnimating()
            self.isLoading = false
        })
    }

    /// Handle a memory warning
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        os_log("PopularListViewController: Memory warning not handled", type: .error)
    }

    /// Define the number of cells
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return streams != nil ? (streams?.count)! : 0
    }

    /// Populate cells
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) ->
            UICollectionViewCell {
        let cell: VideoCell = collectionView.dequeueReusableCell(withReuseIdentifier: "video", for: indexPath)
                as! VideoCell
        let stream: TwitchStream = self.streams![indexPath.item]
        cell.setStream(stream)
        return cell
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
                UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                    self.view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                    self.view.alpha = 0
                }, completion: { _ in
                    if let stream: TwitchStream = cell.getStream() {
                        let streamInfoViewController: StreamInfoViewController = self.storyboard?.instantiateViewController(
                                withIdentifier: "streamInfoViewController") as! StreamInfoViewController
                        streamInfoViewController.setStream(stream)
                        self.present(streamInfoViewController, animated: true, completion: {
                            self.view.transform = CGAffineTransform(scaleX: 1, y: 1)
                            self.view.alpha = 1
                        })
                    }
                })
            })
        })
    }

    /// Handle item focused
    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator) {

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
                    page? += 1
                    populateCollectionView(offset: page, append: true)
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
        header.textLabel?.text = "title.popular".l10n()
        return header
    }


    /// Handle the application and this view resuming
    func applicationDidBecomeActive() {
        os_log("PopularListView active", type: .debug)
        // Update the items if needed
        if lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL {
            populateCollectionViewWithReset()
        }
        // Focus the active cell
        for cell in (collectionView?.visibleCells)! {
            let cell: VideoCell = cell as! VideoCell
            cell.setFocused(cell.isFocused)
        }
        // Propagate to the presented view
        if let presentedView: ResettingViewController = self.presentedViewController as? ResettingViewController {
            presentedView.applicationDidBecomeActive()
        }
    }
}
