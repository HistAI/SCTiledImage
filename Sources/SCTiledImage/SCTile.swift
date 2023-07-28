//
//  SCTile.swift
//  SCTiledImage
//
//  Created by Yan Smaliak on 05/07/2023.
//

import UIKit

// MARK: - SCTile

public class SCTile {

    // MARK: - Public Properties

    public let level: Int
    public let column: Int
    public let row: Int

    // MARK: - Life Cycle

    public init(level: Int, column: Int, row: Int) {
        self.level = level
        self.column = column
        self.row = row
    }
}
