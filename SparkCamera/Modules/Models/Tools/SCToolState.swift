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
public enum SCLivePhotoState: SCToolState {
    case off
    case on
    
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
            return 3.0 / 4.0
        case .ratio1_1:
            return 1.0
        case .ratio16_9:
            return 9.0 / 16.0
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
}

extension SCWhiteBalanceState: SCToolState {}

// MARK: - Exposure State
public enum SCExposureState: SCToolState {
    case negative2
    case negative1
    case zero
    case positive1
    case positive2
    
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
    case threeSeconds = 1
    case fiveSeconds = 2
    case tenSeconds = 3
    
    public var icon: UIImage? {
        let baseIcon = UIImage(systemName: "timer")
        switch self {
        case .off:
            return baseIcon
        case .threeSeconds, .fiveSeconds, .tenSeconds:
            return baseIcon?.withTintColor(.yellow, renderingMode: .alwaysOriginal)
        }
    }
    
    public var title: String {
        switch self {
        case .off: return "关闭"
        case .threeSeconds: return "3秒"
        case .fiveSeconds: return "5秒"
        case .tenSeconds: return "10秒"
        }
    }
    
    public func nextState() -> SCTimerState { return self }
    
    public var seconds: Int {
        switch self {
        case .off: return 0
        case .threeSeconds: return 3
        case .fiveSeconds: return 5
        case .tenSeconds: return 10
        }
    }
}

extension SCTimerState: SCToolState {} 