//
//  SCPreviewView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import AVFoundation

@objc public class SCPreviewView: UIView {
    
    private var lastScale: CGFloat = 1.0
    
    @objc private(set) public var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            
            if let previewLayer = previewLayer {
                self.layer.addSublayer(previewLayer)
            }
        }
    }
    
    @objc public var session: SCSession? {
        didSet {
            oldValue?.stop()
            
            if let session = session {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: session.session)
                session.previewLayer = self.previewLayer
                session.overlayView = self
                session.start()
            }
        }
    }
    
    @objc private(set) public var gridView: SCGridView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let gridView = self.gridView {
                self.addSubview(gridView)
            }
        }
    }
    
    @objc public var showGrid: Bool = false {
        didSet {
            if self.showGrid == oldValue {
                return
            }
            
            if self.showGrid {
                self.gridView = SCGridView(frame: self.bounds)
            } else {
                self.gridView = nil
            }
        }
    }
    
    @objc public var autorotate: Bool = false {
        didSet {
            if !self.autorotate {
                self.previewLayer?.connection?.videoOrientation = .portrait
            }
        }
    }
    
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
    }
    
    private func setupView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(recognizer:)))
        self.addGestureRecognizer(pinchGestureRecognizer)
    }
    
    @objc private func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        if let point = self.previewLayer?.captureDevicePointConverted(fromLayerPoint: location) {
            self.session?.focus(at: point)
        }
    }
    
    @objc private func handlePinch(recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            recognizer.scale = self.lastScale
        }
        
        var minZoom: CGFloat = 1.0
        if let session = self.session, session.isWideAngleAvailable {
            minZoom = 0.5
        }
        
        let zoom = max(minZoom, min(10.0, recognizer.scale))
        self.session?.zoom = Double(zoom)
        
        if recognizer.state == .ended {
            self.lastScale = zoom
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer?.frame = self.bounds
        self.gridView?.frame = self.bounds
        
        if self.autorotate {
            self.previewLayer?.connection?.videoOrientation = UIDevice.current.orientation.videoOrientation
        }
    }
}
