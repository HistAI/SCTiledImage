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

    func shouldIgnorePanGesture() -> Bool
    func shouldIgnorePinchGesture() -> Bool
    func shouldIgnoreRotationGesture() -> Bool

    func didBeginTouches(at location: CGPoint)
    func didMoveTouches(to location: CGPoint)
    func didEndTouches(at location: CGPoint)

    func didChangeImageTransformation(_ isTransformed: Bool)
    func didApplyTransformation(_ transform: Transform)

    func didSetDefaultScale(to scale: CGFloat)
}
