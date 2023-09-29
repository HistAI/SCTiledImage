//
//  Transform.swift
//  
//
//  Created by Yan Smaliak on 28/09/2023.
//

import Foundation

// MARK: - Transform

public enum Transform {

    // MARK: - Cases

    case scale(CGFloat)
    case zoom(CGFloat)
    case rotation(CGFloat)
    case none
}
