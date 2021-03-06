//
//  PickerPreviewNavigationBar.swift
//  AnyImageKit
//
//  Created by 蒋惠 on 2019/9/17.
//  Copyright © 2019 AnyImageProject.org. All rights reserved.
//

import UIKit

final class PickerPreviewNavigationBar: UIView {
    
    private(set) lazy var backButton: UIButton = {
        let view = UIButton(type: .custom)
        let image = BundleHelper.image(named: "ReturnButton", style: options.theme.style)
        view.setImage(image, for: .normal)
        view.imageEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        view.accessibilityLabel = BundleHelper.pickerLocalizedString(key: "Back")
        return view
    }()
    private(set) lazy var selectButton: NumberCircleButton = {
        let view = NumberCircleButton(frame: .zero, style: .large)
        return view
    }()
    
    private let options: PickerOptionsInfo
    
    init(frame: CGRect, options: PickerOptionsInfo) {
        self.options = options
        super.init(frame: frame)
        backgroundColor = UIColor.create(style: options.theme.style,
                                         light: options.theme.toolBarColor,
                                         dark: options.theme.backgroundColor)
            .withAlphaComponent(0.95)
        setupView()
        selectButton.setTheme(options.theme)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        let contentView = UILayoutGuide()
        addLayoutGuide(contentView)
        addSubview(backButton)
        addSubview(selectButton)
        contentView.snp.makeConstraints { maker in
            maker.left.right.bottom.equalToSuperview()
            maker.height.equalTo(44)
        }
        backButton.snp.makeConstraints { maker in
            maker.left.equalToSuperview().offset(8)
            maker.centerY.equalTo(contentView)
            maker.width.height.equalTo(44)
        }
        selectButton.snp.makeConstraints { maker in
            maker.right.equalToSuperview().offset(-4)
            maker.centerY.equalTo(contentView)
            maker.width.height.equalTo(45)
        }
    }
}
