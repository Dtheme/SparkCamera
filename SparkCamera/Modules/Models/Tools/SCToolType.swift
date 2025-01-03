import UIKit

/// 相机工具类型
public enum SCToolType {
    case flash        // 闪光灯
    case livePhoto    // 实况照片
    case ratio        // 预览比例
    case whiteBalance // 白平衡
    case exposure     // 曝光补偿
    case iso          // ISO
    case timer        // 计时器
    
    /// 默认图标
    public var defaultIcon: UIImage? {
        switch self {
        case .flash:
            return UIImage(systemName: "bolt.slash.fill")
        case .livePhoto:
            return UIImage(systemName: "livephoto")
        case .ratio:
            return UIImage(systemName: "rectangle")
        case .whiteBalance:
            return UIImage(systemName: "circle.lefthalf.filled")
        case .exposure:
            return UIImage(systemName: "plusminus")
        case .iso:
            return UIImage(systemName: "camera.aperture")
        case .timer:
            return UIImage(systemName: "timer")
        }
    }
    
    /// 默认标题
    public var defaultTitle: String {
        switch self {
        case .flash:
            return "关闭"
        case .livePhoto:
            return "实况"
        case .ratio:
            return "4:3"
        case .whiteBalance:
            return "白平衡"
        case .exposure:
            return "曝光补偿"
        case .iso:
            return "ISO"
        case .timer:
            return "计时器"
        }
    }
    
    /// 是否支持展开子选项
    public var supportsExpansion: Bool {
        return true
    }
    
    /// 是否支持状态切换
    public var supportsStateToggle: Bool {
        switch self {
        case .flash, .livePhoto:
            return true
        default:
            return false
        }
    }
    
    /// 默认选项
    public var defaultOptions: [SCToolOption] {
        switch self {
        case .flash:
            return [
                SCFlashOption.auto,
                SCFlashOption.on,
                SCFlashOption.off
            ]
        case .ratio:
            return [
                SCRatioOption.ratio4_3,
                SCRatioOption.ratio1_1,
                SCRatioOption.ratio16_9
            ]
        case .whiteBalance:
            return [
                SCWhiteBalanceOption.auto,
                SCWhiteBalanceOption.sunny,
                SCWhiteBalanceOption.cloudy,
                SCWhiteBalanceOption.fluorescent,
                SCWhiteBalanceOption.incandescent
            ]
        case .exposure:
            return [
                SCExposureOption.negative2,
                SCExposureOption.negative1,
                SCExposureOption.zero,
                SCExposureOption.positive1,
                SCExposureOption.positive2
            ]
        case .iso:
            return [
                SCISOOption.auto,
                SCISOOption.iso100,
                SCISOOption.iso200,
                SCISOOption.iso400,
                SCISOOption.iso800
            ]
        case .timer:
            return [
                SCTimerOption.off,
                SCTimerOption.threeSeconds,
                SCTimerOption.fiveSeconds,
                SCTimerOption.tenSeconds
            ]
        case .livePhoto:
            return [
                SCLivePhotoOption.on,
                SCLivePhotoOption.off
            ]
        }
    }
} 