//
// Created by Rolando Islas on 8/1/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

class MultipleChoiceListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private weak var tableView: UITableView?
    @IBOutlet private weak var titleLabel: UILabel?
    var selectionCallback: ((Array<ListViewSelection>) -> Void)? = nil
    var selections: Array<ListViewSelection> = Array() {
        didSet {
            DispatchQueue.main.async(execute: {
                if let tableView = self.tableView {
                    tableView.reloadData()
                }
            })
        }
    }
    var enabledSelections: Array<ListViewSelection> = Array() {
        didSet {
            DispatchQueue.main.async(execute: {
                if let tableView = self.tableView {
                    tableView.reloadData()
                }
            })
        }
    }
    var titleText: String = "" {
        didSet {
            if let titleLabel = self.titleLabel {
                titleLabel.text = self.titleText
            }
        }
    }
    var singleSelection: Bool = false
    var firstExclusive: Bool = false

    /// Handle loading
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    /// Handle appearance
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let titleLabel = self.titleLabel {
            titleLabel.text = self.titleText
        }
        if let tableView = self.tableView {
            tableView.allowsMultipleSelection = !self.singleSelection
        }
    }

    /// Selections in list
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selections.count
    }

    /// Create selection list
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "choice", for: indexPath)
        if let text = cell.textLabel, let selection = selections[safe: indexPath.item], let code = selection.data {
            text.text = selection.name
            if enabledSelections.contains(where: { selection_ in
                if selection_.data == code {
                    return true
                }
                return false
            }) {
                cell.isSelected = true
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
        return cell
    }

    /// Handle item selection
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Disable other selections if the first one is selected or disable the first if others are selected
        if self.firstExclusive {
            if indexPath.row == 0 {
                self.enabledSelections.removeAll(keepingCapacity: false)
            }
            else {
                if let selection = self.selections[safe: 0], let index = self.enabledSelections.index(
                        where: { selection_ in
                            if selection_.data == selection.data {
                                return true
                            }
                            return false
                }) {
                    self.enabledSelections.remove(at: index)
                }
            }
        }
        // Add selection
        if let selection = self.selections[safe: indexPath.row], let code = selection.data {
            if !self.enabledSelections.contains(where: { selection_ in
                if selection_.data == code {
                    return true
                }
                return false
            }) {
                self.enabledSelections.append(selection)
                if self.singleSelection {
                    self.dismiss(animated: true)
                }
            }
        }
    }

    /// Handle item deselection
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let selection = self.selections[safe: indexPath.row], let code = selection.data,
           let index = self.enabledSelections.index(where: { selection_ in
               if selection_.data == code {
                   return true
               }
               return false
           }) {
            self.enabledSelections.remove(at: index)
        }
    }

    /// Handle dismiss
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: {
            if let completion = completion {
                completion()
            }
            if let selectionCallback = self.selectionCallback {
                selectionCallback(self.enabledSelections)
            }
        })
    }
}
