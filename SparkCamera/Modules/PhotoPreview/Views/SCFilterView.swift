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
    
    // MARK: - Public Methods
    
    /// 获取处理后的图片（异步）
    func getFilteredImage(completion: @escaping (UIImage?) -> Void) {
        guard let picture = currentPicture,
              let image = originalImage else {
            print("[FilterView] 获取图片失败: currentPicture 或 originalImage 为空")
            completion(nil)
            return
        }
        
        print("[FilterView] 开始处理图片:")
        print("- 原始图片尺寸: \(image.size)")
        print("- 是否有滤镜模板: \(filterTemplate != nil)")
        
        // 如果没有滤镜模板，直接返回原图
        if filterTemplate == nil {
            print("[FilterView] 无滤镜模板，返回原图")
            completion(image)
            return
        }
        
        // 创建新的图片对象和输出目标
        let pictureOutput = GPUImagePicture(image: image)!
        let outputFilter = GPUImageFilter()
        
        // 配置输出
        outputFilter.useNextFrameForImageCapture()
        
        // 应用滤镜模板
        if let template = filterTemplate {
            print("[FilterView] 应用滤镜模板: \(template.name)")
            template.applyFilter(to: pictureOutput, output: outputFilter)
        } else {
            print("[FilterView] 无滤镜模板，直接连接输出")
            pictureOutput.addTarget(outputFilter)
        }
        
        // 处理图像并在完成后获取结果
        pictureOutput.processImage { [weak self] in
            guard self != nil else { return }
            
            // 获取处理后的图像
            if let processedImage = outputFilter.imageFromCurrentFramebuffer() {
                print("[FilterView] 成功获取处理后的图片:")
                print("- 处理后图片尺寸: \(processedImage.size)")
                print("- 处理后图片scale: \(processedImage.scale)")
                print("- 处理后图片orientation: \(processedImage.imageOrientation.rawValue)")
                
                // 清理资源
                pictureOutput.removeAllTargets()
                outputFilter.removeAllTargets()
                
                DispatchQueue.main.async {
                    completion(processedImage)
                }
            } else {
                print("[FilterView] 获取处理后的图片失败")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
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
                  let picture = self.currentPicture else { return }
            
            // 清理现有的渲染内容
            picture.removeAllTargets()
            
            // 应用新的滤镜
            if let template = self.filterTemplate {
                template.applyFilter(to: picture, output: self.gpuImageView)
            } else {
                // 如果没有滤镜，直接显示原图
                picture.addTarget(self.gpuImageView)
            }
            
            // 处理图像
            picture.processImage()
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
