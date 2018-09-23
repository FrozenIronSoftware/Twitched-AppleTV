//
//  AppDelegate.swift
//  Twitched
//
//  Created by Rolando Islas on 4/28/18.
//  Copyright © 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        TwitchApi.initialize()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        TwitchApi.tryTimeLogIn()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    /// Determine if the application state should be saved
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"]!
        let build = Bundle.main.infoDictionary!["CFBundleVersion"]!
        coder.encode(version, forKey: "twitched_version")
        coder.encode(build, forKey: "twitched_build")
        return true
    }

    /// Determine if the application state should be restored
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"]! as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"]! as! String
        if let savedBuild: String = coder.decodeObject(forKey: "twitched_build") as? String {
            if let savedVersion: String = coder.decodeObject(forKey: "twitched_version") as? String {
                return version == savedVersion && build == savedBuild
            }
            return false
        }
        return false
    }
}
