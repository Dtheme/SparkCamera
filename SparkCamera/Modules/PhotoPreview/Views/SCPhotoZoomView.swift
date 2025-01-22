//
//  SCPhotoZoomView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  图片预览view



import UIKit
import SnapKit
import GPUImage

protocol SCPhotoZoomViewDelegate: AnyObject {
    func zoomViewDidTap(_ zoomView: SCPhotoZoomView)
    func zoomViewDidDoubleTap(_ zoomView: SCPhotoZoomView)
    func zoomViewDidLongPress(_ zoomView: SCPhotoZoomView)
    func zoomView(_ zoomView: SCPhotoZoomView, didPanWithProgress progress: CGFloat)
    func zoomViewDidEndPan(_ zoomView: SCPhotoZoomView, shouldDismiss: Bool)
}

class SCPhotoZoomView: UIScrollView {
    
    // MARK: - Properties
    weak var zoomDelegate: SCPhotoZoomViewDelegate?
    var gpuImageView: GPUImageView!
    private var lastZoomState: (scale: CGFloat, offset: CGPoint)?
    private var initialContentOffset: CGPoint = .zero
    private var panStartPoint: CGPoint = .zero
    private var isAnimating = false
    private var currentPicture: GPUImagePicture?
    
    var filterTemplate: SCFilterTemplate? {
        didSet {
            // 当 filterTemplate 改变时，重新应用滤镜
            if let image = image {
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
                    
                    guard let currentPicture = self.currentPicture else { return }
                    
                    // 配置 GPUImageView
                    self.gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
                    self.gpuImageView.backgroundColor = .clear
                    
                    if let filterTemplate = self.filterTemplate {
                        // 应用新的滤镜
                        filterTemplate.applyFilter(to: currentPicture, output: self.gpuImageView)
                    } else {
                        // 如果滤镜被清除，显示原图
                        currentPicture.addTarget(self.gpuImageView)
                        currentPicture.processImage()
                    }
                }
            }
        }
    }
    
    var image: UIImage? {
        didSet {
            if let image = image {
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
                    
                    guard let currentPicture = self.currentPicture else { return }
                    
                    // 配置 GPUImageView
                    self.gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
                    self.gpuImageView.backgroundColor = .clear
                    
                    if let filterTemplate = self.filterTemplate {
                        // 如果有滤镜模板，应用滤镜效果
                        filterTemplate.applyFilter(to: currentPicture, output: self.gpuImageView)
                    } else {
                        // 如果没有滤镜模板，直接显示原图
                        currentPicture.addTarget(self.gpuImageView)
                        currentPicture.processImage()
                    }
                    
                    // 更新布局
                    self.updateImageViewFrame()
                    self.centerImage()
                }
            } else {
                // 清理现有的渲染内容
                currentPicture?.removeAllTargets()
                currentPicture = nil
            }
        }
    }
    
    var isZoomed: Bool {
        return zoomScale > minimumZoomScale + 0.01
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 配置滚动视图
        super.delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        alwaysBounceVertical = true
        alwaysBounceHorizontal = true
        backgroundColor = .black
        
        // 设置 GPUImageView
        gpuImageView = GPUImageView()
        gpuImageView.backgroundColor = .clear
        gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
        addSubview(gpuImageView)
    }
    
    // MARK: - Gestures
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
        
        // 平移手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        if !isAnimating {
            updateImageViewFrame()
        }
    }
    
    private func updateImageViewFrame() {
        guard let image = image else { return }
        
        let imageSize = image.size
        let viewSize = bounds.size
        
        // 计算适合视图的图片大小
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let minScale = min(widthRatio, heightRatio)
        
        // 设置滚动视图的缩放范围
        minimumZoomScale = minScale
        maximumZoomScale = max(1.0, minScale) * 3.0
        
        // 如果还没有设置过缩放比例，设置为最小缩放比例
        if zoomScale == 0 || zoomScale < minimumZoomScale {
            zoomScale = minScale
        }
        
        // 计算实际显示尺寸
        let scaledWidth = imageSize.width * zoomScale
        let scaledHeight = imageSize.height * zoomScale
        
        // 直接设置 frame，不使用约束
        gpuImageView.frame = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        contentSize = CGSize(width: scaledWidth, height: scaledHeight)
        
        // 居中图片
        centerImage()
    }
    
    private func centerImage() {
        guard let image = image else { return }
        
        let imageSize = image.size
        let scaledSize = CGSize(
            width: imageSize.width * zoomScale,
            height: imageSize.height * zoomScale
        )
        
        // 计算内容边距
        let verticalInset = max(0, (bounds.height - scaledSize.height) / 2)
        let horizontalInset = max(0, (bounds.width - scaledSize.width) / 2)
        
        // 设置内容边距
        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        
        // 如果是最小缩放比例，重置偏移量
        if abs(zoomScale - minimumZoomScale) < 0.01 {
            contentOffset = .zero
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        zoomDelegate?.zoomViewDidTap(self)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        zoomDelegate?.zoomViewDidDoubleTap(self)
        
        if isZoomed {
            // 保存当前状态
            lastZoomState = (zoomScale, contentOffset)
            // 缩小到最小比例
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            if let lastState = lastZoomState {
                // 恢复上次的缩放状态
                isAnimating = true
                UIView.animate(withDuration: 0.3, animations: {
                    self.setZoomScale(lastState.scale, animated: false)
                    self.setContentOffset(lastState.offset, animated: false)
                }) { _ in
                    self.isAnimating = false
                }
            } else {
                // 放大到点击位置
                let location = gesture.location(in: gpuImageView)
                let zoomRect = calculateZoomRect(for: location)
                zoom(to: zoomRect, animated: true)
            }
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            zoomDelegate?.zoomViewDidLongPress(self)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isZoomed else { return }
        
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            panStartPoint = contentOffset
            initialContentOffset = contentOffset
            
        case .changed:
            let progress = abs(translation.y / bounds.height)
            zoomDelegate?.zoomView(self, didPanWithProgress: progress)
            
        case .ended, .cancelled:
            let shouldDismiss = abs(translation.y) > bounds.height * 0.3 || abs(velocity.y) > 500
            zoomDelegate?.zoomViewDidEndPan(self, shouldDismiss: shouldDismiss)
            
        default:
            break
        }
    }
    
    private func calculateZoomRect(for point: CGPoint) -> CGRect {
        let maxZoomScale = maximumZoomScale
        let currentScale = zoomScale
        let zoomFactor = maxZoomScale / currentScale
        
        let width = bounds.size.width / zoomFactor
        let height = bounds.size.height / zoomFactor
        let x = point.x - (width / 2)
        let y = point.y - (height / 2)
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Public Methods
    func resetZoom() {
        isAnimating = true
        UIView.animate(withDuration: 0.3, animations: {
            self.setZoomScale(self.minimumZoomScale, animated: false)
            self.contentOffset = .zero
        }) { _ in
            self.isAnimating = false
            self.lastZoomState = nil
        }
    }
    
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return gpuImageView
    }
}

// MARK: - UIScrollViewDelegate
extension SCPhotoZoomView: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if !isAnimating {
            centerImage()
        }
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if abs(scale - minimumZoomScale) < 0.01 {
            lastZoomState = nil
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SCPhotoZoomView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: self)
            // 只允许垂直方向的平移手势
            return abs(velocity.y) > abs(velocity.x)
        }
        return true
    }
}
