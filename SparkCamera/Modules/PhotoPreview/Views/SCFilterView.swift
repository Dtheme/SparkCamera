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
    
    // 添加滤镜参数属性
    private var brightness: CGFloat = 0.0
    private var contrast: CGFloat = 1.0
    private var saturation: CGFloat = 1.0
    private var exposure: CGFloat = 0.0
    private var highlights: CGFloat = 0.0
    private var shadows: CGFloat = 0.0
    private var grain: CGFloat = 0.0
    private var sharpness: CGFloat = 0.0
    private var blur: CGFloat = 0.0
    private var glow: CGFloat = 0.0
    private var edgeStrength: CGFloat = 0.0
    private var redChannel: CGFloat = 1.0
    private var greenChannel: CGFloat = 1.0
    private var blueChannel: CGFloat = 1.0
    
    // 添加滤镜对象
    private var brightnessFilter: GPUImageBrightnessFilter?
    private var contrastFilter: GPUImageContrastFilter?
    private var saturationFilter: GPUImageSaturationFilter?
    private var exposureFilter: GPUImageExposureFilter?
    private var highlightsFilter: GPUImageHighlightShadowFilter?
    private var grainFilter: GPUImageJFAVoronoiFilter?  // 使用 Voronoi 滤镜模拟颗粒感
    private var sharpenFilter: GPUImageSharpenFilter?
    private var gaussianBlurFilter: GPUImageGaussianBlurFilter?
    private var sobelEdgeFilter: GPUImageSobelEdgeDetectionFilter?
    private var rgbFilter: GPUImageRGBFilter?
    
    var filterTemplate: SCFilterTemplate? {
        didSet {
            if let template = filterTemplate {
                // 更新所有参数
                brightness = template.parameters.brightness
                contrast = template.parameters.contrast
                saturation = template.parameters.saturation
                exposure = template.parameters.exposure
                highlights = template.parameters.highlights
                shadows = template.parameters.shadows
                grain = template.parameters.grain
                sharpness = template.parameters.sharpness
                blur = template.parameters.blur
                glow = template.parameters.glow
                edgeStrength = template.parameters.edgeStrength
                redChannel = template.parameters.red
                greenChannel = template.parameters.green
                blueChannel = template.parameters.blue
            }
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
        setupFilters()
        
        // 如果有模板，立即应用参数
        if let template = template {
            brightness = template.parameters.brightness
            contrast = template.parameters.contrast
            saturation = template.parameters.saturation
            exposure = template.parameters.exposure
            highlights = template.parameters.highlights
            shadows = template.parameters.shadows
            grain = template.parameters.grain
            sharpness = template.parameters.sharpness
            blur = template.parameters.blur
            glow = template.parameters.glow
            edgeStrength = template.parameters.edgeStrength
            redChannel = template.parameters.red
            greenChannel = template.parameters.green
            blueChannel = template.parameters.blue
        }
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
            
            // 如果没有滤镜，直接显示原图
            if self.filterTemplate == nil && self.allFiltersAtDefaultValues() {
                picture!.addTarget(self.gpuImageView)
                picture!.processImage()
            } else {
                // 应用滤镜
                self.applyFilter()
            }
        }
    }
    
    // 检查是否所有滤镜参数都是默认值
    private func allFiltersAtDefaultValues() -> Bool {
        return brightness == 0.0 &&
               contrast == 1.0 &&
               saturation == 1.0 &&
               exposure == 0.0 &&
               highlights == 0.0 &&
               shadows == 0.0 &&
               grain == 0.0 &&
               sharpness == 0.0 &&
               blur == 0.0 &&
               glow == 0.0 &&
               edgeStrength == 0.0 &&
               redChannel == 1.0 &&
               greenChannel == 1.0 &&
               blueChannel == 1.0
    }
    
    // MARK: - Filter Updates
    func updateBrightness(_ value: Float) {
        brightness = CGFloat(value)
        brightnessFilter?.brightness = brightness
        applyFilter()
    }
    
    func updateContrast(_ value: Float) {
        contrast = CGFloat(value)
        contrastFilter?.contrast = contrast
        applyFilter()
    }
    
    func updateSaturation(_ value: Float) {
        saturation = CGFloat(value)
        saturationFilter?.saturation = saturation
        applyFilter()
    }
    
    func updateExposure(_ value: Float) {
        exposure = CGFloat(value)
        exposureFilter?.exposure = exposure
        applyFilter()
    }
    
    func updateHighlights(_ value: Float) {
        highlights = CGFloat(value)
        highlightsFilter?.highlights = highlights
        applyFilter()
    }
    
    func updateShadows(_ value: Float) {
        shadows = CGFloat(value)
        highlightsFilter?.shadows = shadows
        applyFilter()
    }
    
    func updateGrain(_ value: Float) {
        grain = CGFloat(value)
        let size = CGFloat(value * 100)
        grainFilter?.sizeInPixels = CGSize(width: size, height: size)
        applyFilter()
    }
    
    func updateSharpness(_ value: Float) {
        sharpness = CGFloat(value)
        sharpenFilter?.sharpness = sharpness
        applyFilter()
    }
    
    func updateBlur(_ value: Float) {
        blur = CGFloat(value)
        gaussianBlurFilter?.blurRadiusInPixels = CGFloat(value * 10)
        applyFilter()
    }
    
    func updateGlow(_ value: Float) {
        glow = CGFloat(value)
        // 移除 glowFilter，因为 GPUImage 中没有这个滤镜
        applyFilter()
    }
    
    func updateEdgeStrength(_ value: Float) {
        edgeStrength = CGFloat(value)
        sobelEdgeFilter?.edgeStrength = edgeStrength
        applyFilter()
    }
    
    func updateRedChannel(_ value: Float) {
        redChannel = CGFloat(value)
        rgbFilter?.red = redChannel
        applyFilter()
    }
    
    func updateGreenChannel(_ value: Float) {
        greenChannel = CGFloat(value)
        rgbFilter?.green = greenChannel
        applyFilter()
    }
    
    func updateBlueChannel(_ value: Float) {
        blueChannel = CGFloat(value)
        rgbFilter?.blue = blueChannel
        applyFilter()
    }
    
    private func setupFilters() {
        // 创建滤镜对象
        brightnessFilter = GPUImageBrightnessFilter()
        contrastFilter = GPUImageContrastFilter()
        saturationFilter = GPUImageSaturationFilter()
        exposureFilter = GPUImageExposureFilter()
        highlightsFilter = GPUImageHighlightShadowFilter()
        grainFilter = GPUImageJFAVoronoiFilter()
        sharpenFilter = GPUImageSharpenFilter()
        gaussianBlurFilter = GPUImageGaussianBlurFilter()
        sobelEdgeFilter = GPUImageSobelEdgeDetectionFilter()
        rgbFilter = GPUImageRGBFilter()
        
        // 设置初始值
        brightnessFilter?.brightness = brightness
        contrastFilter?.contrast = contrast
        saturationFilter?.saturation = saturation
        exposureFilter?.exposure = exposure
        highlightsFilter?.highlights = highlights
        highlightsFilter?.shadows = shadows
        let grainSize = grain * 100
        grainFilter?.sizeInPixels = CGSize(width: grainSize, height: grainSize)
        sharpenFilter?.sharpness = sharpness
        gaussianBlurFilter?.blurRadiusInPixels = blur * 10
        sobelEdgeFilter?.edgeStrength = edgeStrength
        rgbFilter?.red = redChannel
        rgbFilter?.green = greenChannel
        rgbFilter?.blue = blueChannel
    }
    
    private func applyFilter() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let picture = self.currentPicture else { return }
            
            // 清理现有的渲染内容
            picture.removeAllTargets()
            
            // 如果有滤镜模板，使用模板的滤镜链
            if let template = self.filterTemplate {
                template.applyFilter(to: picture, output: self.gpuImageView)
                picture.processImage()
                return
            }
            
            // 否则使用自定义滤镜链
            let filterChain = [
                brightnessFilter,
                contrastFilter,
                saturationFilter,
                exposureFilter,
                highlightsFilter,
                grainFilter,
                sharpenFilter,
                gaussianBlurFilter,
                sobelEdgeFilter,
                rgbFilter
            ].compactMap { $0 }
            
            if filterChain.isEmpty {
                // 如果没有滤镜，直接显示原图
                picture.addTarget(self.gpuImageView)
            } else {
                // 连接滤镜链
                var previousFilter: GPUImageOutput = picture
                for filter in filterChain {
                    previousFilter.addTarget(filter)
                    previousFilter = filter
                }
                
                // 连接到输出
                previousFilter.addTarget(self.gpuImageView)
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
