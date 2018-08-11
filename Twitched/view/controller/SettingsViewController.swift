//
// Created by Rolando Islas on 7/26/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import L10n_swift
import os.log

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    public static let TWITCH_LANG_KEY: String = "twitch_langs"
    public static let TWITCH_QUALITY_KEY: String = "twitch_quality"
    @IBOutlet private weak var settingTableView: UITableView?
    private var mainSettings: Array<String> = ["title.stream_language", "title.stream_quality", "title.log_in",
                                               "title.about"]
    private var langDetail: String = ""
    private var qualityDetail: String = ""
    private var langSelections: Array<ListViewSelection> = Array()
    private var qualitySelections: Array<ListViewSelection> = Array()

    /// Init
    override func viewDidAppear(_ animated: Bool) {
        loadLangValues()
        loadQualityValues()
        updateLoginState()
        setDetails()
    }

    /// Load quality values
    private func loadQualityValues() {
        var selections: Array<ListViewSelection> = Array()
        selections.append(ListViewSelection(name: "Automatic", data: "auto"))
        selections.append(ListViewSelection(name: "1080p", data: "1080p"))
        selections.append(ListViewSelection(name: "720p", data: "720p"))
        selections.append(ListViewSelection(name: "480p", data: "480p"))
        selections.append(ListViewSelection(name: "240p", data: "240p"))
        self.qualitySelections = selections
    }

    /// Load language values
    private func loadLangValues() {
        if let twitchLangPath = Bundle.main.path(forResource: "twitch_lang", ofType: "json") {
            do {
                let twitchLangString = try String(contentsOfFile: twitchLangPath)
                let twitchLang: Array<Dictionary<String, String>> = try JSONSerialization
                        .jsonObject(with: twitchLangString.data(using: .utf8)!) as! Array<Dictionary<String, String>>
                var selections: Array<ListViewSelection> = Array()
                selections.append(ListViewSelection(name: "All", data: "all"))
                for lang in twitchLang {
                    if let name = lang["name"], let code = lang["code"] {
                        selections.append(ListViewSelection(name: name, data: code))
                    }
                }
                self.langSelections = selections
            }
            catch {
                os_log("Failed to parse twitch_lang.json. Could not show quality selection screen.", type: .debug)
                print(error)
            }
        }
    }

    /// Check login and update text
    private func updateLoginState() {
        TwitchApi.afterLogin(callback: { isLoggedIn in
            if isLoggedIn {
                self.mainSettings[2] = "title.log_out"
            }
            else {
                self.mainSettings[2] = "title.log_in"
            }
            if let settingTableView = self.settingTableView {
                DispatchQueue.main.async(execute: {
                    settingTableView.reloadData()
                })
            }
        })
    }

    /// Specify rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mainSettings.count
    }

    /// Populate items
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let valueButtonCell = tableView.dequeueReusableCell(withIdentifier: "valueButtonCell", for: indexPath)
        if let title = valueButtonCell.textLabel, let detail = valueButtonCell.detailTextLabel {
            title.text = mainSettings[indexPath.item].l10n()
            detail.text = ""
        }
        return valueButtonCell
    }

    /// Item selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
            case 0:
                showLanguageSelectionScreen()
            case 1:
                showQualitySelectionScreen()
            case 2:
                logInOrLogOut()
            case 3:
                showAboutScreen()
            default:
                os_log("Unhandled settings item: %{public}@", indexPath.row)
        }
    }

    /// Show about screen
    private func showAboutScreen() {
        let info = "Information about Twitched can be found at https://www.twitched.org/info.\r\n\r\n" +
                "Twitched's privacy policy can be found at https://www.twitched.org/info/privacy.\r\n\r\n" +
                "Third-party software licenses used in Twitched can be found at https://www.twitched.org/info/oss."
        let alert: UIAlertController = UIAlertController(
                title: Constants.NAME,
                message: info,
                preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: nil, style: .cancel))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true)
        })
    }

    /// Handle log in or out
    private func logInOrLogOut() {
        TwitchApi.afterLogin(callback: { isLoggedIn in
            if isLoggedIn {
                TwitchApi.logOut()
                self.mainSettings[2] = "title.log_in"
                DispatchQueue.main.async(execute: {
                    self.settingTableView?.reloadData()
                })
            }
            else {
                let loginViewController: LoginViewController = self.storyboard?.instantiateViewController(
                        withIdentifier: "loginViewController") as! LoginViewController
                loginViewController.modalPresentationStyle = .blurOverFullScreen
                loginViewController.modalTransitionStyle = .crossDissolve
                loginViewController.dismissCallback = {
                    DispatchQueue.main.async(execute: {
                        self.updateLoginState()
                    })
                }
                DispatchQueue.main.async(execute: {
                    self.present(loginViewController, animated: true)
                })
            }
        })
    }

    /// Show the quality selection screen
    private func showQualitySelectionScreen() {
        let languageSelect: MultipleChoiceListViewController = self.storyboard?.instantiateViewController(
                withIdentifier: "multipleChoiceListViewController") as! MultipleChoiceListViewController
        languageSelect.modalPresentationStyle = .blurOverFullScreen
        languageSelect.modalTransitionStyle = .crossDissolve
        languageSelect.titleText = "title.stream_quality".l10n()
        languageSelect.selections = self.qualitySelections
        // Enabled selections
        let cloud = NSUbiquitousKeyValueStore.default
        if let enabled: Array<String> = cloud.array(forKey: SettingsViewController.TWITCH_QUALITY_KEY)
                as? Array<String> {
            for selection in self.qualitySelections {
                if let code = selection.data {
                    if enabled.contains(code) {
                        languageSelect.enabledSelections = [selection]
                        break
                    }
                }
            }
            if languageSelect.enabledSelections.count == 0 {
                languageSelect.enabledSelections = [self.qualitySelections[0]]
            }
        }
        languageSelect.singleSelection = true
        languageSelect.selectionCallback = saveQualitySelection
        DispatchQueue.main.async(execute: {
            self.present(languageSelect, animated: true)
        })
    }

    /// Save quality selection
    private func saveQualitySelection(_ selections: Array<ListViewSelection>) {
        let cloud = NSUbiquitousKeyValueStore.default
        if selections.count == 1 {
            if let code = selections[0].data {
                cloud.set([code], forKey: SettingsViewController.TWITCH_QUALITY_KEY)
            }
        }
        setDetails()
    }

    /// Fetch and set the details of the list items that have set values
    private func setDetails() {
        let cloud = NSUbiquitousKeyValueStore.default
        // Lang
        let langs = cloud.array(forKey: SettingsViewController.TWITCH_LANG_KEY)
        if let langs: Array<String> = langs as? Array<String> {
            if langs.count == 1 {
                self.langDetail = "title.all".l10n()
            }
            else if langs.count == 1 {
                if let langIndex = self.langSelections.index(where: { selection_ in
                    if selection_.data == langs[0] {
                        return true
                    }
                    return false
                }) {
                    self.langDetail = self.langSelections[langIndex].name
                }
            }
            else {
                self.langDetail = "title.multiple".l10n()
            }
        }
        else {
            self.langDetail = "title.all".l10n()
        }
        // Quality
        let quality = cloud.array(forKey: SettingsViewController.TWITCH_QUALITY_KEY)
        if let quality = quality {
            if quality.count < 1 {

            }
        }
        else {
            self.qualityDetail = "title.automatic".l10n()
        }
    }

    /// Show the language selection screen
    private func showLanguageSelectionScreen() {
            let languageSelect: MultipleChoiceListViewController = self.storyboard?.instantiateViewController(
                    withIdentifier: "multipleChoiceListViewController") as! MultipleChoiceListViewController
            languageSelect.modalPresentationStyle = .blurOverFullScreen
            languageSelect.modalTransitionStyle = .crossDissolve
            languageSelect.titleText = "title.stream_language".l10n()
            languageSelect.selections = self.langSelections
            languageSelect.firstExclusive = true
            // Enabled selections
            let cloud = NSUbiquitousKeyValueStore.default
            if let enabledLangs: Array<String> = cloud.array(forKey: SettingsViewController.TWITCH_LANG_KEY)
                    as? Array<String> {
                var langsToSelections: Array<ListViewSelection> = Array()
                for selection in self.langSelections {
                    if let code = selection.data {
                        if enabledLangs.contains(code) {
                            langsToSelections.append(selection)
                        }
                    }
                }
                if langsToSelections.count > 0 {
                    languageSelect.enabledSelections = langsToSelections
                }
                else {
                    languageSelect.enabledSelections = [self.langSelections[0]]
                }
            }
            languageSelect.selectionCallback = saveLanguageSelection
            DispatchQueue.main.async(execute: {
                self.present(languageSelect, animated: true)
            })
    }

    /// Save language selection to cloud KVS
    private func saveLanguageSelection(_ selections: Array<ListViewSelection>) {
        let cloud = NSUbiquitousKeyValueStore.default
        var langs: Array<String> = Array()
        for selection in selections {
            if let code = selection.data {
                langs.append(code)
            }
        }
        cloud.set(langs, forKey: SettingsViewController.TWITCH_LANG_KEY)
        setDetails()
        VideoGridViewController.needsPopularUpdate = true
    }
}
