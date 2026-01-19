//
//  Logging.swift
//  Dream_Catcher
//
//  Created by Arseny Prostakov on 14/01/2026.
//

import Foundation

func log(_ msg: String) {
    #if DEBUG
    print("[Dream Catcher] \(msg)")
    #endif
}
