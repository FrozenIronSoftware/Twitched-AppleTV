//
// Created by Rolando Islas on 4/29/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import os.log
import CloudKit

class TwitchApi {

    private let API_HELIX: String
    private let API_KRAKEN: String
    private let API: String
    private let CLIENT_ID: String
    private static let GAME_THUMBNAIL_URL: String = "https://static-cdn.jtvnw.net/ttv-boxart/%@-%@x%@.jpg"
    private static let ACCESS_TOKEN_KEY: String = "auth.access_token"
    var isLoggedIn: Bool {
        get {
            return TwitchApi.tokenValidation != nil && TwitchApi.accessToken != nil
        }
    }
    private static var accessToken: TwitchAccessToken?
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

    /// Request a link ID from the API
    func requestLinkCode(callback: @escaping (TwitchedLinkId?) -> Void) {
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

    /// Request the link status
    func getLinkStatus(callback: @escaping (LinkStatus) -> Void) {
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
                    if let _: Int = data.error {
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

    /// Initialize the Twitch API
    /// Loads the config from secret.json
    init() {
        os_log("TwitchApi initialized", type: .debug)
        // Read client configuration
        if let configFile: String = Bundle.main.path(forResource: "secret", ofType: "json") {
            do {
                let configString: String = try String(contentsOfFile: configFile)
                let config: Dictionary<String, Any> = try JSONSerialization.jsonObject(with: configString.data(using: .utf8)!)
                        as! Dictionary<String, Any>
                CLIENT_ID = config["client_id"] as! String
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
        log_in()
    }

    /// Attempts to log in using stored credentials
    private func log_in() {
        os_log("Attempting to log in", type: .debug)
        let cloud = NSUbiquitousKeyValueStore.default
        TwitchApi.accessToken = nil
        TwitchApi.tokenValidation = nil
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
                                            }
                                        })
                                    } else {
                                        os_log("Failed to refresh token", type: .debug)
                                    }
                                })
                            }
                        }
                    }
                })
            }
            catch {
                os_log("Failed to parse saved access token JSON data", type: .debug)
            }
        }
        else {
            os_log("Access token not read from iCloud KVS", type: .debug)
        }
    }

    /// Save access token
    private func saveAccessToken() {
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
    private func refreshToken(parameters: Parameters, callback: @escaping (TwitchAccessToken?) -> Void) {
        let url: String = API + "/link/refresh"
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
                    callback(nil)
                }
            case .failure:
                os_log("Failed to get %{public}@: %{public}@", url, response.error.debugDescription)
                callback(nil)
            }
        }
    }

    /// Call the token validation endpoint
    private func validateToken(callback: @escaping (TwitchTokenValidation?) -> Void) {
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

    /// Send a request to follow a user
    func followUser(id: String, callback: @escaping (Bool) -> Void) {
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
    func getHlsUrl(type: VideoType, id: String) -> String {
        switch type {
            case .STREAM:
                return String(format: "%@/twitch/hls/60/1080p/ATV/:%@.m3u8", arguments: [API, id])
            case .VIDEO:
                return String(format: "%@/twitch/vod/60/1080p/ATV/%@.m3u8", arguments: [API, id])
        }
    }

    /// Call the follows endpoint
    func getFollows(parameters: Parameters, callback: @escaping (Array<TwitchUserFollow>?) -> Void) {
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
    func getStreams(parameters: Parameters, callback: @escaping (Array<TwitchStream>?) -> Void) {
        let url: String = API_HELIX + "/streams"
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

    /// Generate headers with Twitched client ID and Twitch user OAuth token (if the token is available)
    func generateHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Client-ID": CLIENT_ID,
            "X-Twitched-Version": Constants.VERSION
        ]
        if let accessToken: TwitchAccessToken = TwitchApi.accessToken {
            if let accessTokenString: String = accessToken.accessToken {
                headers["Twitch-Token"] = accessTokenString
            }
        }
        return headers
    }

    /// Request users from the API
    func getUsers(parameters: Parameters, callback: @escaping (Array<TwitchUser>?) -> Void) {
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

    /// Video type enum
    enum VideoType: Int {
        case STREAM, VIDEO
    }

    /// Link status types
    enum LinkStatus: Int {
        case SUCCESS, FAILURE, TIMEOUT, WAITING
    }
}
