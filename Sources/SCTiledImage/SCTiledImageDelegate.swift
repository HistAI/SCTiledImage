//
//  SCTiledImageDelegate.swift
//  
//
//  Created by Yan Smaliak on 19/10/2023.
//

import Foundation

// MARK: - SCTiledImageDelegate

public protocol SCTiledImageDelegate: AnyObject {

    // MARK: - Internal Methods

    func defaultScaleSet(_ scale: CGFloat)
    func longPress(in location: CGPoint)
    func tap(in location: CGPoint)
    func centerOffsetChanged(to location: CGPoint)
    func imageTransformationChanged(_ isTransformed: Bool)
    func transformed(_ transform: Transform)
}
