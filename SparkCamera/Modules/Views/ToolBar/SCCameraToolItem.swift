import UIKit
import AVFoundation

// 工具项状态协议
protocol ToolItemState {
    var icon: UIImage? { get }
    var title: String { get }
    func nextState() -> Self
}

// 工具项类型
enum SCCameraToolType {
    case flash        // 闪光灯
    case livePhoto    // 实况照片
    case ratio        // 预览比例
    case whiteBalance // 白平衡
    case mute         // 静音
    
    var defaultIcon: UIImage? {
        switch self {
        case .flash:
            return UIImage(systemName: "bolt.slash.fill")
        case .livePhoto:
            return UIImage(systemName: "livephoto")
        case .ratio:
            return UIImage(systemName: "rectangle")
        case .whiteBalance:
            return UIImage(systemName: "circle.lefthalf.filled")
        case .mute:
            return UIImage(systemName: "speaker.slash.fill")
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .flash:
            return "关闭"
        case .livePhoto:
            return "实况"
        case .ratio:
            return "4:3"
        case .whiteBalance:
            return "白平衡"
        case .mute:
            return "静音"
        }
    }
    
    // 是否支持展开子选项
    var supportsExpansion: Bool {
        // 所有工具项都支持展开
        return true
    }
    
    // 是否支持状态切换
    var supportsStateToggle: Bool {
        switch self {
        case .flash, .livePhoto, .mute:
            return true
        default:
            return false
        }
    }
}

// 闪光灯状态
enum FlashMode: ToolItemState {
    case off
    case on
    case auto
    
    var icon: UIImage? {
        switch self {
        case .off:
            return UIImage(systemName: "bolt.slash.fill")
        case .on:
            return UIImage(systemName: "bolt.fill")
        case .auto:
            return UIImage(systemName: "bolt")
        }
    }
    
    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .on:
            return "打开"
        case .auto:
            return "自动"
        }
    }
    
    func nextState() -> FlashMode {
        switch self {
        case .off:
            return .on
        case .on:
            return .auto
        case .auto:
            return .off
        }
    }
    
    init(sessionFlashMode: SCSession.FlashMode) {
        switch sessionFlashMode {
        case .off:
            self = .off
        case .on:
            self = .on
        case .auto:
            self = .auto
        }
    }
    
    var sessionFlashMode: SCSession.FlashMode {
        switch self {
        case .off:
            return .off
        case .on:
            return .on
        case .auto:
            return .auto
        }
    }
}

// 实况照片状态
enum LivePhotoMode: ToolItemState {
    case off
    case on
    
    var icon: UIImage? {
        switch self {
        case .off:
            return UIImage(systemName: "livephoto")
        case .on:
            return UIImage(systemName: "livephoto.fill")
        }
    }
    
    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .on:
            return "开启"
        }
    }
    
    func nextState() -> LivePhotoMode {
        switch self {
        case .off:
            return .on
        case .on:
            return .off
        }
    }
}

// 静音状态
enum MuteMode: ToolItemState {
    case off
    case on
    
    var icon: UIImage? {
        switch self {
        case .off:
            return UIImage(systemName: "speaker.fill")
        case .on:
            return UIImage(systemName: "speaker.slash.fill")
        }
    }
    
    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .on:
            return "开启"
        }
    }
    
    func nextState() -> MuteMode {
        switch self {
        case .off:
            return .on
        case .on:
            return .off
        }
    }
}

struct SCCameraToolItem {
    let type: SCCameraToolType
    var icon: UIImage?
    var title: String
    var isSelected: Bool
    var isEnabled: Bool
    var options: [String]?
    
    // 状态管理
    private var state: ToolItemState?
    
    init(type: SCCameraToolType, 
         state: ToolItemState? = nil,
         isSelected: Bool = false, 
         isEnabled: Bool = true, 
         options: [String]? = nil) {
        self.type = type
        self.state = state
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.options = type.supportsExpansion ? (options ?? []) : nil
        
        // 设置图标和标题
        if let state = state {
            self.icon = state.icon
            self.title = state.title
        } else {
            self.icon = type.defaultIcon
            self.title = type.defaultTitle
        }
    }
    
    // 状态切换
    mutating func toggleState() {
        guard type.supportsStateToggle else { return }
        
        switch type {
        case .flash:
            if var state = state as? FlashMode {
                state = state.nextState()
                self.state = state
                self.icon = state.icon
                self.title = state.title
            }
        case .livePhoto:
            if var state = state as? LivePhotoMode {
                state = state.nextState()
                self.state = state
                self.icon = state.icon
                self.title = state.title
            }
        case .mute:
            if var state = state as? MuteMode {
                state = state.nextState()
                self.state = state
                self.icon = state.icon
                self.title = state.title
            }
        default:
            break
        }
    }
    
    // 获取当前状态
    func getFlashMode() -> FlashMode? {
        return state as? FlashMode
    }
    
    func getLivePhotoMode() -> LivePhotoMode? {
        return state as? LivePhotoMode
    }
    
    func getMuteMode() -> MuteMode? {
        return state as? MuteMode
    }
} 