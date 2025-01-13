//
//  SCToolState.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/21.
//



import UIKit
import AVFoundation

/// 工具状态协议
public protocol SCToolState {
    var icon: UIImage? { get }
    var title: String { get }
    func nextState() -> Self
}

// MARK: - Flash State
public enum SCFlashState: Int {
    case auto = 0
    case on = 1
    case off = 2
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .on: return "打开"
        case .off: return "关闭"
        }
    }
    
    public var icon: UIImage? {
        switch self {
        case .auto: return UIImage(systemName: "bolt")
        case .on: return UIImage(systemName: "bolt.fill")
        case .off: return UIImage(systemName: "bolt.slash.fill")
        }
    }
    
    public var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}

extension SCFlashState: SCToolState {
    public func nextState() -> SCFlashState {
        switch self {
        case .off: return .on
        case .on: return .auto
        case .auto: return .off
        }
    }
}

// MARK: - LivePhoto State
public enum SCLivePhotoState: Int {
    case off = 0
    case on = 1
    
    public var icon: UIImage? {
        switch self {
        case .off: return UIImage(systemName: "livephoto")
        case .on: return UIImage(systemName: "livephoto.fill")
        }
    }
    
    public var title: String {
        switch self {
        case .off: return "关闭"
        case .on: return "开启"
        }
    }
}

extension SCLivePhotoState: SCToolState {
    public func nextState() -> SCLivePhotoState {
        switch self {
        case .off: return .on
        case .on: return .off
        }
    }
}

// MARK: - Ratio State
public enum SCRatioState: Int {
    case ratio4_3 = 0
    case ratio1_1 = 1
    case ratio16_9 = 2
    
    public var title: String {
        switch self {
        case .ratio4_3:
            return "4:3"
        case .ratio1_1:
            return "1:1"
        case .ratio16_9:
            return "16:9"
        }
    }
    
    public var icon: UIImage? {
        switch self {
        case .ratio4_3:
            return SCSVGImageLoader.loadSVG(named: "icon_4v3", size: CGSize(width: 24, height: 24))
        case .ratio1_1:
            return SCSVGImageLoader.loadSVG(named: "icon_1v1", size: CGSize(width: 24, height: 24))
        case .ratio16_9:
            return SCSVGImageLoader.loadSVG(named: "icon_16v9", size: CGSize(width: 24, height: 24))
        }
    }
    
    public var aspectRatio: CGFloat {
        switch self {
        case .ratio4_3:
            return 4.0 / 3.0
        case .ratio1_1:
            return 1.0
        case .ratio16_9:
            return 16.0 / 9.0
        }
    }
}

extension SCRatioState: SCToolState {
    public func nextState() -> SCRatioState {
        switch self {
        case .ratio4_3:
            return .ratio1_1
        case .ratio1_1:
            return .ratio16_9
        case .ratio16_9:
            return .ratio4_3
        }
    }
}

// MARK: - WhiteBalance State
public enum SCWhiteBalanceState: Int {
    case auto = 0
    case sunny = 1
    case cloudy = 2
    case fluorescent = 3
    case incandescent = 4
    
    public var icon: UIImage? {
        return UIImage(systemName: "circle.lefthalf.filled")
    }
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .sunny: return "晴天"
        case .cloudy: return "阴天"
        case .fluorescent: return "荧光灯"
        case .incandescent: return "白炽灯"
        }
    }
    
    public func nextState() -> SCWhiteBalanceState { return self }
    
    public var temperature: Float {
        switch self {
        case .auto: return 0  // 自动模式
        case .sunny: return 5500  // 晴天色温
        case .cloudy: return 6500  // 阴天色温
        case .fluorescent: return 4000  // 荧光灯色温
        case .incandescent: return 2700  // 白炽灯色温
        }
    }
    
    public var tint: Float {
        switch self {
        case .auto: return 0      // 自动模式，不调整色调
        case .sunny: return 0      // 晴天，标准色调
        case .cloudy: return 10    // 阴天，稍微偏冷
        case .fluorescent: return -10  // 荧光灯，稍微偏绿
        case .incandescent: return 5   // 白炽灯，稍微偏暖
        }
    }
}

extension SCWhiteBalanceState: SCToolState {}

// MARK: - Exposure State
public enum SCExposureState: SCToolState {
    case negative2
    case negative1
    case zero
    case positive1
    case positive2
    case custom(value: Float)
    
    public var icon: UIImage? {
        return UIImage(systemName: "plusminus")
    }
    
    public var title: String {
        switch self {
        case .negative2: return "-2.0"
        case .negative1: return "-1.0"
        case .zero: return "0"
        case .positive1: return "+1.0"
        case .positive2: return "+2.0"
        case .custom(let value): return String(format: "%.1f", value)
        }
    }
    
    public func nextState() -> SCExposureState { return self }
    
    public var value: Float {
        switch self {
        case .negative2: return -2.0
        case .negative1: return -1.0
        case .zero: return 0.0
        case .positive1: return 1.0
        case .positive2: return 2.0
        case .custom(let value): return value
        }
    }
}

// MARK: - ISO State
public enum SCISOState: SCToolState {
    case auto
    case iso100
    case iso200
    case iso400
    case iso800
    
    public var icon: UIImage? {
        return UIImage(systemName: "camera.aperture")
    }
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .iso100: return "ISO 100"
        case .iso200: return "ISO 200"
        case .iso400: return "ISO 400"
        case .iso800: return "ISO 800"
        }
    }
    
    public func nextState() -> SCISOState { return self }
    
    public var value: Float {
        switch self {
        case .auto: return 0  // 自动模式
        case .iso100: return 100
        case .iso200: return 200
        case .iso400: return 400
        case .iso800: return 800
        }
    }
}

// MARK: - Timer State
public enum SCTimerState: Int {
    case off = 0
    case seconds3 = 1
    case seconds5 = 2
    case seconds10 = 3
    
    public var icon: UIImage? {
        let baseIcon = UIImage(systemName: "timer")
        switch self {
        case .off:
            return baseIcon
        case .seconds3, .seconds5, .seconds10:
            return baseIcon?.withTintColor(SCConstants.themeColor, renderingMode: .alwaysOriginal)
        }
    }
    
    public var title: String {
        switch self {
        case .off: return "关闭"
        case .seconds3: return "3秒"
        case .seconds5: return "5秒"
        case .seconds10: return "10秒"
        }
    }
    
    public var seconds: Int {
        switch self {
        case .off: return 0
        case .seconds3: return 3
        case .seconds5: return 5
        case .seconds10: return 10
        }
    }
}

extension SCTimerState: SCToolState {
    public func nextState() -> SCTimerState { return self }
}

// 快门速度状态
public enum SCShutterSpeedState: Float, CaseIterable {
    case auto = 0.0
    case speed1_1000 = 0.001    // 1/1000s
    case speed1_500 = 0.002     // 1/500s
    case speed1_250 = 0.004     // 1/250s
    case speed1_125 = 0.008     // 1/125s
    case speed1_60 = 0.0167     // 1/60s
    case speed1_30 = 0.0333     // 1/30s
    case speed1_15 = 0.0667     // 1/15s
    case speed1_8 = 0.125       // 1/8s
    case speed1_4 = 0.25        // 1/4s
    case speed1_2 = 0.5         // 1/2s
    case speed1 = 1.0           // 1s
    
    public var title: String {
        switch self {
        case .auto:
            return "自动"
        default:
            if self.rawValue < 0.1 {
                return "1/\(Int(1/self.rawValue))s"
            } else {
                return String(format: "%.1fs", self.rawValue)
            }
        }
    }
    
    public var value: Float {
        return self.rawValue
    }
}

extension SCShutterSpeedState: SCToolState {
    public var icon: UIImage? {
        return UIImage(systemName: "camera.shutter")
    }
    
    public func nextState() -> SCShutterSpeedState { return self }
} 
