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
    public var currentZoomFactor: CGFloat = 1.0
    public var maxZoomFactor: CGFloat = 15.0
    
    @objc public var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            
            if let previewLayer = previewLayer {
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = self.bounds
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
                
                // 初始化时设置 maxZoomFactor
                if let lensName = session.currentLens?.name {
                    switch lensName {
                    case "0.5x":
                        self.maxZoomFactor = 2.0
                        print("0.5x lens maxZoomFactor set to \(self.maxZoomFactor)")
                    case "1x":
                        self.maxZoomFactor = 2.96
                        print("1x lens maxZoomFactor set to \(self.maxZoomFactor)")
                    case "3x":
                        self.maxZoomFactor = 15.0
                        print("3x lens maxZoomFactor set to \(self.maxZoomFactor)")
                    default:
                        self.maxZoomFactor = 2.96
                    }
                }
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
    
    private var zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        return label
    }()
    
    internal let focusBox = SCFocusBoxView()

    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
    }
    
    private func setupView() {
        // 添加变焦倍数指示器
        self.addSubview(zoomLabel)
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            zoomLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            zoomLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 100),
            zoomLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // 添加对焦框
        self.addSubview(focusBox)
        self.bringSubviewToFront(focusBox)
    }
}

