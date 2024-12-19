//
//  SCCameraVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import SwiftMessages
import AVFoundation

class SCCameraVC: UIViewController {
    
    // MARK: - Properties
    private var photoSession: SCPhotoSession!
    private var previewView: SCPreviewView!
    
    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.systemBlue.cgColor
        return button
    }()
    
    private lazy var switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private lazy var flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private lazy var gridButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "grid"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private lazy var focusView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.yellow.cgColor
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    private lazy var zoomIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 15
        view.isHidden = true
        return view
    }()
    
    private lazy var zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
    }
    
    // MARK: - Setup
    private func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupCamera()
                } else {
                    self?.showPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func setupCamera() {
        // 初始化相机会话
        photoSession = SCPhotoSession()
        
        // 创建预览视图
        previewView = SCPreviewView(frame: view.bounds)
        previewView.session = photoSession
        previewView.autorotate = true
        
        // 启用网格功能
        previewView.showGrid = false
        
        setupUI()
        setupConstraints()
        setupActions()
        
        // 设置代理以处理变焦回调
        photoSession.delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(previewView)
        view.addSubview(closeButton)
        view.addSubview(captureButton)
        view.addSubview(switchCameraButton)
        view.addSubview(flashButton)
        view.addSubview(gridButton)
        view.addSubview(focusView)
        
        // 添加��焦指示器
        view.addSubview(zoomIndicatorView)
        zoomIndicatorView.addSubview(zoomLabel)
    }
    
    private func setupConstraints() {
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.height.equalTo(44)
        }
        
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            make.width.height.equalTo(70)
        }
        
        switchCameraButton.snp.makeConstraints { make in
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalTo(captureButton)
            make.width.height.equalTo(44)
        }
        
        flashButton.snp.makeConstraints { make in
            make.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.centerY.equalTo(captureButton)
            make.width.height.equalTo(44)
        }
        
        gridButton.snp.makeConstraints { make in
            make.top.equalTo(closeButton)
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.width.height.equalTo(44)
        }
        
        zoomIndicatorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        zoomLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        gridButton.addTarget(self, action: #selector(toggleGrid), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func close() {
        dismiss(animated: true)
    }
    
    @objc private func capturePhoto() {
        // 添加拍照动画
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }
        
        photoSession.capture({ [weak self] image, _ in
            self?.handleCapturedImage(image)
        }, { [weak self] error in
            self?.showError(error)
        })
    }
    
    @objc private func switchCamera() {
        photoSession.cameraPosition = photoSession.cameraPosition == .front ? .back : .front
    }
    
    @objc private func toggleFlash() {
        switch photoSession.flashMode {
        case .off:
            photoSession.flashMode = .on
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        case .on:
            photoSession.flashMode = .auto
            flashButton.setImage(UIImage(systemName: "bolt"), for: .normal)
        case .auto:
            photoSession.flashMode = .off
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        }
    }
    
    @objc private func toggleGrid() {
        previewView.showGrid = !previewView.showGrid
        gridButton.tintColor = previewView.showGrid ? .yellow : .white
    }
    
    // MARK: - Helpers
    private func handleCapturedImage(_ image: UIImage) {
        // 保存照片到相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showError(error)
        } else {
            showSuccess("照片已保存到相册")
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "无法访问相机",
            message: "请在设置中允许访问相机",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.error)
        view.configureContent(title: "错误", body: error.localizedDescription)
        SwiftMessages.show(view: view)
    }
    
    private func showSuccess(_ message: String) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.configureContent(title: "成功", body: message)
        SwiftMessages.show(view: view)
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        focusView.center = point
        focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusView.isHidden = false
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5) {
                self.focusView.isHidden = true
            }
        }
    }
}

// MARK: - SCSessionDelegate
extension SCCameraVC: SCSessionDelegate {
    func didChangeValue(session: SCSession, value: Any, key: String) {
        if key == "zoom", let zoomValue = value as? Double {
            // 更新变焦指示器
            zoomLabel.text = String(format: "%.1fx", zoomValue)
            
            // 显示变焦指示器
            if zoomIndicatorView.isHidden {
                zoomIndicatorView.alpha = 0
                zoomIndicatorView.isHidden = false
                UIView.animate(withDuration: 0.2) {
                    self.zoomIndicatorView.alpha = 1
                }
            }
            
            // 延迟隐藏变焦指示器
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideZoomIndicator), object: nil)
            perform(#selector(hideZoomIndicator), with: nil, afterDelay: 1.5)
        }
    }
    
    // 将 hideZoomIndicator 方法移到 extension 内部
    @objc private func hideZoomIndicator() {
        UIView.animate(withDuration: 0.2) {
            self.zoomIndicatorView.alpha = 0
        } completion: { _ in
            self.zoomIndicatorView.isHidden = true
        }
    }
} 
