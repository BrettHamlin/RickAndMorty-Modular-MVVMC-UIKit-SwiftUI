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
        try await Task.sleep(nanoseconds: 300_000_000)

        return [
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
                name: "Squanchy",
                status: .unknown,
                species: "Cat-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/331.jpeg"
            ),
            Character(
                id: 5,
                name: "Summer Smith",
                status: .alive,
                species: "Human",
                gender: "Female",
                image: "https://rickandmortyapi.com/api/character/avatar/3.jpeg"
            ),
            Character(
                id: 6,
                name: "Beth Smith",
                status: .alive,
                species: "Human",
                gender: "Female",
                image: "https://rickandmortyapi.com/api/character/avatar/4.jpeg"
            ),
            Character(
                id: 7,
                name: "Jerry Smith",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/5.jpeg"
            ),
            Character(
                id: 8,
                name: "Abadango Cluster Princess",
                status: .alive,
                species: "Alien",
                gender: "Female",
                image: "https://rickandmortyapi.com/api/character/avatar/6.jpeg"
            ),
            Character(
                id: 9,
                name: "Abradolf Lincler",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/7.jpeg"
            ),
            Character(
                id: 10,
                name: "Adjudicator Rick",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/8.jpeg"
            ),
            Character(
                id: 11,
                name: "Agency Director",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/9.jpeg"
            ),
            Character(
                id: 12,
                name: "Alan Rails",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/10.jpeg"
            ),
            Character(
                id: 13,
                name: "Albert Einstein",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/11.jpeg"
            ),
            Character(
                id: 14,
                name: "Alexander",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/12.jpeg"
            )
        ]
    }
}
