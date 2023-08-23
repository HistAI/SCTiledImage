//
//  SCTiledImageView.swift
//  SCTiledImage
//
//  Created by Maxime POUWELS on 13/09/16.
//  Copyright © 2016 Siclo. All rights reserved.
//

import UIKit

// MARK: - SCTiledImageView

public final class SCTiledImageView: UIView {

    // MARK: - Public Properties

    override public class var layerClass: AnyClass {
        ZeroFadeTiledLayer.self
    }

    // MARK: - Private Properties

    private class func cacheKey(forLevel level: Int, column: Int, row: Int) -> String {
        "\(level)-\(column)-\(row)"
    }

    private var dataSource: SCTiledImageViewDataSource!
    private let tileCache = NSCache<NSString, SCDrawableTile>()

    // MARK: - Life Cycle

    override public func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        let scaleX = context.ctm.a / UIScreen.main.scale
        let scaleY = context.ctm.d / UIScreen.main.scale

        let tiledLayer = layer as! CATiledLayer

        var tileSize = tiledLayer.tileSize
        tileSize.width = round(tileSize.width / scaleX)
        tileSize.height = round(-tileSize.height / scaleY)

        let level = -Int(round(log2(Float(scaleX))))

        let firstCol = Int(floor(rect.minX / tileSize.width))
        let lastCol = Int(floor((rect.maxX - 1) / tileSize.width))
        let firstRow = Int(floor(rect.minY / tileSize.height))
        let lastRow = Int(floor((rect.maxY - 1) / tileSize.height))

        var tilesToRequest: [SCTile] = []

        for rowInt in firstRow...lastRow {
            let row = CGFloat(rowInt)

            for columnInt in firstCol...lastCol {
                let col = CGFloat(columnInt)

                let cacheKey = SCTiledImageView.cacheKey(forLevel: level, column: columnInt, row: rowInt)
                var missingImageRect: CGRect?

                if let cachedDrawableTile = tileCache.object(forKey: cacheKey as NSString) as SCDrawableTile? {
                    if cachedDrawableTile.hasImage {
                        cachedDrawableTile.draw()
                    } else {
                        missingImageRect = cachedDrawableTile.tileRect
                    }
                } else {
                    let x = tileSize.width * col
                    let y = tileSize.height * row
                    let width = tileSize.width
                    let height = tileSize.height
                    var tileRect = CGRect(x: x, y: y, width: width, height: height)
                    tileRect = bounds.intersection(tileRect)

                    let drawableTile = SCDrawableTile(rect: tileRect)
                    let tile = SCTile(level: level, column: columnInt, row: rowInt)

                    missingImageRect = tileRect
                    tilesToRequest.append(tile)
                    tileCache.setObject(drawableTile, forKey: cacheKey as NSString, cost: level)
                }

                if let unwrappedMissingImageRect = missingImageRect {
                    drawLowerResTileIfAvailableAtHigherLevel(
                        ofLevel: level,
                        column: columnInt,
                        row: rowInt,
                        tileSize: tiledLayer.tileSize,
                        tileRect: unwrappedMissingImageRect
                    )
                }
            }
        }

        if !tilesToRequest.isEmpty {
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for tile in tilesToRequest {
                        group.addTask { [weak self] in
                            guard let image = await self?.dataSource.tileImage(for: tile) else { return }

                            await MainActor.run { [weak self] in
                                self?.dataSource.delegate?.didRetrieve(image: image, for: tile)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Public Methods

    public func setup(dataSource: SCTiledImageViewDataSource) {
        clipsToBounds = true
        backgroundColor = UIColor.clear

        self.dataSource = dataSource
        dataSource.delegate = self

        let layer = self.layer as! CATiledLayer
        layer.levelsOfDetail = dataSource.zoomLevels
        layer.levelsOfDetailBias = 0

        var tileSize = dataSource.tileSize

        if tileSize == CGSize.zero {
            tileSize = dataSource.imageSize
        }

        layer.tileSize = tileSize

        let imageSize = dataSource.imageSize

        frame = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
    }

    // MARK: - Private Methods

    private func drawLowerResTileIfAvailableAtHigherLevel(
        ofLevel zoomLevel: Int,
        column: Int,
        row: Int,
        tileSize: CGSize,
        tileRect: CGRect
    ) {
        guard zoomLevel + 1 <= dataSource.zoomLevels - 1 else { return }

        for level in zoomLevel + 1...dataSource.zoomLevels - 1 {
            let zoomDifference = level - zoomLevel
            let scaleDifference = zoomDifference * 2
            let zoomColumn = column / scaleDifference
            let zoomRow = row / scaleDifference

            let cacheKey = SCTiledImageView.cacheKey(forLevel: level, column: zoomColumn, row: zoomRow)

            var tileImage: UIImage?
            if let lowerResTile = tileCache.object(forKey: cacheKey as NSString) as SCDrawableTile? {
                tileImage = lowerResTile.image
            }

            guard let image = tileImage, let cgImage = image.cgImage else { continue }

            let cropColumn = column % scaleDifference
            let cropRow = row % scaleDifference
            let scaleDifferenceFloat = CGFloat(scaleDifference)

            let size = CGSize(width: tileSize.width / scaleDifferenceFloat, height: tileSize.height / scaleDifferenceFloat)
            let cropBounds = CGRect(
                x: CGFloat(cropColumn) * size.width,
                y: CGFloat(cropRow) * size.height,
                width: size.width,
                height: size.height
            )

            if let resizedImage = cgImage.cropping(to: cropBounds) {
                UIImage(cgImage: resizedImage).draw(in: tileRect)
            }

            break
        }
    }
}

// MARK: - SCTiledImageView (SCTiledImageViewDataSourceDelegate)

extension SCTiledImageView: SCTiledImageViewDataSourceDelegate {

    // MARK: - Internal Methods

    public func didRetrieve(image: UIImage, for tile: SCTile) {
        let cacheKey = SCTiledImageView.cacheKey(forLevel: tile.level, column: tile.column, row: tile.row)

        if let cachedTile = tileCache.object(forKey: cacheKey as NSString) as SCDrawableTile? {
            cachedTile.image = image
            setNeedsDisplay(cachedTile.tileRect)
        }
    }
}
