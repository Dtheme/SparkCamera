import Foundation
import AVFoundation

struct SCLensModel {
    var name: String
    var type: AVCaptureDevice.DeviceType
    var lastZoomFactor: CGFloat? // 确保 lastZoomFactor 是 var
}
