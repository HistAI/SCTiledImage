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

    private let tiledImageView: SCTiledImageView = {
        let view = SCTiledImageView()
        return view
    }()

    private let backgroundImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    // MARK: - Initializers

    public init(dataSource: SCTiledImageViewDataSource) {
        super.init(frame: .zero)

        tiledImageView.setup(dataSource: dataSource)
        frame = tiledImageView.frame
        fetchBackgroundImage(from: dataSource)
        setupSubviews()
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Helpers

    private func fetchBackgroundImage(from dataSource: SCTiledImageViewDataSource) {
        Task { [weak self] in
            if let image = await dataSource.backgroundImage() {
                await MainActor.run {
                    self?.backgroundImageView.image = image
                    self?.backgroundImageView.frame = self?.tiledImageView.bounds ?? .zero
                }
            }
        }
    }

    private func setupSubviews() {
        addSubview(backgroundImageView)
        addSubview(tiledImageView)
    }
}

