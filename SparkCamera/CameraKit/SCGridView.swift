//
//  SCGridView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/13.
//

import UIKit

public class SCGridView: UIView {
    
    private let lineWidth: CGFloat = 1.0
    private let lineColor: UIColor = .white.withAlphaComponent(0.5)
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 设置线条样式
        context.setLineWidth(lineWidth)
        context.setStrokeColor(lineColor.cgColor)
        
        // 计算网格线位置
        let width = rect.width
        let height = rect.height
        
        // 绘制水平线
        let horizontalSpacing = height / 3.0
        for i in 1...2 {
            let y = horizontalSpacing * CGFloat(i)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
        }
        
        // 绘制垂直线
        let verticalSpacing = width / 3.0
        for i in 1...2 {
            let x = verticalSpacing * CGFloat(i)
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: height))
        }
        
        // 绘制线条
        context.strokePath()
    }
} 
