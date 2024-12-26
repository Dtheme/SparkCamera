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
import CoreMotion

class SCCameraVC: UIViewController {
    
    // MARK: - Properties
    private var photoSession: SCPhotoSession!
    private var previewView: SCPreviewView!
    private var cameraManager: SCCameraManager!
    private lazy var lensSelectorView = SCLensSelectorView()
    private let motionManager = CMMotionManager()
    private let horizontalIndicator = SCHorizontalIndicatorView()
    private var isHorizontalIndicatorVisible = true
    
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
        button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
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
        setupHorizontalIndicator()
    }  
    
    private func setupHorizontalIndicator() {
        view.addSubview(horizontalIndicator)
        view.bringSubviewToFront(horizontalIndicator)
        horizontalIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(4)
        }
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleHorizontalIndicator))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let motion = motion else { return }
                let rotation = atan2(motion.gravity.x, motion.gravity.y) - .pi
                self?.horizontalIndicator.updateRotation(angle: CGFloat(rotation))
            }
        }
    }

    override func viewDidLayoutSubviews() {
        self.view.bringSubviewToFront(horizontalIndicator)
    }

    @objc private func toggleHorizontalIndicator() {
        isHorizontalIndicatorVisible.toggle()
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible

        let message = isHorizontalIndicatorVisible ? "水平仪已开启" : "水平仪已关闭"
        print(message)
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(isHorizontalIndicatorVisible ? .success : .warning)
        view.configureContent(title: "提示", body: message)
        SwiftMessages.show(view: view)
        
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()

//        horizontalIndicator.isHidden = false
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
        
        // 初始化 cameraManager
        cameraManager = SCCameraManager(session: photoSession)
        
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
        
        // 设置镜头选择器
        setupLensSelector()
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
        view.addSubview(lensSelectorView)
        
        // 添加变焦指示器
        view.addSubview(zoomIndicatorView)
        zoomIndicatorView.addSubview(zoomLabel)
        setupLensSelector()
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
    
    private func setupLensSelector() {
        // 获取可用镜头选项
        let availableLensOptions = cameraManager.getAvailableLensOptions()
        
        // 确保有可用的镜头选项
        guard !availableLensOptions.isEmpty else {
            print("No available lens options")
            return
        }
        
        // 打印获取到的镜头信息
        for lens in availableLensOptions {
            print("Lens Name: \(lens.name), Type: \(lens.type)")
        }
        
        // 设置默认选中的镜头为 1.0x
        let defaultLens = availableLensOptions.first(where: { $0.name == "1x" })
        
        // 更新 lensSelectorView 的显示内容并设置默认选中
        lensSelectorView.updateLensOptions(availableLensOptions, currentLens: defaultLens)
        
        // 确保 lensSelectorView 和 captureButton 都被添加到 view 中
        view.addSubview(lensSelectorView)
        view.addSubview(captureButton) // 确保 captureButton 也在同一个父视图中

        lensSelectorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(captureButton.snp.top).offset(-20)
            make.height.equalTo(50)
            make.width.equalTo(200)
        }
        
        // 设置镜头选择回调
        lensSelectorView.onLensSelected = { [weak self] lensName in
            guard let lens = availableLensOptions.first(where: { $0.name == lensName }) else { return }
            self?.handleLensSelection(lens)
        }
    }
    
    private func handleLensSelection(_ lens: SCLensModel) {
        cameraManager.switchCamera(to: lens) { [weak self] message in
            DispatchQueue.main.async {
                self?.showCameraSwitchMessage(message)
            }
        }
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
        let isCurrentlyBackCamera = cameraManager.currentCameraPosition == .back
        let newLens: SCLensModel
        
        if isCurrentlyBackCamera {
            newLens = SCLensModel(name: "Front", type: .builtInWideAngleCamera)
        } else {
            // 切换回后置摄像头时，恢复到前一次选中的镜头
            newLens = cameraManager.getLastSelectedLens() ?? SCLensModel(name: "1x", type: .builtInWideAngleCamera)
        }
        
        cameraManager.switchCamera(to: newLens) { [weak self] message in
            DispatchQueue.main.async {
                self?.showCameraSwitchMessage(message)
                
                // 触觉反馈
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                feedbackGenerator.impactOccurred()
                
                // 只有在成功切换到前置摄像头时才隐藏 lensSelectorView
                if newLens.name == "Front" {
                    UIView.animate(withDuration: 0.3, animations: {
                        self?.lensSelectorView.alpha = 0
                        self?.lensSelectorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    }) { _ in
                        self?.lensSelectorView.isHidden = true
                    }
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self?.lensSelectorView.alpha = 1
                        self?.lensSelectorView.transform = .identity
                    }) { _ in
                        self?.lensSelectorView.isHidden = false
                    }
                }
            }
        }
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
    
    private func showCameraSwitchMessage(_ message: String) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.configureContent(title: "镜头切换", body: message)
        SwiftMessages.show(view: view)
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
