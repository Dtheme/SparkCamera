//
//  SCPhotoInfo.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/17.
//

import UIKit

/// 照片信息模型，用于在拍照和预览之间传递照片相关信息
@objc public class SCPhotoInfo: NSObject {
    
    // MARK: - Properties
    
    /// 照片宽高比（width/height）
    public let aspectRatio: CGFloat
    
    /// 是否是横向照片
    public let isLandscape: Bool
    
    /// 照片宽度（像素）
    public let width: CGFloat
    
    /// 照片高度（像素）
    public let height: CGFloat
    
    /// 照片方向
    public let orientation: UIImage.Orientation
    
    /// 是否已保存到相册
    public var isSavedToAlbum: Bool = false
    
    /// 拍照格式（例如："JPEG"、"RAW"、"RAW+JPEG"）
    public var captureFormat: String = "JPEG"
    
    // MARK: - Initialization
    
    /// 使用UIImage初始化
    /// - Parameter image: 原始图片
    public init(image: UIImage) {
        self.width = image.size.width
        self.height = image.size.height
        self.aspectRatio = width / height
        self.isLandscape = width > height
        self.orientation = image.imageOrientation
    }
    
    /// 使用具体参数初始化
    /// - Parameters:
    ///   - width: 照片宽度
    ///   - height: 照片高度
    ///   - orientation: 照片方向
    public init(width: CGFloat, height: CGFloat, orientation: UIImage.Orientation) {
        self.width = width
        self.height = height
        self.aspectRatio = width / height
        self.isLandscape = width > height
        self.orientation = orientation
    }
    
    // MARK: - Dictionary Conversion
    
    /// 转换为字典格式
    public var dictionary: [String: Any] {
        return [
            "aspectRatio": aspectRatio,
            "isLandscape": isLandscape,
            "width": width,
            "height": height,
            "orientation": orientation.rawValue,
            "isSavedToAlbum": isSavedToAlbum,
            "format": captureFormat
        ]
    }
    
    /// 从字典创建实例
    /// - Parameter dict: 包含照片信息的字典
    /// - Returns: SCPhotoInfo实例，如果信息不完整则返回nil
    public static func from(dictionary dict: [String: Any]) -> SCPhotoInfo? {
        guard let width = dict["width"] as? CGFloat,
              let height = dict["height"] as? CGFloat,
              let orientationRaw = dict["orientation"] as? Int,
              let orientation = UIImage.Orientation(rawValue: orientationRaw) else {
            return nil
        }
        
        let info = SCPhotoInfo(width: width, height: height, orientation: orientation)
        info.isSavedToAlbum = dict["isSavedToAlbum"] as? Bool ?? false
        if let fmt = dict["format"] as? String { info.captureFormat = fmt }
        return info
    }
    
    // MARK: - Debug Description
    
    override public var description: String {
        return """
          [Photo Info]
        - 尺寸: \(width) x \(height)
        - 宽高比: \(aspectRatio)
        - 是否横向: \(isLandscape)
        - 方向: \(orientation.rawValue)
        - 格式: \(captureFormat)
        - 已保存到相册: \(isSavedToAlbum)
        """
    }
}

// MARK: - Orientation Helper
extension SCPhotoInfo {
    /// 检查是否需要旋转显示
    public var needsRotation: Bool {
        switch orientation {
        case .up, .upMirrored:
            return false
        default:
            return true
        }
    }
    
    /// 获取旋转角度（弧度）
    public var rotationAngle: CGFloat {
        switch orientation {
        case .right, .rightMirrored:
            return .pi / 2
        case .left, .leftMirrored:
            return -.pi / 2
        case .down, .downMirrored:
            return .pi
        default:
            return 0
        }
    }
    
    /// 检查是否需要镜像
    public var needsMirroring: Bool {
        switch orientation {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }
} 
