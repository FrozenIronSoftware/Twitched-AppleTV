//
// Created by Rolando Islas on 5/15/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire

class ImageUtil {
    enum Alignment: Int {
        case LEFT = 0, RIGHT = 1, TOP = 2, BOTTOM = 3
    }

    /// Create a new image the desired size with the specified image placed into it
    class func expandImageCanvas(image: UIImage, alignHoriz: ImageUtil.Alignment, alignVert: ImageUtil.Alignment,
                                 size: CGSize, color: UIColor? = nil) -> UIImage {
        assert(size.width >= image.size.width)
        assert(size.height >= image.size.height)
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        if color != nil {
            color?.setFill()
            UIRectFill(rect)
        }
        var x: CGFloat
        switch alignHoriz {
            case .LEFT:
                x = 0
            case .RIGHT:
                x = size.width - image.size.width
            default:
                x = 0
        }
        var y: CGFloat
        switch alignVert {
            case .TOP:
                y = 0
            case .BOTTOM:
                y = size.height - image.size.height
            default:
                y = 0
        }
        let imageRect: CGRect = CGRect(x: x, y: y, width: image.size.width, height: image.size.height)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        context.clear(imageRect)
        image.draw(in: imageRect)
        let expandedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return expandedImage
    }

    class func imageFromUrl(url: String, completion: @escaping (UIImage?) -> Void) {
        request(url).responseData(completionHandler: { response in
            if let data: Data = response.result.value {
                completion(UIImage(data: data))
            }
            else {
                completion(nil)
            }
        })
    }
}

extension UIImageView {
    /// Attempt to set the image to the one contained at the URL
    /// This performs an async request and will set the image to an error placeholder if an error is encountered
    func setUrl(_ url: String, errorImageName: String? = nil) {
        request(url).responseData { response in
            if let data = response.result.value {
                let image = UIImage(data: data)
                self.image = image
            }
            else {
                if let errorImageName: String = errorImageName {
                    self.image = UIImage(named: errorImageName)
                }
                else {
                    self.image = nil
                }
            }
        }
    }
}