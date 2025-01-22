import UIKit
import GPUImage
import SnapKit
import Photos

class TestVC: UIViewController {
    
    private lazy var filterView: SCFilterView = {
        let view = SCFilterView()
        view.delegate = self
        return view
    }()
    
    private lazy var filterOptionView: SCFilterOptionView = {
        let view = SCFilterOptionView(templates: SCFilterTemplate.templates)
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 设置FilterView
        view.addSubview(filterView)
        filterView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(filterView.snp.width).multipliedBy(4.0/3.0)
        }
        
        // 设置FilterOptionView
        view.addSubview(filterOptionView)
        filterOptionView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(120)
        }
    }
    
    private func loadImage() {
        guard let image = UIImage(named: "test_image2") else {
            print("无法加载测试图片")
            return
        }
        
        // 设置图片到FilterView
        filterView.setImage(image)
        
        // 更新滤镜列表 - 在初始化时已经设置了模板，不需要再次更新
        // filterOptionView.updateTemplates(SCFilterTemplate.templates)
    }
    
    @objc private func saveImageToAlbum() {
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            if status == .authorized {
                // 在主线程中获取滤镜后的图片
                DispatchQueue.main.async {
                    print("开始生成滤镜图片")
                    self.filterView.generateFilteredImageData { image in
                        if let image = image {
                            print("成功生成滤镜图片，尺寸：\(image.size)")
                            // 保存图片到相册
                            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                        } else {
                            print("生成滤镜图片失败")
                            self.showAlert(title: "保存失败", message: "无法生成滤镜图片")
                        }
                    }
                }
            } else {
                print("没有相册访问权限")
                DispatchQueue.main.async {
                    self.showAlert(title: "无法访问相册", message: "请在设置中允许访问相册")
                }
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                print("保存图片失败：\(error.localizedDescription)")
                self.showAlert(title: "保存失败", message: error.localizedDescription)
            } else {
                print("图片已保存到相册")
                self.showAlert(title: "保存成功", message: "图片已保存到相册")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SCFilterViewDelegate
extension TestVC: SCFilterViewDelegate {
    func filterView(_ filterView: SCFilterView, didChangeFilter template: SCFilterTemplate?) {
        // 处理滤镜变化
    }
    
    func filterViewDidTap(_ filterView: SCFilterView) {
        // 处理点击事件
    }
    
    func filterViewDidDoubleTap(_ filterView: SCFilterView) {
        // 处理双击事件
    }
    
    func filterViewDidLongPress(_ filterView: SCFilterView) {
        // 长按保存图片
        saveImageToAlbum()
    }
}

// MARK: - SCFilterOptionViewDelegate
extension TestVC: SCFilterOptionViewDelegate {
    func filterOptionView(_ filterOptionView: SCFilterOptionView, didSelectTemplate template: SCFilterTemplate) {
        // 应用选中的滤镜
        filterView.filterTemplate = template
    }
} 