//
//  TestVC.swift
//  SparkCamera
//
//  Created by [Your Name] on [Date].
//

import UIKit

class TestVC: UIViewController {
    
    // MARK: - UI Components
    private lazy var testLabel: UILabel = {
        let label = UILabel()
        label.text = "This is a test view controller"
        label.textColor = .black
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .medium)
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(testLabel)
    }
    
    private func setupConstraints() {
        testLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            testLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            testLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
} 