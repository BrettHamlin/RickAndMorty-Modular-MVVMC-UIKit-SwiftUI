import XCTest
import Core
import Domain
@testable import FeatureHome

final class HomeViewModelFilterTests: XCTestCase {
    private var repository: MockCharacterRepository!

    override func setUp() {
        super.setUp()
        repository = MockCharacterRepository(characters: Self.mixedCharacters)
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
    }

    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        repository = nil
        super.tearDown()
    }

    @MainActor
    func testFilterTypeHasFourCasesAndDefaultsToAll() {
        //harness:criterion=c-filter-enum-four-cases,c-filter-default-all,c-unit-test-file-exists
        let viewModel = HomeViewModel()
        let selectedFilter: CharacterStatusFilter = viewModel.selectedFilter

        XCTAssertEqual(CharacterStatusFilter.allCases.count, 4)
        XCTAssertEqual(Set(CharacterStatusFilter.allCases), [.all, .alive, .dead, .unknown])
        XCTAssertEqual(CharacterStatusFilter.allCases.map(\.rawValue), ["All", "Alive", "Dead", "Unknown"])
        XCTAssertEqual(selectedFilter, .all)
    }

    @MainActor
    func testAllFilterPublishesEveryFetchedCharacter() async {
        //harness:criterion=c-filter-all-shows-all-characters
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        viewModel.selectedFilter = .all

        let characters = await waitForSuccess(from: viewModel)
        XCTAssertEqual(characters.map(\.id), Self.mixedCharacters.map(\.id))
        XCTAssertEqual(Set(characters.map(\.status)), [.alive, .dead, .unknown])
    }

    @MainActor
    func testStatusFiltersPublishOnlyMatchingCharacters() async {
        //harness:criterion=c-filter-alive-shows-alive-only,c-filter-dead-shows-dead-only,c-filter-unknown-shows-unknown-only
        let cases: [(filter: CharacterStatusFilter, status: CharacterStatusType, ids: [Int])] = [
            (.alive, .alive, [1]),
            (.dead, .dead, [2]),
            (.unknown, .unknown, [3])
        ]

        for testCase in cases {
            ServiceLocator.shared.unregisterAll()
            repository = MockCharacterRepository(characters: Self.mixedCharacters)
            ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)

            let viewModel = HomeViewModel()
            viewModel.fetchCharacters()
            _ = await waitForSuccess(from: viewModel)

            viewModel.selectedFilter = testCase.filter

            let characters = await waitForSuccess(from: viewModel)
            XCTAssertEqual(characters.map(\.id), testCase.ids)
            XCTAssertTrue(characters.allSatisfy { $0.status == testCase.status })
            XCTAssertEqual(repository.fetchCallCount, 1)
        }
    }

    @MainActor
    func testChangingFilterDoesNotRefetchAndRestoresFullArray() async {
        //harness:criterion=c-filter-change-no-refetch,c-filter-full-array-retained
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await waitForSuccess(from: viewModel)

        viewModel.selectedFilter = .alive
        _ = await waitForSuccess(from: viewModel)
        viewModel.selectedFilter = .dead
        _ = await waitForSuccess(from: viewModel)
        XCTAssertEqual(repository.fetchCallCount, 1)

        viewModel.selectedFilter = .all
        let restoredCharacters = await waitForSuccess(from: viewModel)
        XCTAssertEqual(restoredCharacters.map(\.id), Self.mixedCharacters.map(\.id))
    }

    @MainActor
    func testDidSelectFromFilteredListDeliversSelectedCharacter() async throws {
        //harness:criterion=c-filter-did-select-delivers-original-character
        let viewModel = HomeViewModel()
        var receivedCharacter: Character?
        viewModel.onDetailRequested = { character in
            receivedCharacter = character
        }

        viewModel.fetchCharacters()
        _ = await waitForSuccess(from: viewModel)
        viewModel.selectedFilter = .alive
        let filteredCharacters = await waitForSuccess(from: viewModel)

        let aliveCharacter = try XCTUnwrap(filteredCharacters.first)
        viewModel.didSelect(character: aliveCharacter)

        XCTAssertEqual(receivedCharacter?.id, aliveCharacter.id)
        XCTAssertEqual(receivedCharacter?.name, aliveCharacter.name)
        XCTAssertEqual(receivedCharacter?.status, aliveCharacter.status)
        XCTAssertEqual(receivedCharacter?.species, aliveCharacter.species)
        XCTAssertEqual(receivedCharacter?.gender, aliveCharacter.gender)
        XCTAssertEqual(receivedCharacter?.image, aliveCharacter.image)
    }

    @MainActor
    func testAliveFilterCanPublishEmptyResult() async {
        //harness:criterion=c-filter-empty-result-alive
        repository.characters = [
            Self.character(id: 10, name: "Dead One", status: .dead),
            Self.character(id: 11, name: "Dead Two", status: .dead)
        ]
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await waitForSuccess(from: viewModel)
        viewModel.selectedFilter = .alive

        let characters = await waitForSuccess(from: viewModel)
        XCTAssertTrue(characters.isEmpty)
    }

    @MainActor
    func testLoadingStateUnaffectedBySelectedFilter() {
        //harness:criterion=c-loading-state-unaffected-by-filter
        for filter in CharacterStatusFilter.allCases {
            let viewModel = HomeViewModel()
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()

            guard case .loading = viewModel.state else {
                return XCTFail("Expected loading state for filter \(filter)")
            }
        }
    }

    @MainActor
    func testFailureStateUnaffectedBySelectedFilter() async {
        //harness:criterion=c-failure-state-unaffected-by-filter
        for filter in CharacterStatusFilter.allCases {
            repository.error = TestError.fetchFailed
            let viewModel = HomeViewModel()
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()

            let message = await waitForFailure(from: viewModel)
            XCTAssertFalse(message.isEmpty)
        }
    }

    func testServiceLocatorUsesRepositoryRegisteredForCurrentTest() {
        //harness:criterion=c-service-locator-reset-between-tests,c-fetch-characters-layer-unchanged
        let resolved: CharacterRepositoryProtocol = ServiceLocator.shared.resolve()

        XCTAssertTrue((resolved as? MockCharacterRepository) === repository)
    }

    func testServiceLocatorRegistrationCanBeReplacedWithinATest() {
        //harness:criterion=c-service-locator-reset-between-tests
        let replacement = MockCharacterRepository(characters: [
            Self.character(id: 20, name: "Replacement Rick", status: .alive)
        ])

        ServiceLocator.shared.unregisterAll()
        ServiceLocator.shared.register(replacement as CharacterRepositoryProtocol)

        let resolved: CharacterRepositoryProtocol = ServiceLocator.shared.resolve()
        XCTAssertTrue((resolved as? MockCharacterRepository) === replacement)
    }

    @MainActor
    private func waitForSuccess(
        from viewModel: HomeViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> [Character] {
        for _ in 0..<100 {
            if case .success(let characters) = viewModel.state {
                return characters
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for success state", file: file, line: line)
        return []
    }

    @MainActor
    private func waitForFailure(
        from viewModel: HomeViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> String {
        for _ in 0..<100 {
            if case .failure(let message) = viewModel.state {
                return message
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for failure state", file: file, line: line)
        return ""
    }

    private static let mixedCharacters = [
        character(id: 1, name: "Alive Character", status: .alive),
        character(id: 2, name: "Dead Character", status: .dead),
        character(id: 3, name: "Unknown Character", status: .unknown)
    ]

    private static func character(id: Int, name: String, status: CharacterStatusType) -> Character {
        Character(
            id: id,
            name: name,
            status: status,
            species: "Human",
            gender: "Unknown",
            image: "https://example.com/\(id).jpeg"
        )
    }
}

private final class MockCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    var characters: [Character]
    var error: Error?

    private let lock = NSLock()
    private(set) var fetchCallCount = 0

    init(characters: [Character]) {
        self.characters = characters
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        fetchCallCount += 1
        lock.unlock()

        if let error {
            throw error
        }

        return characters
    }
}

private enum TestError: LocalizedError {
    case fetchFailed

    var errorDescription: String? {
        "Fetch failed"
    }
}
