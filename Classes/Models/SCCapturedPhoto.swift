import UIKit

struct SCCapturedPhoto {
    let image: UIImage
    let timestamp: Date
    
    init(image: UIImage) {
        self.image = image
        self.timestamp = Date()
    }
} 