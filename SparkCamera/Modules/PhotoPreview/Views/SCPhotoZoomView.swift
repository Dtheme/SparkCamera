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
    
    private var lastZoomScale: CGFloat = 1.0
    private var panGesture: UIPanGestureRecognizer!
    private var initialTouchPoint: CGPoint = .zero
    private var initialImageCenter: CGPoint = .zero
    private var initialImageTransform: CGAffineTransform = .identity
    
    weak var delegate: SCPhotoZoomViewDelegate?
    
    var image: UIImage? {
        didSet {
            imageView.image = image
            if let _ = image {
                resetZoom(animated: false)
                updateImageViewLayout()
            }
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
        addGestureRecognizer(longPress)
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        addGestureRecognizer(panGesture)
        
        singleTap.require(toFail: doubleTap)
    }
    
    // MARK: - Layout
    private func updateImageViewLayout() {
        guard let image = imageView.image else { return }
        
        let viewSize = bounds.size
        let imageSize = image.size
        
        let scaleWidth = viewSize.width / imageSize.width
        let scaleHeight = viewSize.height / imageSize.height
        let minScale = min(scaleWidth, scaleHeight)
        
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 3.0, 1.0)
        
        let width = imageSize.width * minScale
        let height = imageSize.height * minScale
        
        imageView.frame = CGRect(
            x: (viewSize.width - width) / 2,
            y: (viewSize.height - height) / 2,
            width: width,
            height: height
        )
        
        scrollView.contentSize = viewSize
        scrollView.zoomScale = minScale
        centerImage()
    }
    
    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        imageView.frame = frameToCenter
    }
    
    // MARK: - Gestures
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.zoomViewDidTap(self)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // 缩小到原始大小
            UIView.animate(withDuration: 0.25) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
        } else {
            // 放大到指定位置
            let location = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(scale: scrollView.maximumZoomScale * 0.7, center: location)
            scrollView.zoom(to: zoomRect, animated: true)
        }
        
        delegate?.zoomViewDidDoubleTap(self)
    }
    
    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        let bounds = scrollView.bounds
        
        zoomRect.size.width = bounds.size.width / scale
        zoomRect.size.height = bounds.size.height / scale
        
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2)
        
        return zoomRect
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            delegate?.zoomViewDidLongPress(self)
        }
    }
    
    // 添加平移手势处理方法
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard !isZoomed else { return }  // 如果图片已放大，不处理拖拽
        
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            // 记录初始状态
            initialImageCenter = imageView.center
            initialImageTransform = imageView.transform
            
        case .changed:
            // 计算垂直和水平移动距离
            let verticalDelta = translation.y
            let horizontalDelta = translation.x
            
            // 计算缩放比例（随着下拉逐渐缩小）
            let scale = max(0.5, 1 - abs(verticalDelta) / 1000)
            
            // 应用变换
            var transform = initialImageTransform
            transform = transform.scaledBy(x: scale, y: scale)
            imageView.transform = transform
            
            // 更新位置（水平方向有阻尼效果）
            imageView.center = CGPoint(
                x: initialImageCenter.x + horizontalDelta * 0.7,
                y: initialImageCenter.y + verticalDelta
            )
            
            // 计算并通知代理进度
            let progress = min(1.0, abs(verticalDelta) / bounds.height)
            delegate?.zoomView(self, didPanWithProgress: progress)
            
        case .ended, .cancelled:
            let shouldDismiss = abs(translation.y) > bounds.height * 0.25 || abs(velocity.y) > 800
            
            if shouldDismiss {
                // 使用当前速度计算动画时间
                let velocity = max(abs(velocity.y), 800)
                let duration = 0.25 * (bounds.height / velocity)
                
                // 添加消失动画
                UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
                    // 继续向移动方向移动并缩小
                    let direction = translation.y > 0 ? 1.0 : -1.0
                    self.imageView.center = CGPoint(
                        x: self.initialImageCenter.x,
                        y: self.initialImageCenter.y + direction * self.bounds.height
                    )
                    self.imageView.transform = self.imageView.transform.scaledBy(x: 0.5, y: 0.5)
                }) { _ in
                    self.delegate?.zoomViewDidEndPan(self, shouldDismiss: true)
                }
            } else {
                // 恢复到原始状态
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut, animations: {
                    self.imageView.center = self.initialImageCenter
                    self.imageView.transform = self.initialImageTransform
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
}

// MARK: - UIScrollViewDelegate
extension SCPhotoZoomView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        lastZoomScale = scale
    }
}
