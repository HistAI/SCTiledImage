//
//  SCTiledImageContentView.swift
//  SCTiledImage
//
//  Created by Maxime POUWELS on 14/09/16.
//  Copyright © 2016 Siclo. All rights reserved.
//

import UIKit

// MARK: - SCTiledImageContentView

public final class SCTiledImageContentView: UIView {

    // MARK: - Private Properties

    private let tiledImageView: SCTiledImageView
    private let backgroundImageView: UIImageView

    // MARK: - Life Cycle

    public init(dataSource: SCTiledImageViewDataSource) {
        tiledImageView = SCTiledImageView()
        tiledImageView.setup(dataSource: dataSource)
        backgroundImageView = UIImageView(frame: tiledImageView.bounds)

        super.init(frame: tiledImageView.frame)

        backgroundImageView.contentMode = .scaleAspectFit

        Task {
            let image = await dataSource.backgroundImage()

            await MainActor.run {
                backgroundImageView.image = image
            }
        }

        addSubview(backgroundImageView)
        addSubview(tiledImageView)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
