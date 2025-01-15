//
//  SCCameraVC+SessionDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/13.
//

import UIKit

extension UIImage {
    func SCRotate(by angle: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.translateBy(x: size.width/2, y: size.height/2)
            context.cgContext.rotate(by: angle)
            draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        }
    }
} 
