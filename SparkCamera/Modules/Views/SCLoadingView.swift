//
//  SCLoadingView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit

class SCLoadingView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.layer.cornerRadius = 12
        view.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        return view
    }()
    
    private let shapeLayer = CAShapeLayer()
    private var textPath: CGPath?
    private let horizontalPadding: CGFloat = 30  // 文字两边的内边距
    
    init(message: String) {
        super.init(frame: .zero)
        setupUI(with: message)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(with message: String) {
        backgroundColor = .clear
        
        // 计算文字宽度
        let font = CTFontCreateWithName("ProFontForPowerline" as CFString, 16, nil) ?? CTFontCreateWithName("HelveticaNeue" as CFString, 16, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 0.5
        ]
        let attributedString = NSAttributedString(string: message, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        // 添加容器视图
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(bounds.width + horizontalPadding * 2)  // 文字宽度加上两边内边距
            make.height.equalTo(50)
        }
        
        // 配置形状层
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
        shapeLayer.lineWidth = 0.5
        shapeLayer.lineCap = .round
         shapeLayer.lineJoin = .round
        shapeLayer.fillRule = .nonZero
        containerView.layer.addSublayer(shapeLayer)
        
        // 等待布局完成后创建路径
        DispatchQueue.main.async { [weak self] in
            self?.createTextPath(for: message)
            self?.startAnimation()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = containerView.bounds
    }
    
    private func createTextPath(for text: String) {
        // 使用系统字体以支持中文，改用常规字重
        let font = CTFontCreateWithName("ProFontForPowerline" as CFString, 16, nil)
        
        // 如果PingFang字体不可用，回退到系统字体
        let fallbackFont = font ?? CTFontCreateWithName("HelveticaNeue" as CFString, 16, nil)
        
        // 创建属性字符串
        let attrString = NSAttributedString(
            string: text,
            attributes: [
                .font: fallbackFont,
                .kern: 0.5
            ]
        )
        
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        let textPath = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        
        // 计算文本位置（居中）
        let containerBounds = containerView.bounds
        let xOffset = horizontalPadding  // 使用固定的左边距
        
        // 重新计算垂直位置
        let fontAscent = CTFontGetAscent(fallbackFont)
        let fontDescent = CTFontGetDescent(fallbackFont)
        let fontHeight = fontAscent + fontDescent
        let yOffset = containerBounds.height / 2 + fontAscent / 2
        
        for run in runs {
            let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
            let runFont = attributes[.font] as! CTFont
            
            let count = CTRunGetGlyphCount(run)
            let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: count)
            let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: count)
            
            CTRunGetGlyphs(run, CFRangeMake(0, count), glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), positions)
            
            for i in 0..<count {
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    var transform = CGAffineTransform(translationX: xOffset + positions[i].x,
                                                    y: yOffset + positions[i].y)
                    transform = transform.scaledBy(x: 1, y: -1)
                    
                    // 创建一个新的路径来处理当前字形
                    let currentGlyphPath = CGMutablePath()
                    currentGlyphPath.addPath(glyphPath, transform: transform)
                    
                    // 使用非零缠绕规则填充路径
                    let bezierPath = UIBezierPath()
                    bezierPath.append(UIBezierPath(cgPath: currentGlyphPath))
                    bezierPath.usesEvenOddFillRule = false
                    
                    // 将处理后的路径添加到总路径中
                    textPath.addPath(bezierPath.cgPath)
                }
            }
            
            glyphs.deallocate()
            positions.deallocate()
        }
        
        self.textPath = textPath
        shapeLayer.path = textPath
        
        // 设置填充规则
        shapeLayer.fillRule = .nonZero
    }
    
    private func startAnimation() {
        // 描边动画
        let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeAnimation.fromValue = 0
        strokeAnimation.toValue = 1
        strokeAnimation.duration = 1.0
        strokeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 填充动画
        let fillAnimation = CABasicAnimation(keyPath: "fillColor")
        fillAnimation.fromValue = UIColor.clear.cgColor
        fillAnimation.toValue = UIColor.white.withAlphaComponent(0.6).cgColor
        fillAnimation.duration = 0.3
        fillAnimation.beginTime = strokeAnimation.duration
        fillAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fillAnimation.fillMode = .forwards
        
        // 保持填充状态的延时动画
        let holdAnimation = CABasicAnimation(keyPath: "fillColor")
        holdAnimation.fromValue = UIColor.white.withAlphaComponent(0.6).cgColor
        holdAnimation.toValue = UIColor.white.withAlphaComponent(0.6).cgColor
        holdAnimation.duration = 3.0
        holdAnimation.beginTime = strokeAnimation.duration + fillAnimation.duration
        
        // 清除填充的动画
        let clearFillAnimation = CABasicAnimation(keyPath: "fillColor")
        clearFillAnimation.fromValue = UIColor.white.withAlphaComponent(0.6).cgColor
        clearFillAnimation.toValue = UIColor.clear.cgColor
        clearFillAnimation.duration = 0.3
        clearFillAnimation.beginTime = strokeAnimation.duration + fillAnimation.duration + holdAnimation.duration
        
        // 组合动画
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [strokeAnimation, fillAnimation, holdAnimation, clearFillAnimation]
        groupAnimation.duration = strokeAnimation.duration + fillAnimation.duration + holdAnimation.duration + clearFillAnimation.duration
        groupAnimation.repeatCount = .infinity
        groupAnimation.fillMode = .forwards
        groupAnimation.isRemovedOnCompletion = false
        
        shapeLayer.add(groupAnimation, forKey: "loading")
    }
    
    func show(in view: UIView) {
        view.addSubview(self)
        self.alpha = 0
        
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
