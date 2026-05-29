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
                id: 47,
                name: "Birdperson",
                status: .dead,
                species: "Bird-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/47.jpeg"
            ),
            Character(
                id: 331,
                name: "Squanchy",
                status: .unknown,
                species: "Cat-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/331.jpeg"
            )
        ]
    }
}
