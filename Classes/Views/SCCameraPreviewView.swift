import UIKit
import AVFoundation

class SCCameraPreviewView: UIView {
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
    
    func convertToPointOfInterest(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
} 