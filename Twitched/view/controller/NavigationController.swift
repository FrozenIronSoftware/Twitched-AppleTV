//
// Created by Rolando Islas on 5/14/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class NavigationController: UITabBarController, ResettingViewController {
    func applicationDidBecomeActive() {
        for viewController in self.childViewControllers {
            if viewController is ResettingViewController && viewController.isViewLoaded {
                let viewController: ResettingViewController = viewController as! ResettingViewController
                viewController.applicationDidBecomeActive()
            }
        }
    }
}