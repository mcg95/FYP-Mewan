//
//  Utilities.swift
//  FYPTest1
//
//  Created by Mewan Chathuranga on 03/04/2018.
//  Copyright © 2018 Mewan Chathuranga. All rights reserved.
//

import Foundation
import ARKit

// Convert device orientation to image orientation for use by Vision analysis.
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}
