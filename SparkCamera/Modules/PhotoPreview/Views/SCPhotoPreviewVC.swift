// MARK: - SCFilterOptionViewDelegate
extension SCPhotoPreviewVC: SCFilterOptionViewDelegate {
    func filterOptionView(_ view: SCFilterOptionView, didSelectTemplate template: SCFilterTemplate) {
        // 应用滤镜
        filterView.filterTemplate = template
        
        // 更新调整视图的参数值
        filterAdjustView.updateParameters(template.toParameters())
    }
}

private func setupFilterOptionView() {
    // 初始化滤镜选择器
    filterOptionView = SCFilterOptionView()
    filterOptionView.delegate = self
    filterOptionView.templates = SCFilterTemplate.templates
    view.addSubview(filterOptionView)
    
    // 设置布局约束
    filterOptionView.snp.makeConstraints { make in
        make.left.right.equalToSuperview()
        make.height.equalTo(100)
        make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
    }
} 