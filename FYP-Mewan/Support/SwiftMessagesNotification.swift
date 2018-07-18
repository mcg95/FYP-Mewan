//
//  SwiftMessagesNotification.swift
//  FYP-Mewan
//
//  Created by Mewan Chathuranga on 16/07/2018.
//  Copyright © 2018 Mewan Chathuranga. All rights reserved.
//

import Foundation
import SwiftMessages

class SwiftMessagesNotification{
    var swiftMsgView: MessageView? = nil

    func displayNotification(layout: MessageView.Layout, title: String, body: String, presentationStyle: SwiftMessages.PresentationStyle, iconText: String, backgroundColor: UIColor ){
        //Config view
        swiftMsgView = MessageView.viewFromNib(layout: layout)
        swiftMsgView?.configureContent(title: title, body: body)
        let iconText = iconText
        swiftMsgView?.configureTheme(backgroundColor: backgroundColor, foregroundColor: UIColor.white, iconImage: nil, iconText: iconText)
        // self.swiftMsgView?.button?.setImage(Icon.errorSubtle.image, for: .normal)
        swiftMsgView?.button?.setTitle("Hide", for: .normal)
        swiftMsgView?.button?.backgroundColor = UIColor.clear
        swiftMsgView?.button?.tintColor = UIColor.white
        swiftMsgView?.configureDropShadow()
        
        //Config
        var swiftConfig = SwiftMessages.defaultConfig
        swiftConfig.interactiveHide = true
        swiftConfig.presentationStyle = presentationStyle
        swiftConfig.duration = .automatic
        
        //Show
        SwiftMessages.show(config: swiftConfig, view: self.swiftMsgView!)
    }
}
