//
//  File.swift
//  HomeViewModel
//
//  Created by rico on 22.01.2026.
//

import Foundation
import Core
import Domain
import SwiftUI

public enum CharacterStatusFilter: CaseIterable, Identifiable, Sendable {
    case all
    case alive
    case dead
    case unknown
    
    public var id: Self { self }
    
    var title: String {
        switch self {
        case .all:
            return "All"
        case .alive:
            return "Alive"
        case .dead:
            return "Dead"
        case .unknown:
            return "Unknown"
        }
    }
}

@MainActor
public final class HomeViewModel: ObservableObject {
    
    @Published public var state: HomeViewState = .loading
    @Published public var selectedFilter: CharacterStatusFilter = .all
    
    public var onDetailRequested: ((Character) -> Void)?
    
    @Inject private var repository: CharacterRepositoryProtocol
    
    public init() {}
    
    public var filteredCharacters: [Character] {
        guard case .success(let characters) = state else {
            return []
        }
        
        switch selectedFilter {
        case .all:
            return characters
        case .alive:
            return characters.filter { $0.status == .alive }
        case .dead:
            return characters.filter { $0.status == .dead }
        case .unknown:
            return characters.filter { $0.status == .unknown }
        }
    }
    
    public func fetchCharacters() {
        state = .loading
        Task {
            do {
                let result = try await repository.fetchCharacters()
                if result.isEmpty {
                    state = .failure("Karakter listesi boş geldi.")
                } else {
                    state = .success(result)
                }
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }
    
    // View'daki butona basılınca bu çalışır
    public func didSelect(character: Character) {
        // Coordinator'a "Patron, detay istendi" diye haber verir
        onDetailRequested?(character)
    }
}

extension CharacterStatusType {
    var color: Color {
        switch self {
        case .alive:
            return .green
        case .dead:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .alive: return "heart.fill"
        case .dead: return "heart.slash.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
