//
//  LikesViewSingletonModel.swift
//  overlokfilm2
//
//  Created by hyasar on 26.12.2022.
//

import Foundation

final class LikesViewSingletonModel{
    
    static let sharedInstance = LikesViewSingletonModel()
    
    var postId = ""
    
    private init(){}
    
}
