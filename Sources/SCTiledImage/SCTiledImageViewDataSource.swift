//
//  SCTiledImageDataSource.swift
//  SCTiledImage
//
//  Created by Maxime POUWELS on 15/09/16.
//  Copyright © 2016 Siclo. All rights reserved.
//

import UIKit

// MARK: - SCTiledImageViewDataSource

public protocol SCTiledImageViewDataSource: AnyObject {

    // MARK: - Internal Properties

    var delegate: SCTiledImageViewDataSourceDelegate? { get set }
    var imageSize: CGSize { get }
    var tileSize: CGSize { get }
    var zoomLevels: Int { get }

    // MARK: - Internal Methods

    func backgroundImage() async -> UIImage?
    func tileImage(for tile: SCTile) async -> UIImage?
}

// MARK: - SCTiledImageViewDataSourceDelegate

public protocol SCTiledImageViewDataSourceDelegate: AnyObject {

    // MARK: - Internal Methods

    func didRetrieve(image: UIImage, for tile: SCTile)
}
