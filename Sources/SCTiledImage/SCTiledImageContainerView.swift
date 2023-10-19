//
//  SCTiledImageContainerView.swift
//  SCTiledImage
//
//  Created by Yan Smaliak on 05/07/2023.
//

import UIKit

// MARK: - SCTiledImageContainerView

public final class SCTiledImageContainerView: UIView {

    // MARK: - Internal Properties

    var contentView: SCTiledImageContentView?
    var dataSource: SCTiledImageViewDataSource?

    // MARK: - Internal Methods

    func setup(dataSource: SCTiledImageViewDataSource) {
        self.dataSource = dataSource
        contentView = SCTiledImageContentView(dataSource: dataSource)
        frame = contentView!.frame

        if let contentView {
            if !subviews.contains(contentView) {
                addSubview(contentView)
            }
            contentView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
}
