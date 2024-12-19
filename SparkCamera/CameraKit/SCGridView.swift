//
//  SCGridView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit

@objc public class SCGridView: UIView {
    
    @objc public var color: UIColor = UIColor.white.withAlphaComponent(0.5) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
    }
    
    private func setupView() {
        self.backgroundColor = UIColor.clear
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        context.setStrokeColor(self.color.cgColor)
        context.setLineWidth(1.0)
        
        let pairs: [[CGPoint]] = [
            [CGPoint(x: rect.width / 3.0, y: rect.minY), CGPoint(x: rect.width / 3.0, y: rect.maxY)],
            [CGPoint(x: 2 * rect.width / 3.0, y: rect.minY), CGPoint(x: 2 * rect.width / 3.0, y: rect.maxY)],
            [CGPoint(x: rect.minX, y: rect.height / 3.0), CGPoint(x: rect.maxX, y: rect.height / 3.0)],
            [CGPoint(x: rect.minX, y: 2 * rect.height / 3.0), CGPoint(x: rect.maxX, y: 2 * rect.height / 3.0)]
        ]
        
        for pair in pairs {
            context.addLines(between: pair)
        }
        
        context.strokePath()
    }
}
