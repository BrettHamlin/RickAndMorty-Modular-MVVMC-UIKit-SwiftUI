//
//  HomeViewState.swift
//  FeatureHome
//
//  Created by rico on 22.01.2026.
//

import Foundation
import Domain

public enum HomeViewState: Equatable, Sendable {
    case loading
    case success([Character])
    case failure(String)
}
