//
// Created by Rolando Islas on 4/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import os.log
import CloudKit

class TwitchApi {

    private static var API_HELIX: String = ""
    private static var API_KRAKEN: String = ""
    private static var API: String = ""
    private static var API_RAW: String = "https://api.twitch.tv/api"
    private static var API_USHER: String = "https://usher.ttvnw.net"
    private static var CLIENT_ID: String = ""
    private static var CLIENT_ID_TWITCH: String = ""
    private static let GAME_THUMBNAIL_URL: String = "https://static-cdn.jtvnw.net/ttv-boxart/%@-%@x%@.jpg"
    private static let ACCESS_TOKEN_KEY: String = "auth.access_token"
    private static let LOGIN_INTERVAL: TimeInterval = 60 * 60 // One hour
    private static var isLoggedIn: Bool {
        get {
            return TwitchApi.tokenValidation != nil && TwitchApi.accessToken != nil
        }
    }
    public static var accessToken: TwitchAccessToken?
    public static var userLogin: String? {
        get {
            if let tokenValidation = TwitchApi.tokenValidation {
                return tokenValidation.login
            }
            else {
                return nil
            }
        }
    }
    private static var tokenValidation: TwitchTokenValidation?
    public static var userId: String {
        get {
            if let tokenValidation: TwitchTokenValidation = TwitchApi.tokenValidation {
                return tokenValidation.userId
            }
            else {
                return ""
            }
        }
    }
    private static var lastLoginTime: TimeInterval = 0
    private static var isLoggingIn = false
    public static var chatBadges: TwitchBadges?

    /// Static only class
    private init() {}

    /// Request a link ID from the API
    static func requestLinkCode(callback: @escaping (TwitchedLinkId?) -> Void) {
        let url: String = API + "/link"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "type": "ATV",
            "id": UIDevice.current.identifierForVendor?.uuidString as Any
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: TwitchedLinkId = try JSONDecoder().decode(TwitchedLinkId.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Log out
    static func logOut() {
        DispatchQueue.global().async(qos: .background) {
            while isLoggingIn {}
            let cloud = NSUbiquitousKeyValueStore.default
            cloud.removeObject(forKey: TwitchApi.ACCESS_TOKEN_KEY)
            self.tokenValidation = nil
            self.accessToken = nil
            self.lastLoginTime = 0
            PosterItemsListViewController.needsCommunityUpdate = true
            PosterItemsListViewController.needsGameUpdate = true
            VideoGridViewController.needsFollowsUpdate = true
        }
    }

    /// Check the last login time and verify the token
    static func tryTimeLogIn(callback: @escaping (Bool) -> Void = {_ in}) {
        if (!isLoggedIn) || Date().timeIntervalSince1970 - lastLoginTime >= LOGIN_INTERVAL {
            log_in(invalidate: false, callback: callback)
        }
        else {
            callback(false)
        }
    }

    /// Request the link status
    static func getLinkStatus(callback: @escaping (LinkStatus) -> Void) {
        let url: String = API + "/link/status"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "type": "ATV",
            "id": UIDevice.current.identifierForVendor?.uuidString as Any
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: TwitchAccessToken = try JSONDecoder().decode(TwitchAccessToken.self,
                            from: response.result.value!)
                    if let error = data.error, let _: Int = error.value as? Int {
                        callback(.TIMEOUT)
                    }
                    else if let complete: Bool = data.complete {
                        if complete {
                            if data.scope != nil && data.accessToken != nil && data.refreshToken != nil &&
                                       data.expiresIn != nil {
                                os_log("Saved access token", type: .debug)
                                TwitchApi.accessToken = data
                                self.saveAccessToken()
                                self.log_in()
                                callback(.SUCCESS)
                            }
                            else {
                                callback(.FAILURE)
                            }
                        }
                        else {
                            callback(.WAITING)
                        }
                    }
                    else {
                        callback(.FAILURE)
                    }
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(.FAILURE)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(.FAILURE)
            }
        }
    }

    /// Request a users followed communities
    static func getFollowedCommunities(parameters: Parameters, callback: @escaping (Array<TwitchCommunity>?) -> Void) {
        let url: String = API + "/communities/follows"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchCommunity> = try JSONDecoder().decode(Array<TwitchCommunity>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Get the streams a user follows
    static func getFollowedStreams(parameters: Parameters, callback: @escaping (Array<TwitchStream>?) -> Void) {
        let url: String = API_HELIX + "/users/follows/streams"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchStream> = try JSONDecoder().decode(Array<TwitchStream>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Initialize the Twitch API
    /// Loads the config from secret.json and attempts to login
    static func initialize() {
        os_log("TwitchApi initialized", type: .debug)
        // Read client configuration
        if let configFile: String = Bundle.main.path(forResource: "secret", ofType: "json") {
            do {
                let configString: String = try String(contentsOfFile: configFile)
                let config: Dictionary<String, Any> = try JSONSerialization.jsonObject(with: configString.data(using: .utf8)!)
                        as! Dictionary<String, Any>
                CLIENT_ID = config["client_id"] as! String
                CLIENT_ID_TWITCH = config["client_id_twitch"] as! String
                API_HELIX = config["api_helix"] as! String
                API_KRAKEN = config["api_kraken"] as! String
                API = config["api"] as! String
            } catch {
                os_log("Failed to open secret.json for reading", type: .fault)
                exit(EXIT_FAILURE)
            }
        }
        else {
            os_log("Failed to find secret.json", type: .fault)
            exit(EXIT_FAILURE)
        }
        // Read stored credentials
        if !isLoggedIn {
            log_in()
        }
        // Get badge data
        getBadges()
    }

    /// Perform a search
    static func search(parameters: Parameters, callback: @escaping (Array<TwitchStream>?) -> Void = { _ in },
                       callbackGame: @escaping (Array<TwitchGame>?) -> Void = { _ in }, games: Bool = false) {
        // Request
        let url: String = API_KRAKEN + "/search"
        os_log("Get request to %{public}@", url)
        var params = parameters
        if games {
            params["type"] = "games"
        }
        request(url, parameters: params, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    if !games {
                        let data: Array<TwitchStream> = try JSONDecoder().decode(Array<TwitchStream>.self,
                                from: response.result.value!)
                        callback(data)
                    }
                    else {
                        let data: Array<TwitchGame> = try JSONDecoder().decode(Array<TwitchGame>.self,
                                from: response.result.value!)
                        callbackGame(data)
                    }
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    if games {
                        callbackGame(nil)
                    }
                    else {
                        callback(nil)
                    }
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                if let errorData = response.data {
                    print(String(data: errorData, encoding: .utf8) as Any)
                }
                if games {
                    callbackGame(nil)
                }
                else {
                    callback(nil)
                }
            }
        }
    }

    /// Perform a search for a game
    static func searchGames(parameters: Parameters, callback: @escaping (Array<TwitchGame>?) -> Void) {

    }

    /// Get global twitch badges
    private static func getBadges() {
        let url: String = "https://badges.twitch.tv/v1/badges/global/display"
        request(url, headers: ["User-Agent": generateUserAgent()]).validate().responseData { response in
            switch response.result {
                case .success:
                    do {
                        let data: TwitchBadges = try JSONDecoder().decode(TwitchBadges.self,
                                from: response.result.value!)
                        TwitchApi.chatBadges = data
                    }
                    catch {
                        os_log("Failed to parse Twitch badges JSON", type: .debug)
                        print(error)
                    }
                case .failure:
                    os_log("Failed to fetch Twitch badges", type: .debug)
            }
        }
    }

    /// Attempts to log in using stored credentials
    /// @param invalid Bool Should the
    private static func log_in(invalidate: Bool = true, callback: @escaping (Bool) -> Void = {_ in}) {
        os_log("Attempting to log in", type: .debug)
        if self.isLoggingIn {
            callback(false)
            return
        }
        self.isLoggingIn = true
        let cloud = NSUbiquitousKeyValueStore.default
        let doCallback: (Bool) -> Void = { status in
            self.isLoggingIn = false
            if status {
                self.lastLoginTime = Date().timeIntervalSince1970
                PosterItemsListViewController.needsCommunityUpdate = true
                PosterItemsListViewController.needsGameUpdate = true
                VideoGridViewController.needsFollowsUpdate = true
            }
            callback(status)
        }
        if invalidate {
            TwitchApi.accessToken = nil
            TwitchApi.tokenValidation = nil
        }
        if let accessTokenData: Data = cloud.data(forKey: TwitchApi.ACCESS_TOKEN_KEY) {
            do {
                let accessToken = try JSONDecoder().decode(TwitchAccessToken.self, from: accessTokenData)
                os_log("Loaded token from iCloud KVS", type: .debug)
                TwitchApi.accessToken = accessToken
                self.validateToken(callback: { response in
                    // Token was valid
                    if let tokenValidation: TwitchTokenValidation = response {
                        os_log("Token validated. Logged in", type: .debug)
                        TwitchApi.tokenValidation = tokenValidation
                        doCallback(true)
                    }
                    // Token was invalid. Attempt to refresh
                    else {
                        if let refreshToken: String = TwitchApi.accessToken?.refreshToken {
                            if let scope: String = TwitchApi.accessToken?.scope {
                                os_log("Attempting token refresh", type: .debug)
                                self.refreshToken(parameters: [
                                    "refresh_token": refreshToken,
                                    "scope": scope
                                ], callback: { response in
                                    if let accessToken: TwitchAccessToken = response {
                                        os_log("Refreshed token", type: .debug)
                                        TwitchApi.accessToken = accessToken
                                        self.saveAccessToken()
                                        self.validateToken(callback: { response in
                                            if let tokenValidation: TwitchTokenValidation = response {
                                                TwitchApi.tokenValidation = tokenValidation
                                                doCallback(true)
                                            }
                                            else {
                                                os_log("Refresh token failed validation", type: .debug)
                                                doCallback(false)
                                            }
                                        })
                                    }
                                    else {
                                        os_log("Failed to refresh token", type: .debug)
                                        doCallback(false)
                                    }
                                })
                            }
                            else {
                                os_log("No scope. Not refreshing", type: .debug)
                                doCallback(false)
                            }
                        }
                        else {
                            os_log("No refresh token. Not refreshing", type: .debug)
                            doCallback(false)
                        }
                    }
                })
            }
            catch {
                os_log("Failed to parse saved access token JSON data", type: .debug)
                doCallback(false)
            }
        }
        else {
            os_log("Access token not read from iCloud KVS", type: .debug)
            doCallback(false)
        }
    }

    /// Request videos
    class func getVideos(parameters: Parameters, callback: @escaping (Array<TwitchStream>?) -> Void) {
        let url: String = API_HELIX + "/videos"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchStream> = try JSONDecoder().decode(Array<TwitchStream>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Save access token
    private static func saveAccessToken() {
        if let accessToken = TwitchApi.accessToken {
            let cloud = NSUbiquitousKeyValueStore.default
            do {
                let accessTokenJson: Data = try JSONEncoder().encode(accessToken)
                cloud.set(accessTokenJson, forKey: TwitchApi.ACCESS_TOKEN_KEY)
                os_log("Saved access token", type: .debug)
            }
            catch {
                os_log("Failed to save access token", type: .debug)
            }
        }
    }

    /// Call the token refresh endpoint
    private static func refreshToken(parameters: Parameters, callback: @escaping (TwitchAccessToken?) -> Void) {
        let url: String = TwitchApi.API + "/link/refresh"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: TwitchAccessToken = try JSONDecoder().decode(TwitchAccessToken.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    if let errorData = response.data {
                        print(String(data: errorData, encoding: .utf8) as Any)
                    }
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Wait for a login process to finish if it is in progress
    static func afterLogin(callback: @escaping (Bool) -> Void) {
        tryTimeLogIn()
        DispatchQueue.global(qos: .background).async(execute: {
            while TwitchApi.isLoggingIn {}
            callback(TwitchApi.isLoggedIn)
        })
    }

    /// Call the token validation endpoint
    private static func validateToken(callback: @escaping (TwitchTokenValidation?) -> Void) {
        let url: String = API + "/link/validate"
        os_log("Get request to %{public}@", url)
        request(url, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchTokenValidation> = try JSONDecoder().decode(Array<TwitchTokenValidation>.self,
                            from: response.result.value!)
                    if data.count == 1 {
                        callback(data[0])
                    }
                    else {
                        callback(nil)
                    }
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Unfollow a community
    static func unfollowCommunity(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API + "/communities/unfollow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Follow a community
    static func followCommunity(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API + "/communities/follow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Unfollow a game
    class func unfollowGame(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API + "/twitch/games/unfollow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Follow a game
    class func followGame(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API + "/twitch/games/follow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Check if a user follows a game
    class func getFollowedGame(parameters: Parameters, callback: @escaping (Bool) -> Void) {
        let url: String = API + "/twitch/games/following"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: TwitchGameFollowStatus = try JSONDecoder().decode(TwitchGameFollowStatus.self,
                            from: response.result.value!)
                    if data.status {
                        callback(true)
                    }
                    else {
                        callback(false)
                    }
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(false)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Send a request to follow a user
    static func followUser(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API_KRAKEN + "/users/follows/follow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Get HLS url for a stream
    static func getHlsUrl(type: VideoType, id: String, callback: @escaping (String, Bool) -> Void) -> Void {
        let cloud = NSUbiquitousKeyValueStore.default
        let qualityArray = cloud.array(forKey: SettingsViewController.TWITCH_QUALITY_KEY)
        var quality = "1080p"
        if let qualityArray: Array<String> = qualityArray as? Array<String> {
            if qualityArray.count > 0 && qualityArray[0] != "auto" {
                quality = qualityArray[0]
            }
        }
        getTwitchPlaylistUrl(type: type, quality: quality, id: id) { localPlaylist in
            if let localPlaylist = localPlaylist {
                callback(localPlaylist, true)
                return
            }
            switch type {
            case .STREAM:
                callback(String(format: "%@/twitch/hls/60/%@/ATV/%@.m3u8", arguments: [API, quality, id]), false)
            case .VIDEO:
                callback(String(format: "%@/twitch/vod/60/%@/ATV/%@.m3u8", arguments: [API, quality, id]), false)
            }
        }
    }

    /// Unfollow a user
    class func unfollowUser(id: String, callback: @escaping (Bool) -> Void) {
        let url: String = API_KRAKEN + "/users/follows/unfollow"
        os_log("Get request to %{public}@", url)
        request(url, parameters: [
            "id": id
        ], headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                callback(true)
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(false)
            }
        }
    }

    /// Call the follows endpoint
    static func getFollows(parameters: Parameters, callback: @escaping (Array<TwitchUserFollow>?) -> Void) {
        let url: String = API_HELIX + "/users/follows"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchUserFollow> = try JSONDecoder().decode(Array<TwitchUserFollow>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Get a game thumbnail url
    static func getGameThumbnailUrl(gameName: String, width: Int, height: Int) -> String {
        return String(format: GAME_THUMBNAIL_URL, gameName, width.description, height.description)
    }

    /// Request stream data from the API
    static func getStreams(parameters: Parameters, callback: @escaping (Array<TwitchStream>?) -> Void) {
        // Add lang data
        var params = parameters
        params.updateValue(getEnabledLanguages(), forKey: "language")
        // Request
        let url: String = API_HELIX + "/streams"
        os_log("Get request to %{public}@", url)
        request(url, parameters: params, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchStream> = try JSONDecoder().decode(Array<TwitchStream>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Returns a list of enabled languages
    private class func getEnabledLanguages() -> Array<String> {
        let cloud = NSUbiquitousKeyValueStore.default
        let langs = cloud.array(forKey: SettingsViewController.TWITCH_LANG_KEY)
        if let langs: Array<String> = langs as? Array<String> {
            if langs.contains("all") {
                return Array()
            }
            return langs
        }
        return Array()
    }

    /// Generate headers with Twitched client ID and Twitch user OAuth token (if the token is available)
    static func generateHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Client-ID": CLIENT_ID,
            "X-Twitched-Version": Constants.VERSION,
            "User-Agent": generateUserAgent()
        ]
        if let accessToken: TwitchAccessToken = TwitchApi.accessToken {
            if let accessTokenString: String = accessToken.accessToken {
                headers["Twitch-Token"] = accessTokenString
            }
        }
        return headers
    }

    /// Return the Twitched user agent string
    private static func generateUserAgent() -> String {
        return String(format: "TwitchedAppleTV/%@ (Swift)", Constants.VERSION)
    }

    /// Request users from the API
    static func getUsers(parameters: Parameters, callback: @escaping (Array<TwitchUser>?) -> Void) {
        let url: String = API_HELIX + "/users"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchUser> = try JSONDecoder().decode(Array<TwitchUser>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Request the top games
    static func getTopGames(parameters: Parameters, callback: @escaping (Array<TwitchGame>?) -> Void) {
        let url: String = API_HELIX + "/games/top"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchGame> = try JSONDecoder().decode(Array<TwitchGame>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Request the top games
    static func getFollowedGames(parameters: Parameters, callback: @escaping (Array<TwitchGame>?) -> Void) {
        let url: String = API + "/twitch/games/follows"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchGame> = try JSONDecoder().decode(Array<TwitchGame>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Load top communities
    static func getTopCommunities(parameters: Parameters, callback: @escaping (Array<TwitchCommunity>?) -> Void) {
        var parameters = parameters;
        parameters["array"] = "true";
        let url: String = API_KRAKEN + "/communities/top"
        os_log("Get request to %{public}@", url)
        request(url, parameters: parameters, headers: generateHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let data: Array<TwitchCommunity> = try JSONDecoder().decode(
                            Array<TwitchCommunity>.self,
                            from: response.result.value!)
                    callback(data)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@",
                            url,
                            response.result.value.debugDescription)
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Fetch a video access token for the current user if they are logged in.
    /// @param type video type
    /// @param id streamer username or video id
    /// @param completion video access token or nil on error
    private static func getVideoAccessToken(type: TwitchApi.VideoType, id: String, completion:
            @escaping (TwitchVideoAccessToken?) -> Void) -> Void {
        var url: String
        switch type {
        case .STREAM:
            url = String(format: "%@/channels/%@/access_token", arguments: [API_RAW, id])
        case .VIDEO:
            url = String(format: "%@/vods/%@/access_token", arguments: [API_RAW, id])
        }
        request(url, headers: generateTwitchHeaders()).validate().responseData { response in
            switch response.result {
            case .success:
                do {
                    let token: TwitchVideoAccessToken = try JSONDecoder().decode(TwitchVideoAccessToken.self,
                            from: response.result.value!)
                    completion(token)
                }
                catch {
                    os_log("Failed to parse JSON from %{public}@: %{public}@", url,
                            response.result.value.debugDescription)
                    completion(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                completion(nil)
            }
        }
    }

    /// Generate headers for communicating with Twitch directly
    static func generateTwitchHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Client-ID": CLIENT_ID_TWITCH,
            "User-Agent": generateUserAgent()
        ]
        if let accessToken: TwitchAccessToken = TwitchApi.accessToken {
            if let accessTokenString: String = accessToken.accessToken {
                headers["Authorization"] = "OAuth " + accessTokenString
            }
        }
        return headers
    }

    /// Get a raw M3U8 playlist url for Twitch
    private static func getHlsPlaylistUrl(type: TwitchApi.VideoType, id: String, token: TwitchVideoAccessToken) -> String? {
        var url: String
        switch type {
        case .STREAM:
            url = String(format: "%@/api/channel/hls/%@.m3u8", arguments: [API_USHER, id])
        case .VIDEO:
            url = String(format: "%@/vod/%@.m3u8", arguments: [API_USHER, id])
        }
        var params = HTTPHeaders()
        params["player"] = "Twitched"
        params["p"] = String(Int(arc4random_uniform(UInt32.max)))
        params["type"] = "any"
        params["allow_audio_only"] = "true"
        params["allow_source"] = "true"
        switch type {
        case .STREAM:
            params["token"] = token.token
            params["sig"] = token.sig
        case .VIDEO:
            params["nauth"] = token.token
            params["nauthsig"] = token.sig
        }
        var queryItems = Array<URLQueryItem>()
        for param in params.keys {
            queryItems.append(URLQueryItem(name: param, value: params[param]))
        }
        let urlComponents = NSURLComponents(string: url)
        if let urlComponents = urlComponents {
            urlComponents.queryItems = queryItems
            if let urlConstructed = urlComponents.url {
                return urlConstructed.absoluteString
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }

    /// Attempts to download a Twitch playlist and adds it to a local server
    /// @param completion m3u8 url or nil on error
    private static func getTwitchPlaylistUrl(type: TwitchApi.VideoType, quality: String, id: String,
                              completion: @escaping (String?) -> Void) -> Void {
        TwitchApi.getVideoAccessToken(type: type, id: id) { token in
            if let token = token {
                let playlistUrl = TwitchApi.getHlsPlaylistUrl(type: type, id: id, token: token)
                completion(playlistUrl)
            }
            else {
                completion(nil)
            }
        }
    }

    /// Video type enum
    enum VideoType: Int {
        case STREAM, VIDEO
    }

    /// Link status types
    enum LinkStatus: Int {
        case SUCCESS, FAILURE, TIMEOUT, WAITING
    }
}
