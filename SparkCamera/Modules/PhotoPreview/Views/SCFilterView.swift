//
//  SCFilterView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/21.
//

import UIKit
import GPUImage

protocol SCFilterViewDelegate: AnyObject {
    func filterViewDidTap(_ filterView: SCFilterView)
    func filterViewDidDoubleTap(_ filterView: SCFilterView)
    func filterViewDidLongPress(_ filterView: SCFilterView)
    func filterView(_ filterView: SCFilterView, didChangeFilter template: SCFilterTemplate?)
}

class SCFilterView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCFilterViewDelegate?
    private var gpuImageView: GPUImageView!
    private var currentPicture: GPUImagePicture?
    private var originalImage: UIImage?
    
    var filterTemplate: SCFilterTemplate? {
        didSet {
            applyFilter()
            delegate?.filterView(self, didChangeFilter: filterTemplate)
        }
    }
    
    // 获取当前渲染后的图片
    var currentImage: UIImage? {
        // 创建当前尺寸的上下文
        let scale = UIScreen.main.scale
        let size = gpuImageView.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        // 将 GPUImageView 的内容渲染到上下文
        if let context = UIGraphicsGetCurrentContext() {
            gpuImageView.layer.render(in: context)
        }
        
        // 获取图片并关闭上下文
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    // 获取处理后的图片
    func captureFilteredImage() -> UIImage? {
        guard let picture = currentPicture,
              let image = originalImage else { return nil }
        
        // 如果没有滤镜模板，直接输出原图
        if filterTemplate == nil {
            return originalImage
        }
        
        // 创建一个临时的 GPUImageView 用于捕获
        let outputView = GPUImageView()
        outputView.frame = CGRect(origin: .zero, size: image.size)
        outputView.fillMode = kGPUImageFillModePreserveAspectRatio
        
        // 创建新的图片对象，避免影响当前显示
        let pictureOutput = GPUImagePicture(image: image)!
        
        // 应用当前的滤镜模板
        if let template = filterTemplate {
            template.applyFilter(to: pictureOutput, output: outputView)
        } else {
            pictureOutput.addTarget(outputView)
        }
        
        // 处理图片
        pictureOutput.processImage()
        
        // 从 outputView 中获取处理后的图片
        let scale = UIScreen.main.scale
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        if let context = UIGraphicsGetCurrentContext() {
            outputView.layer.render(in: context)
        }
        
        let processedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 清理资源
        pictureOutput.removeAllTargets()
        
        return processedImage
    }
    
    // 生成处理后的图片数据
    func generateFilteredImageData(completion: @escaping (UIImage?) -> Void) {
        guard let image = originalImage else {
            completion(nil)
            return
        }
        
        // 如果没有滤镜模板，直接返回原图
        if filterTemplate == nil {
            completion(originalImage)
            return
        }
        
        // 从当前显示的 gpuImageView 中获取图像
        let scale = UIScreen.main.scale
        let size = gpuImageView.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        if let context = UIGraphicsGetCurrentContext() {
            gpuImageView.layer.render(in: context)
            let processedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            completion(processedImage)
        } else {
            UIGraphicsEndImageContext()
            completion(nil)
        }
    }
    
    // MARK: - Initialization
    init(frame: CGRect = .zero, template: SCFilterTemplate? = nil) {
        self.filterTemplate = template
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .black
        
        // 设置 GPUImageView
        gpuImageView = GPUImageView()
        gpuImageView.backgroundColor = .clear
        gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
        addSubview(gpuImageView)
        
        gpuImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        // 单击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // 双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        
        // 设置手势优先级
        tapGesture.require(toFail: doubleTapGesture)
        
        // 长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Public Methods
    func setImage(_ image: UIImage) {
        self.originalImage = image
        
        // 在主线程中设置 GPUImageView 的属性
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 清理现有的渲染内容
            self.currentPicture?.removeAllTargets()
            
            // 根据图片方向创建正确的图片
            let correctedImage: UIImage
            if image.imageOrientation != .up {
                UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
                image.draw(in: CGRect(origin: .zero, size: image.size))
                correctedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else {
                correctedImage = image
            }
            
            // 创建新的 GPUImagePicture
            let picture = GPUImagePicture(image: correctedImage)
            self.currentPicture = picture
            
            // 应用滤镜或显示原图
            self.applyFilter()
        }
    }
    
    // MARK: - Private Methods
    private func applyFilter() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let currentPicture = self.currentPicture else { return }
            
            // 清理现有的渲染内容
            currentPicture.removeAllTargets()
            
            // 配置 GPUImageView
            self.gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
            
            if let filterTemplate = self.filterTemplate {
                // 如果有滤镜模板，应用滤镜效果
                filterTemplate.applyFilter(to: currentPicture, output: self.gpuImageView)
            } else {
                // 如果没有滤镜模板，直接显示原图
                currentPicture.addTarget(self.gpuImageView)
                currentPicture.processImage()
            }
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.filterViewDidTap(self)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.filterViewDidDoubleTap(self)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            delegate?.filterViewDidLongPress(self)
        }
    }
    
    // MARK: - Memory Management
    deinit {
        // 清理资源
        currentPicture?.removeAllTargets()
        currentPicture = nil
        originalImage = nil
    }
} 
