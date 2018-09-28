//
// Created by Rolando Islas on 8/18/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import os.lock

class SearchViewController: UIViewController {

    @IBOutlet private weak var searchType: UISegmentedControl?
    private var searchViewControllerHandler: SearchViewControllerHandler = SearchViewControllerHandler()
    private var videoGrid: VideoGridViewController = VideoGridViewController()
    private var posterGrid: PosterItemsListViewController = PosterItemsListViewController()
    private var searchController: UISearchController?
    private var searchQueued: Bool = false
    private var searchQuery: String = ""

    /// Loaded
    override func viewDidLoad() {
        // Search handler
        searchViewControllerHandler = SearchViewControllerHandler()
        searchViewControllerHandler.restorationIdentifier = "searchViewControllerHandler"

        // Search controller
        searchController = UISearchController(searchResultsController: searchViewControllerHandler)
        if let searchController = searchController {
            searchController.restorationIdentifier = "searchController"
            searchController.searchResultsUpdater = searchViewControllerHandler
            searchController.hidesNavigationBarDuringPresentation = false
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = "Search"
            searchController.searchBar.frame = self.view.frame
            searchController.searchBar.searchBarStyle = .default
        }

        // Search container
        let searchContainerViewController = UISearchContainerViewController(searchController: searchController!)
        searchContainerViewController.restorationIdentifier = "searchContainerViewController"
        searchContainerViewController.view.frame = CGRect(x: self.view.frame.minX, y: self.view.frame.minY,
                width: self.view.frame.width, height: self.view.frame.height)
        searchContainerViewController.willMove(toParent: self)
        self.addChild(searchContainerViewController)
        self.view.addSubview(searchContainerViewController.view)
        searchContainerViewController.didMove(toParent: self)

        // Segment
        if let searchType = searchType {
            searchType.frame = CGRect(x: searchType.frame.minX, y: 350, width: searchType.frame.width,
                    height: searchType.frame.height)
            searchType.removeFromSuperview()
            self.view.addSubview(searchType)
        }

        // Video grid
        videoGrid = self.storyboard?.instantiateViewController(
                withIdentifier: "videoGridViewController") as! VideoGridViewController
        videoGrid.view.frame = CGRect(x: self.view.frame.minX, y: self.view.frame.minY + 440,
                width: self.view.frame.width, height: self.view.frame.height - 440)
        videoGrid.headerTitle = ""
        videoGrid.noHeader = true
        videoGrid.view.clipsToBounds = true
        videoGrid.willMove(toParent: self)
        self.addChild(videoGrid)
        self.view.addSubview(videoGrid.view)
        videoGrid.didMove(toParent: self)

        // Game grid
        posterGrid = self.storyboard?.instantiateViewController(withIdentifier: "gameListVIewController") as!
                PosterItemsListViewController
        posterGrid.view.frame = CGRect(x: self.view.frame.minX, y: self.view.frame.minY + 400,
                width: self.view.frame.width, height: self.view.frame.height - 400)
        posterGrid.noHeader = true
        posterGrid.loadFollowed = false
        posterGrid.willMove(toParent: self)
        self.addChild(posterGrid)
        self.view.addSubview(posterGrid.view)
        posterGrid.didMove(toParent: self)
        posterGrid.view.isHidden = true
    }

    /// Disappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .SearchTextUpdate, object: searchViewControllerHandler)
    }

    /// Appeared
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(searchTextUpdate),
                name: .SearchTextUpdate, object: searchViewControllerHandler)
    }

    /// Handle search text
    @objc
    func searchTextUpdate(notification: Notification) {
        if let userInfo = notification.userInfo, let query = userInfo["query"] as? String {
            search(query)
        }
    }

    private func search(_ query: String? = nil, instant: Bool = false) {
        if let query = query {
            self.searchQuery = query
        }
        else {
            if let searchController = self.searchController, let query = searchController.searchBar.text {
                self.searchQuery = query
            }
        }
        if !searchQueued {
            searchQueued = true
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(instant ? 0 : 2), execute: {
                if let searchType = self.searchType {
                    switch (searchType.selectedSegmentIndex) {
                    case 0: // Streams
                        self.videoGrid.search(self.searchQuery)
                    case 1: // Channels
                        self.videoGrid.search(self.searchQuery, channels: true)
                    case 2: // Games
                        self.posterGrid.search(self.searchQuery)
                    default:
                        os_log("SearchViewController: searchTextUpdate: Invalid search type: %d", type: .error,
                                searchType.selectedSegmentIndex)
                    }
                }
                self.videoGrid.search(self.searchQuery)
                self.searchQueued = false
            })
        }
    }

    /// Handle change
    @IBAction func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch (sender.selectedSegmentIndex) {
        case 0, 1: // Streams / Channels
            videoGrid.view.isHidden = false
            posterGrid.view.isHidden = true
            search(instant: true)
        case 2: // Games
            posterGrid.view.isHidden = false
            videoGrid.view.isHidden = true
            search(instant: true)
        default:
            os_log("SearchViewController: segmentedControlValueChanged: Invalid search type: %d", type: .error,
                    sender.selectedSegmentIndex)
        }
    }
}
