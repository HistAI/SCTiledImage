//
//  ZeroFadeTiledLayer.swift
//  SCTiledImage
//
//  Created by Yan Smaliak on 05/07/2023.
//

import UIKit

// MARK: - ZeroFadeTiledLayer

final class ZeroFadeTiledLayer: CATiledLayer {

    // MARK: - Internal Methods

    override class func fadeDuration() -> CFTimeInterval {
        0
    }
}
