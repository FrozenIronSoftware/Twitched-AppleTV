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

class PopularListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private let UPDATE_INTERVAL: TimeInterval = 60 * 10
    private let MAX_PAGE: Int = 10
    @IBOutlet private weak var collectionView: UICollectionView?
    @IBOutlet private weak var messageLabel: UILabel?
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView?
    private var lastUpdateTime: TimeInterval?
    private var streams: Array<TwitchStream>?
    private var page: Int?
    private var isLoading: Bool?
    private var initialHeaderBounds: CGRect?

    /// View is about to appear
    /// Check if enough time has passed that the grid needs an update
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        os_log("PopularListView will appear", type: .debug)
        if lastUpdateTime != nil && Date().timeIntervalSince1970 - lastUpdateTime! >= UPDATE_INTERVAL {
            populateCollectionViewWithReset()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                name: .UIApplicationDidBecomeActive, object: nil)
    }

    /// Disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
    }

    // Appeared
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Save initial header position
        if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                at: IndexPath(item: 0, section: 0)) {
            self.initialHeaderBounds = header.bounds
        }
    }

    /// Disappeared
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Reset header position
        if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                at: IndexPath(item: 0, section: 0)) {
            if let bounds = self.initialHeaderBounds {
                header.bounds = bounds
            }
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
        populateCollectionViewWithReset()
        // Save header location

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
        TwitchApi.getStreams(parameters: params, callback: { response in
            if let streams: Array<TwitchStream> = response {
                self.lastUpdateTime = Date().timeIntervalSince1970
                if (!append!) || self.streams == nil {
                    self.streams = streams
                    self.collectionView?.reloadData()
                }
                else {
                    let count: Int = (self.streams?.count)!
                    self.streams?.append(contentsOf: streams)
                    var indexPaths: Array<IndexPath> = Array()
                    var index: Int = count
                    while index < (self.streams?.count)! {
                        indexPaths.append(IndexPath(item: index, section: 0))
                        index += 1
                    }
                    if indexPaths.count > 0 {
                        self.collectionView?.insertItems(at: indexPaths)
                    }
                }
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
        // Move the header title if the cell focused is the first item
        if let indexPath = context.nextFocusedIndexPath {
            if let header = collectionView.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)) {
                if indexPath.section == 0 && indexPath.item == 0 {
                    UIView.animate(withDuration: 0.2, animations: {
                        header.bounds = (self.initialHeaderBounds?.offsetBy(dx: 1, dy: 20))!
                    })
                }
                else if let previousIndexPath = context.previouslyFocusedIndexPath {
                    if previousIndexPath.section == 0 && previousIndexPath.item == 0 {
                        UIView.animate(withDuration: 0.2, animations: {
                            header.bounds = self.initialHeaderBounds!
                        })
                    }
                }
            }
        }
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
        // Reset the header title if the focus is not a video cell
        else {
            if let header = self.collectionView?.supplementaryView(forElementKind: UICollectionElementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)) {
                if let bounds = self.initialHeaderBounds {
                    header.bounds = bounds
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
    @objc func applicationDidBecomeActive() {
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
    }
}
