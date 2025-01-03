import UIKit

public class SCToolItem {
    public let type: SCToolType
    public private(set) var state: SCToolState?
    public let options: [SCToolOption]
    public var isSelected: Bool = false
    public var isEnabled: Bool = true
    
    public init(type: SCToolType) {
        self.type = type
        self.options = type.defaultOptions
        self.state = options.first?.state
    }
    
    public var icon: UIImage? {
        return state?.icon ?? type.defaultIcon
    }
    
    public var title: String {
        return state?.title ?? type.defaultTitle
    }
    
    public func setState(_ newState: SCToolState) {
        self.state = newState
    }
    
    public func toggleState() {
        if let currentState = state as? SCFlashState {
            state = currentState.nextState()
        } else if let currentState = state as? SCLivePhotoState {
            state = currentState.nextState()
        }
    }
} 