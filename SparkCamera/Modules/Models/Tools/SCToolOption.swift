import UIKit

/// 工具选项协议
public protocol SCToolOption {
    var title: String { get }
    var state: SCToolState { get }
    var isSelected: Bool { get set }
}

struct SCDefaultToolOption: SCToolOption {
    let title: String
    let state: SCToolState
    var isSelected: Bool
    
    init(title: String, state: SCToolState, isSelected: Bool = false) {
        self.title = title
        self.state = state
        self.isSelected = isSelected
    }
}

// MARK: - Flash Options
public enum SCFlashOption: SCToolOption {
    case auto, on, off
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .on: return "打开"
        case .off: return "闪光灯已关闭"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .auto: return SCFlashState.auto
        case .on: return SCFlashState.on
        case .off: return SCFlashState.off
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .auto: return SCCameraSettingsManager.shared.flashMode == SCFlashState.auto.rawValue
            case .on: return SCCameraSettingsManager.shared.flashMode == SCFlashState.on.rawValue
            case .off: return SCCameraSettingsManager.shared.flashMode == SCFlashState.off.rawValue
            }
        }
        set { }  // 不需要实现set，因为状态由SCCameraSettingsManager管理
    }
}

// MARK: - LivePhoto Options
public enum SCLivePhotoOption: SCToolOption {
    case on, off
    
    public var title: String {
        switch self {
        case .on: return "开启"
        case .off: return "关闭"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .on: return SCLivePhotoState.on
        case .off: return SCLivePhotoState.off
        }
    }
        
    public var isSelected: Bool {
        get {
            switch self {
            case .on: return SCCameraSettingsManager.shared.isLivePhotoEnabled
            case .off: return !SCCameraSettingsManager.shared.isLivePhotoEnabled
            }
        }
        set { }  // 不需要实现set，因为状态由SCCameraSettingsManager管理
    }
}

// MARK: - Ratio Options
public enum SCRatioOption: SCToolOption {
    case ratio4_3, ratio1_1, ratio16_9
    
    public var title: String {
        switch self {
        case .ratio4_3: return "4:3"
        case .ratio1_1: return "1:1"
        case .ratio16_9: return "16:9"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .ratio4_3: return SCRatioState.ratio4_3
        case .ratio1_1: return SCRatioState.ratio1_1
        case .ratio16_9: return SCRatioState.ratio16_9
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .ratio4_3: return SCCameraSettingsManager.shared.ratioMode == SCRatioState.ratio4_3.rawValue
            case .ratio1_1: return SCCameraSettingsManager.shared.ratioMode == SCRatioState.ratio1_1.rawValue
            case .ratio16_9: return SCCameraSettingsManager.shared.ratioMode == SCRatioState.ratio16_9.rawValue
            }
        }
        set { }
    }
}

// MARK: - WhiteBalance Options
public enum SCWhiteBalanceOption: SCToolOption {
    case auto, sunny, cloudy, fluorescent, incandescent
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .sunny: return "晴天"
        case .cloudy: return "阴天"
        case .fluorescent: return "荧光灯"
        case .incandescent: return "白炽灯"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .auto: return SCWhiteBalanceState.auto
        case .sunny: return SCWhiteBalanceState.sunny
        case .cloudy: return SCWhiteBalanceState.cloudy
        case .fluorescent: return SCWhiteBalanceState.fluorescent
        case .incandescent: return SCWhiteBalanceState.incandescent
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .auto: return SCCameraSettingsManager.shared.whiteBalanceMode == SCWhiteBalanceState.auto.rawValue
            case .sunny: return SCCameraSettingsManager.shared.whiteBalanceMode == SCWhiteBalanceState.sunny.rawValue
            case .cloudy: return SCCameraSettingsManager.shared.whiteBalanceMode == SCWhiteBalanceState.cloudy.rawValue
            case .fluorescent: return SCCameraSettingsManager.shared.whiteBalanceMode == SCWhiteBalanceState.fluorescent.rawValue
            case .incandescent: return SCCameraSettingsManager.shared.whiteBalanceMode == SCWhiteBalanceState.incandescent.rawValue
            }
        }
        set { }
    }
}

// MARK: - Exposure Options
public enum SCExposureOption: SCToolOption {
    case negative2, negative1, zero, positive1, positive2
    
    public var title: String {
        switch self {
        case .negative2: return "-2.0"
        case .negative1: return "-1.0"
        case .zero: return "0"
        case .positive1: return "+1.0"
        case .positive2: return "+2.0"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .negative2: return SCExposureState.negative2
        case .negative1: return SCExposureState.negative1
        case .zero: return SCExposureState.zero
        case .positive1: return SCExposureState.positive1
        case .positive2: return SCExposureState.positive2
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .negative2: return SCCameraSettingsManager.shared.exposureValue == SCExposureState.negative2.value
            case .negative1: return SCCameraSettingsManager.shared.exposureValue == SCExposureState.negative1.value
            case .zero: return SCCameraSettingsManager.shared.exposureValue == SCExposureState.zero.value
            case .positive1: return SCCameraSettingsManager.shared.exposureValue == SCExposureState.positive1.value
            case .positive2: return SCCameraSettingsManager.shared.exposureValue == SCExposureState.positive2.value
            }
        }
        set { }
    }
}

// MARK: - ISO Options
public enum SCISOOption: SCToolOption {
    case auto, iso100, iso200, iso400, iso800
    
    public var title: String {
        switch self {
        case .auto: return "自动"
        case .iso100: return "ISO 100"
        case .iso200: return "ISO 200"
        case .iso400: return "ISO 400"
        case .iso800: return "ISO 800"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .auto: return SCISOState.auto
        case .iso100: return SCISOState.iso100
        case .iso200: return SCISOState.iso200
        case .iso400: return SCISOState.iso400
        case .iso800: return SCISOState.iso800
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .auto: return SCCameraSettingsManager.shared.isoValue == SCISOState.auto.value
            case .iso100: return SCCameraSettingsManager.shared.isoValue == SCISOState.iso100.value
            case .iso200: return SCCameraSettingsManager.shared.isoValue == SCISOState.iso200.value
            case .iso400: return SCCameraSettingsManager.shared.isoValue == SCISOState.iso400.value
            case .iso800: return SCCameraSettingsManager.shared.isoValue == SCISOState.iso800.value
            }
        }
        set { }
    }
}

// MARK: - Timer Options
public enum SCTimerOption: SCToolOption {
    case off, threeSeconds, fiveSeconds, tenSeconds
    
    public var title: String {
        switch self {
        case .off: return "关闭"
        case .threeSeconds: return "3秒"
        case .fiveSeconds: return "5秒"
        case .tenSeconds: return "10秒"
        }
    }
    
    public var state: SCToolState {
        switch self {
        case .off: return SCTimerState.off
        case .threeSeconds: return SCTimerState.seconds3
        case .fiveSeconds: return SCTimerState.seconds5
        case .tenSeconds: return SCTimerState.seconds10
        }
    }
    
    public var isSelected: Bool {
        get {
            switch self {
            case .off: return SCCameraSettingsManager.shared.timerMode == SCTimerState.off.rawValue
            case .threeSeconds: return SCCameraSettingsManager.shared.timerMode == SCTimerState.seconds3.rawValue
            case .fiveSeconds: return SCCameraSettingsManager.shared.timerMode == SCTimerState.seconds5.rawValue
            case .tenSeconds: return SCCameraSettingsManager.shared.timerMode == SCTimerState.seconds10.rawValue
            }
        }
        set { }
    }
}

// 其他选项定义... 
