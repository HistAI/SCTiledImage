//
//  SCDrawableTile.swift
//  SCTiledImage
//
//  Created by Maxime POUWELS on 13/09/16.
//  Copyright © 2016 Siclo. All rights reserved.
//

import UIKit

// MARK: - SCDrawableTile

final class SCDrawableTile {

    // MARK: - Internal Properties

    let tileRect: CGRect
    var image: UIImage?

    var hasImage: Bool {
        image != nil
    }

    // MARK: - Life Cycle

    init(rect: CGRect) {
        tileRect = rect
    }

    // MARK: - Internal Methods

    func draw() {
        image?.draw(in: tileRect, blendMode: .normal, alpha: 1.0)
    }
}
