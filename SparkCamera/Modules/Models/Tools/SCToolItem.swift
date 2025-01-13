import UIKit

public class SCToolItem {
    public let type: SCToolType
    public private(set) var state: SCToolState?
    public let options: [SCToolOption]
    public var isSelected: Bool = false
    public var isEnabled: Bool = true
    private var sliderValue: Float = 0.0

    public init(type: SCToolType) {
        self.type = type
        self.options = type.defaultOptions
        self.state = options.first?.state
        
        // 初始化 sliderValue
        if let exposureState = state as? SCExposureState {
            self.sliderValue = exposureState.value
        } else if let isoState = state as? SCISOState {
            self.sliderValue = isoState.value
        }
    }
    
    public var icon: UIImage? {
        return state?.icon ?? type.defaultIcon
    }
    
    public var title: String {
        return state?.title ?? type.defaultTitle
    }
    
    public func setState(_ newState: SCToolState) {
        self.state = newState
        // 当设置新状态时，同步更新 sliderValue
        switch type {
        case .exposure:
            if let exposureState = newState as? SCExposureState {
                self.sliderValue = exposureState.value
            }
        case .iso:
            if let isoState = newState as? SCISOState {
                self.sliderValue = isoState.value
            }
        default:
            break
        }
    }
    
    public func getValue(for optionType: SCCameraToolOptionsViewType) -> Any? {
        switch optionType {
        case .scale:
            // 直接返回 sliderValue
            return sliderValue
        case .normal:
            return state
        }
    }
    
    public func setValue(_ value: Float, for optionType: SCCameraToolOptionsViewType) {
        switch optionType {
        case .scale:
            // 立即更新 sliderValue
            self.sliderValue = value
            
            // 根据工具类型更新状态
            switch type {
            case .exposure:
                if let exposureState = SCExposureState.custom(value: value) as? SCToolState {
                    self.state = exposureState
                }
            case .iso:
                if value == 0 {
                    if let autoState = SCISOState.auto as? SCToolState {
                        self.state = autoState
                    }
                } else {
                    if let iso100State = SCISOState.iso100 as? SCToolState {
                        self.state = iso100State
                    }
                }
            default:
                break
            }
            
        case .normal:
            // normal 类型不需要设置值
            break
        }
    }
    
    public func toggleState() {
        if let currentState = state as? SCFlashState {
            state = currentState.nextState()
        } else if let currentState = state as? SCLivePhotoState {
            state = currentState.nextState()
        }
    }
} 
