//
//  AppConfigurator.swift
//  RickAndMortyHybrid
//
//  Created by rico on 22.01.2026.
//

import Foundation
import Core
import Infrastructure
import Data
import Domain

final class AppConfigurator {
    static let shared = AppConfigurator()
    
    private init() {}
    
    func configure() {
        print("AppConfigurator: Dependencies installing. ..")
        if ProcessInfo.processInfo.arguments.contains("--uitesting-loading") {
            ServiceLocator.shared.register(UITestingLoadingCharacterRepository() as CharacterRepositoryProtocol)
            return
        }

        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            ServiceLocator.shared.register(UITestingCharacterRepository() as CharacterRepositoryProtocol)
            return
        }

        let networkManager = NetworkManager()
        let characterRepository = CharacterRepository(networkManager: networkManager)
        ServiceLocator.shared.register(characterRepository as CharacterRepositoryProtocol)
    }
}

private struct UITestingCharacterRepository: CharacterRepositoryProtocol {
    func fetchCharacters() async throws -> [Character] {
        [
            Character(
                id: 1,
                name: "Rick Sanchez",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
            ),
            Character(
                id: 2,
                name: "Morty Smith",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/2.jpeg"
            ),
            Character(
                id: 3,
                name: "Birdperson",
                status: .dead,
                species: "Bird-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/47.jpeg"
            ),
            Character(
                id: 4,
                name: "Dr. Wong",
                status: .unknown,
                species: "Human",
                gender: "Female",
                image: "https://rickandmortyapi.com/api/character/avatar/120.jpeg"
            )
        ]
    }
}

private struct UITestingLoadingCharacterRepository: CharacterRepositoryProtocol {
    func fetchCharacters() async throws -> [Character] {
        try await Task.sleep(nanoseconds: UInt64.max)
        return []
    }
}
