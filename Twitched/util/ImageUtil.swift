//
// Created by Rolando Islas on 5/15/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage

class ImageUtil {
    public static let imageDownloader: ImageDownloader = ImageDownloader()

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

    /// Try get a UI image from a URL
    class func imageFromUrl(url: String, completion: @escaping (UIImage?) -> Void) -> RequestReceipt? {
        return imageDownloader.download(URLRequest(url: URL(safe: url))) { response in
            completion(response.result.value)
        }
    }
}

extension UIImageView {
    /// Attempt to set the image to the one contained at the URL
    /// This performs an async request and will set the image to an error placeholder if an error is encountered
    func setUrl(_ url: String, errorImageName: String? = nil) -> RequestReceipt? {
        return ImageUtil.imageDownloader.download(URLRequest(url: URL(safe: url))) { response in
            if let image = response.result.value {
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

extension UIImage {
    /// Attempt to download an image and return a UIImage with its data
    static func loadFromUrl(_ url: String, completion: @escaping (UIImage?) -> Void) -> RequestReceipt? {
        return ImageUtil.imageDownloader.download(URLRequest(url: URL(safe: url))) { response in
            completion(response.result.value)
        }
    }

    /// Attempt to download all urls as images and return a dictionary with keys set to the initial url passed
    static func loadAllFromUrl(urls: Array<String>, errorImageName: String? = nil,
                        completion: @escaping (Dictionary<String, UIImage?>) -> Void) -> Array<RequestReceipt> {
        var dataRequests: Array<RequestReceipt> = Array()
        var images: Dictionary<String, UIImage> = Dictionary()
        for url in urls {
            if let requestReceipt = loadFromUrl(url, completion: { image in
                if let image = image {
                    images[url] = image
                }
                else {
                    images[url] = nil
                }
                if images.count == urls.count {
                    completion(images)
                }
            }) {
                dataRequests.append(requestReceipt)
            }
        }
        return dataRequests
    }
}

extension URL {
    init(safe url: String) {
        if let _url = URL(string: url) {
            self = _url
        }
        else {
            self = URL(string: "https://localhost/404.png")!
        }
    }
}