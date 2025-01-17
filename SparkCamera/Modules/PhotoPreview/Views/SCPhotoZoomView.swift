//
//  SCPhotoZoomView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  图片预览view



import UIKit
import SnapKit

protocol SCPhotoZoomViewDelegate: AnyObject {
    func zoomViewDidTap(_ zoomView: SCPhotoZoomView)
    func zoomViewDidDoubleTap(_ zoomView: SCPhotoZoomView)
    func zoomViewDidLongPress(_ zoomView: SCPhotoZoomView)
    func zoomView(_ zoomView: SCPhotoZoomView, didPanWithProgress progress: CGFloat)
    func zoomViewDidEndPan(_ zoomView: SCPhotoZoomView, shouldDismiss: Bool)
}

class SCPhotoZoomView: UIView {
    
    // MARK: - Properties
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        scrollView.bouncesZoom = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    // 记录上一次的缩放状态
    private var lastZoomState: (scale: CGFloat, offset: CGPoint)?
    // 记录缩放开始时的状态
    private var zoomStartState: (center: CGPoint, scale: CGFloat)?
    // 记录当前捏合手势的中心点
    private var pinchCenter: CGPoint?
    
    // 添加新的属性
    private var panGesture: UIPanGestureRecognizer!
    private var initialTouchPoint: CGPoint = .zero
    private var initialImageCenter: CGPoint = .zero
    
    weak var delegate: SCPhotoZoomViewDelegate?
    
    var image: UIImage? {
        didSet {
            imageView.image = image
            updateImageViewLayout()
        }
    }
    
    var isZoomed: Bool {
        return scrollView.zoomScale > scrollView.minimumZoomScale
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
    
    // MARK: - Setup
    private func setupUI() {
        addSubview(scrollView)
        scrollView.delegate = self
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        scrollView.addSubview(imageView)
    }
    
    private func setupGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        addGestureRecognizer(singleTap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)
        
        // 添加平移手势
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        addGestureRecognizer(panGesture)
        
        singleTap.require(toFail: doubleTap)
    }
    
    // MARK: - Layout
    private func updateImageViewLayout() {
        guard let image = imageView.image else { return }
        
        let screenSize = bounds.size
        let imageSize = image.size
        
        // 计算适合屏幕的图片尺寸
        let screenRatio = screenSize.width / screenSize.height
        let imageRatio = imageSize.width / imageSize.height
        
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        if imageRatio > screenRatio {
            displayWidth = screenSize.width
            displayHeight = displayWidth / imageRatio
        } else {
            displayHeight = screenSize.height
            displayWidth = displayHeight * imageRatio
        }
        
        // 更新图片视图尺寸和位置
        imageView.frame = CGRect(
            x: 0,
            y: 0,
            width: displayWidth,
            height: displayHeight
        )
        
        // 更新滚动视图内容
        scrollView.contentSize = imageView.frame.size
        
        // 计算最小缩放比例
        let minScale = min(screenSize.width / displayWidth, screenSize.height / displayHeight)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = 3.0
        scrollView.zoomScale = minScale
        
        // 居中显示
        centerImage()
    }
    
    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        // 水平方向居中
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) * 0.5
        } else {
            frameToCenter.origin.x = 0
        }
        
        // 垂直方向居中
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) * 0.5
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
    
    // MARK: - Gestures
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.zoomViewDidTap(self)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // 当前已放大，恢复到上一次的位置或最小缩放
            print("📸 [ZoomView] 双击缩小:")
            print("📸 [ZoomView] - 当前缩放比例: \(scrollView.zoomScale)")
            print("📸 [ZoomView] - 目标缩放比例: \(scrollView.minimumZoomScale)")
            
            // 保存当前状态
            lastZoomState = (scrollView.zoomScale, scrollView.contentOffset)
            
            // 使用transform动画来实现更平滑的缩放效果
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
                self.scrollView.contentOffset = .zero
            }) { _ in
                self.scrollView.contentInset = .zero
            }
        } else {
            // 如果有上一次的缩放状态，恢复到该状态
            if let lastState = lastZoomState {
                print("📸 [ZoomView] 双击恢复上一次状态:")
                print("📸 [ZoomView] - 上一次缩放比例: \(lastState.scale)")
                print("📸 [ZoomView] - 上一次偏移: \(lastState.offset)")
                
                let currentCenter = CGPoint(
                    x: scrollView.contentOffset.x + scrollView.bounds.width / 2,
                    y: scrollView.contentOffset.y + scrollView.bounds.height / 2
                )
                
                UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
                    self.scrollView.zoomScale = lastState.scale
                    
                    // 计算新的中心点
                    let newCenter = CGPoint(
                        x: lastState.offset.x + self.scrollView.bounds.width / 2,
                        y: lastState.offset.y + self.scrollView.bounds.height / 2
                    )
                    
                    // 计算偏移量
                    let contentOffsetX = newCenter.x - self.scrollView.bounds.width / 2
                    let contentOffsetY = newCenter.y - self.scrollView.bounds.height / 2
                    
                    self.scrollView.contentOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
                }) { _ in
                    self.lastZoomState = nil
                }
            } else {
                // 放大到指定位置
                let location = gesture.location(in: imageView)
                let targetScale = scrollView.maximumZoomScale * 0.7
                
                print("📸 [ZoomView] 双击放大:")
                print("📸 [ZoomView] - 点击位置: \(location)")
                print("📸 [ZoomView] - 当前缩放比例: \(scrollView.zoomScale)")
                print("📸 [ZoomView] - 目标缩放比例: \(targetScale)")
                
                // 计算目标区域
                let width = scrollView.bounds.width / targetScale
                let height = scrollView.bounds.height / targetScale
                
                let x = location.x - width * 0.5
                let y = location.y - height * 0.5
                
                let zoomRect = CGRect(
                    x: max(0, min(x, imageView.bounds.width - width)),
                    y: max(0, min(y, imageView.bounds.height - height)),
                    width: width,
                    height: height
                )
                
                print("📸 [ZoomView] - 缩放区域: \(zoomRect)")
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
        
        delegate?.zoomViewDidDoubleTap(self)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            delegate?.zoomViewDidLongPress(self)
        }
    }
    
    // 添加平移手势处理方法
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let touchPoint = gesture.location(in: window)
        
        switch gesture.state {
        case .began:
            initialTouchPoint = touchPoint
            initialImageCenter = imageView.center
            
        case .changed:
            let translation = CGPoint(
                x: touchPoint.x - initialTouchPoint.x,
                y: touchPoint.y - initialTouchPoint.y
            )
            
            // 更新图片位置
            imageView.center = CGPoint(
                x: initialImageCenter.x + translation.x,
                y: initialImageCenter.y + translation.y
            )
            
            // 计算进度
            let progress = abs(translation.y) / bounds.height
            delegate?.zoomView(self, didPanWithProgress: min(1.0, progress))
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self)
            let translation = gesture.translation(in: self)
            
            // 判断是否应该关闭
            let shouldDismiss = abs(translation.y) > bounds.height * 0.3 || abs(velocity.y) > 1000
            
            if shouldDismiss {
                delegate?.zoomViewDidEndPan(self, shouldDismiss: true)
            } else {
                // 恢复到原始位置
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut, animations: {
                    self.imageView.center = self.initialImageCenter
                }) { _ in
                    self.delegate?.zoomViewDidEndPan(self, shouldDismiss: false)
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Public Methods
    func resetZoom(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
        } else {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageViewLayout()
    }
    
    // MARK: - Private Methods
    private func updateScrollViewInsets() {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size
        
        // 计算内边距，确保图片居中
        let verticalInset = max((scrollViewSize.height - imageViewSize.height) * 0.5, 0)
        let horizontalInset = max((scrollViewSize.width - imageViewSize.width) * 0.5, 0)
        
        // 设置新的内边距
        let newInsets = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        
        // 只有当内边距发生变化时才更新
        if newInsets != scrollView.contentInset {
            scrollView.contentInset = newInsets
            
            // 如果存在捏合手势中心点，保持其相对位置不变
            if let center = pinchCenter {
                let beforeZoom = scrollView.convert(center, from: self)
                let beforeZoomPercent = CGPoint(
                    x: beforeZoom.x / scrollView.contentSize.width,
                    y: beforeZoom.y / scrollView.contentSize.height
                )
                
                // 计算新的偏移量
                let newContentOffsetX = beforeZoomPercent.x * scrollView.contentSize.width - center.x
                let newContentOffsetY = beforeZoomPercent.y * scrollView.contentSize.height - center.y
                
                // 限制偏移量在有效范围内
                let minOffsetX = -scrollView.contentInset.left
                let maxOffsetX = max(-scrollView.contentInset.left, scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right)
                let minOffsetY = -scrollView.contentInset.top
                let maxOffsetY = max(-scrollView.contentInset.top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
                
                scrollView.contentOffset = CGPoint(
                    x: max(minOffsetX, min(maxOffsetX, newContentOffsetX)),
                    y: max(minOffsetY, min(maxOffsetY, newContentOffsetY))
                )
            } else if scrollView.zoomScale == scrollView.minimumZoomScale {
                scrollView.contentOffset = .zero
            }
        }
    }
}

// MARK: - UIScrollViewDelegate
extension SCPhotoZoomView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // 获取捏合手势的中心点
        if let pinchGesture = scrollView.pinchGestureRecognizer {
            pinchCenter = pinchGesture.location(in: self)
        }
    }

    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // 清除捏合手势中心点
        pinchCenter = nil
        
        // 如果是最小缩放比例，重置所有状态
        if scale == scrollView.minimumZoomScale {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
                self.scrollView.contentInset = .zero
                self.scrollView.contentOffset = .zero
            })
        }
    }
}
