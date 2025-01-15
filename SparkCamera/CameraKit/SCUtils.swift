//
//  SCUtils.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import UIKit.UIGraphics

private extension UIDeviceOrientation {
    var imageOrientation: UIImage.Orientation {
        switch self {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
    var imageRotationAngle: CGFloat {
        switch self {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return .pi
        case .landscapeLeft:
            return -.pi/2
        case .landscapeRight:
            return .pi/2
        default:
            return 0
        }
    }
    var isLandscape: Bool {
        return self == .landscapeLeft || self == .landscapeRight
    }
    var imageOrientationMirrored: UIImage.Orientation {
        switch self {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        default:
            return .right
        }
    }
}

@objc public class SCUtils: NSObject {
    
    @objc public static func cropAndScale(_ image: UIImage, width: Int, height: Int, orientation: UIDeviceOrientation, mirrored: Bool) -> UIImage? {
        print("📸 [Utils] ===== 开始处理图片 =====")
        print("📸 [Utils] 输入参数:")
        print("📸 [Utils] - 目标尺寸: \(width) x \(height)")
        print("📸 [Utils] - 目标比例: \(Double(width)/Double(height))")
        print("📸 [Utils] - 设备方向: \(orientation.rawValue)")
        print("📸 [Utils] - 是否镜像: \(mirrored)")
        
        // 1. 获取图片的原始信息
        guard let cgImage = image.cgImage else {
            print("❌ [Utils] 无法获取 CGImage")
            return nil
        }
        
        let imageSize = image.size
        print("📸 [Utils] 原始图片信息:")
        print("📸 [Utils] - 尺寸: \(imageSize.width) x \(imageSize.height)")
        print("📸 [Utils] - 比例: \(imageSize.width/imageSize.height)")
        print("📸 [Utils] - 方向: \(image.imageOrientation.rawValue)")
        
        // 2. 确定目标尺寸和方向
        let targetRatio: CGFloat
        
        if width == 0 || height == 0 {
            // 在主线程获取 ratioMode
            var ratioMode: Int = 0
            if Thread.isMainThread {
                ratioMode = SCCameraSettingsManager.shared.ratioMode
            } else {
                DispatchQueue.main.sync {
                    ratioMode = SCCameraSettingsManager.shared.ratioMode
                }
            }
            
            // 根据比例模式设置目标比例
            switch ratioMode {
            case 0: // 4:3
                targetRatio = 4.0/3.0
            case 1: // 1:1
                targetRatio = 1.0
            case 2: // 16:9
                targetRatio = 16.0/9.0
            default:
                targetRatio = 4.0/3.0
            }
            print("📸 [Utils] 使用预设比例: \(targetRatio)")
        } else {
            targetRatio = CGFloat(width) / CGFloat(height)
            print("📸 [Utils] 使用指定比例: \(targetRatio)")
        }
        
        // 3. 计算目标尺寸
        let maxDimension: CGFloat = 1920 // 使用相机输出的最大尺寸
        let targetSize: CGSize
        
        if orientation.isLandscape {
            // 横屏：宽度为长边
            targetSize = CGSize(width: maxDimension,
                              height: maxDimension / targetRatio)
        } else {
            // 竖屏：高度为长边
            targetSize = CGSize(width: maxDimension / targetRatio,
                              height: maxDimension)
        }
        print("📸 [Utils] 计算的目标尺寸: \(targetSize.width) x \(targetSize.height)")
        
        // 4. 创建绘图上下文
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        print("📸 [Utils] 最终渲染尺寸: \(targetSize.width) x \(targetSize.height)")
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        let result = renderer.image { context in
            // 设置黑色背景
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // 保存状态
            context.cgContext.saveGState()
            
            // 移动到中心点
            context.cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            
            // 计算总旋转角度
            var rotationAngle: CGFloat = 0
            
            // 1. 处理图片的EXIF方向
            switch image.imageOrientation {
            case .up:
                rotationAngle += 0
            case .down:
                rotationAngle += .pi
            case .left:
                rotationAngle += .pi/2
            case .right:
                rotationAngle -= .pi/2
            default:
                rotationAngle += 0
            }
            print("📸 [Utils] EXIF旋转角度: \(rotationAngle/(.pi/2))π/2")
            
            // 2. 处理设备方向
            switch orientation {
            case .portrait:
                rotationAngle += .pi/2
            case .portraitUpsideDown:
                rotationAngle += .pi*3/2
            case .landscapeLeft:
                rotationAngle += .pi
            case .landscapeRight:
                rotationAngle += 0
            default:
                rotationAngle += .pi/2
            }
            print("📸 [Utils] 设备方向旋转角度: \(rotationAngle/(.pi/2))π/2")
            
            // 应用旋转
            context.cgContext.rotate(by: rotationAngle)
            
            // 3. 处理镜像
            if mirrored {
                print("📸 [Utils] 应用镜像变换")
                context.cgContext.scaleBy(x: -1, y: 1)
            }
            
            // 4. 处理EXIF镜像
            if image.imageOrientation.isMirrored {
                print("📸 [Utils] 应用EXIF镜像变换")
                context.cgContext.scaleBy(x: -1, y: 1)
            }
            
            // 5. 绘制图像
            let drawRect: CGRect
            if orientation.isLandscape {
                drawRect = CGRect(x: -targetSize.height/2, y: -targetSize.width/2,
                                width: targetSize.height, height: targetSize.width)
            } else {
                drawRect = CGRect(x: -targetSize.width/2, y: -targetSize.height/2,
                                width: targetSize.width, height: targetSize.height)
            }
            print("📸 [Utils] 绘制区域: \(drawRect)")
            
            context.cgContext.draw(cgImage, in: drawRect)
            
            // 恢复状态
            context.cgContext.restoreGState()
        }
        
        print("📸 [Utils] 处理完成:")
        print("📸 [Utils] - 最终尺寸: \(result.size.width) x \(result.size.height)")
        print("📸 [Utils] - 最终比例: \(result.size.width/result.size.height)")
        print("📸 [Utils] - 最终方向: \(result.imageOrientation.rawValue)")
        print("📸 [Utils] ===== 处理完成 =====")
        
        return result
    }
}

// MARK: - Helper Extensions
private extension UIImage.Orientation {
    var isMirrored: Bool {
        switch self {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }
}

