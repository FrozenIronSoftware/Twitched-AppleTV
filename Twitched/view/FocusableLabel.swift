//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

@IBDesignable
class FocusableLabel: UIControl, ResettingViewController {

    @IBInspectable public var selectedBackgroundColor: UIColor = .clear
    @IBInspectable public var fontSize: CGFloat = 30 {
        didSet {
            label?.font = UIFont(name: self.fontName, size: self.fontSize)
        }
    }
    @IBInspectable public var fontName: String = "Helvetica Neue" {
        didSet {
            label?.font = UIFont(name: self.fontName, size: self.fontSize)
        }
    }
    @IBInspectable public var textAlignHorizontal: Int = NSTextAlignment.left.rawValue {
        didSet {
            label?.textAlignment = NSTextAlignment(rawValue: self.textAlignHorizontal)!
        }
    }
    @IBInspectable public var minimumFontScale: CGFloat = 0.5 {
        didSet {
            label?.minimumScaleFactor = self.minimumFontScale
        }
    }
    @IBInspectable public var textColorDarkUi: UIColor = .black {
        didSet {
            label?.textColor = self.textColorDarkUi
        }
    }
    @IBInspectable public var textColorLightUi: UIColor = .white {
        didSet {
            label?.textColor = self.textColorLightUi
        }
    }

    private var label: UILabel?
    var text: String = "" {
        didSet{
            label?.text = self.text
        }
    }
    override var bounds: CGRect {
        didSet {
            label?.frame = self.bounds
        }
    }

    /// Init
    override func awakeFromNib() {
        super.awakeFromNib()
        // Init
        self.backgroundColor = .clear
        label = UILabel()
        label?.frame = self.bounds
        label?.font = UIFont(name: self.fontName, size: self.fontSize)
        label?.textAlignment = NSTextAlignment(rawValue: self.textAlignHorizontal)!
        label?.minimumScaleFactor = self.minimumFontScale
        label?.adjustsFontSizeToFitWidth = true
        label?.allowsDefaultTighteningForTruncation = true
        setTextColorStyle()
        addSubview(label!)
        // Setup tap recognizer
        let tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self,
                action: #selector(self.selected(sender:)))
        tapRecognizer.allowedPressTypes = [NSNumber(value: UIPressType.select.rawValue)]
        self.addGestureRecognizer(tapRecognizer)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
    }

    /// Handle the view being selected
    @objc private func selected(sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                if self.isFocused {
                    self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }
                else {
                    self.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            }, completion: { _ in
                self.sendActions(for: .primaryActionTriggered)
            })
        })
    }

    /// Make focusable
    override var canBecomeFocused: Bool {
        return true
    }

    /// Handle focus
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if context.nextFocusedView == self {
            coordinator.addCoordinatedAnimations({
                self.layer.backgroundColor = self.selectedBackgroundColor.cgColor
                self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                self.label?.transform = CGAffineTransform(scaleX: 0.9, y: 1)
            })
        }
        else {
            coordinator.addCoordinatedAnimations({
                self.layer.backgroundColor = UIColor.clear.cgColor
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
                self.label?.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
        }
    }

    /// Handle the application becoming active
    func applicationDidBecomeActive() {
        setTextColorStyle()
    }

    /// Set text color based on UI style
    private func setTextColorStyle() {
        DispatchQueue.global(qos: .background).async {
            while self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.unspecified {}
            DispatchQueue.main.async {
                if self.traitCollection.userInterfaceStyle == UIUserInterfaceStyle.light {
                    self.label?.textColor = self.textColorLightUi
                }
                else {
                    self.label?.textColor = self.textColorDarkUi
                }
            }
        }
    }
}
