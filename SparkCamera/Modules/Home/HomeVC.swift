//
//  HomeVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit

class HomeVC: UIViewController {
    
    // MARK: - UI Components
    private lazy var cameraButton: UIButton = {

        let button = UIButton(type: .system)
        button.setTitle("打开相机", for: .normal)
        button.titleLabel?.font = UIFont.mainFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return button
    }()
    
    private lazy var labButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("相机实验室", for: .normal)
        button.titleLabel?.font = UIFont.mainFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 25
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "SparkCamera"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(titleLabel)
        view.addSubview(cameraButton)
        view.addSubview(labButton)
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(50)
        }
        
        cameraButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
        
        labButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(cameraButton.snp.bottom).offset(20)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
    }
    
    private func setupActions() {
        cameraButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        labButton.addTarget(self, action: #selector(openLab), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func openCamera() {
        let cameraVC = SCCameraVC()
        cameraVC.modalPresentationStyle = .fullScreen
        present(cameraVC, animated: true)
    }
    
    @objc private func openLab() {
        let labVC = TestVC()
        let nav = UINavigationController(rootViewController: labVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
} 
