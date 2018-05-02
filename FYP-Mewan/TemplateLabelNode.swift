//
//  TemplateLabelNode.swift
//  FYPTest1
//
//  Created by Mewan Chathuranga on 03/04/2018.
//  Copyright © 2018 Mewan Chathuranga. All rights reserved.
//

import SpriteKit

class TemplateLabelNode: SKReferenceNode {
    
    private let text: String
    
    init(text: String) {
        self.text = text
        // Force call to designated init(fileNamed: String?), not convenience init(fileNamed: String)
        super.init(fileNamed: Optional.some("LabelScene"))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad(_ node: SKNode?) {
        // Apply text to both labels loaded from the template.
        guard let parent = node?.childNode(withName: "LabelNode") else {
            fatalError("misconfigured SpriteKit template file")
        }
        for case let label as SKLabelNode in parent.children {
            label.name = text
            label.text = text
        }
    }
}
