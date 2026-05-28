import XCTest
import Core
import Domain
@testable import FeatureHome

final class HomeViewModelFilterTests: XCTestCase {
    private var repository: MockCharacterRepository!

    override func setUp() {
        super.setUp()
        ServiceLocator.shared.unregisterAll()
        repository = MockCharacterRepository(result: .success(Self.mixedCharacters))
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
    }

    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        repository = nil
        super.tearDown()
    }

    //harness:criterion=c-filter-enum-cases,c-filter-control-segments
    @MainActor
    func testSelectedFilterExposesExactlyTheExpectedCases() {
        let allCases = Array(CharacterStatusFilter.allCases)

        XCTAssertEqual(allCases.count, 4)
        XCTAssertEqual(allCases.map(\.title), ["All", "Alive", "Dead", "Unknown"])

        for filter in allCases {
            switch filter {
            case .all:
                XCTAssertEqual(filter.title, "All")
            case .alive:
                XCTAssertEqual(filter.title, "Alive")
            case .dead:
                XCTAssertEqual(filter.title, "Dead")
            case .unknown:
                XCTAssertEqual(filter.title, "Unknown")
            }
        }

        let viewModel = HomeViewModel()
        viewModel.selectedFilter = .all
        XCTAssertEqual(viewModel.selectedFilter, .all)
        viewModel.selectedFilter = .alive
        XCTAssertEqual(viewModel.selectedFilter, .alive)
        viewModel.selectedFilter = .dead
        XCTAssertEqual(viewModel.selectedFilter, .dead)
        viewModel.selectedFilter = .unknown
        XCTAssertEqual(viewModel.selectedFilter, .unknown)
    }

    //harness:criterion=c-filter-default-all
    @MainActor
    func testSelectedFilterDefaultsToAll() {
        let viewModel = HomeViewModel()

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    //harness:criterion=c-filter-all-passthrough
    @MainActor
    func testAllFilterReturnsEveryFetchedCharacter() async throws {
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        viewModel.selectedFilter = .all

        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [1, 2, 3])
    }

    //harness:criterion=c-filter-alive-only,c-filter-alive-excludes-non-alive
    @MainActor
    func testAliveFilterReturnsOnlyAliveCharacters() async throws {
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        viewModel.selectedFilter = .alive

        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [1])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .alive })
        XCTAssertFalse(viewModel.filteredCharacters.contains { $0.id == 2 || $0.id == 3 })
    }

    //harness:criterion=c-filter-dead-only,c-filter-dead-excludes-non-dead
    @MainActor
    func testDeadFilterReturnsOnlyDeadCharacters() async throws {
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        viewModel.selectedFilter = .dead

        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [2])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .dead })
        XCTAssertFalse(viewModel.filteredCharacters.contains { $0.id == 1 || $0.id == 3 })
    }

    //harness:criterion=c-filter-unknown-only,c-filter-unknown-excludes-non-unknown
    @MainActor
    func testUnknownFilterReturnsOnlyUnknownCharacters() async throws {
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        viewModel.selectedFilter = .unknown

        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [3])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .unknown })
        XCTAssertFalse(viewModel.filteredCharacters.contains { $0.id == 1 || $0.id == 2 })
    }

    //harness:criterion=c-filter-no-refetch
    @MainActor
    func testChangingSelectedFilterDoesNotRefetchCharacters() async throws {
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        XCTAssertEqual(repository.fetchCallCount, 1)

        viewModel.selectedFilter = .alive
        XCTAssertEqual(repository.fetchCallCount, 1)
        viewModel.selectedFilter = .dead
        XCTAssertEqual(repository.fetchCallCount, 1)
        viewModel.selectedFilter = .unknown
        XCTAssertEqual(repository.fetchCallCount, 1)
        viewModel.selectedFilter = .all
        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    //harness:criterion=c-filter-did-select-correct-character,c-filter-detail-nav-unaffected
    @MainActor
    func testDidSelectAfterFilteringRequestsTheSelectedCharacter() async throws {
        let viewModel = HomeViewModel()
        let recorder = SelectedCharacterRecorder()
        viewModel.onDetailRequested = { recorder.record($0) }

        viewModel.fetchCharacters()
        try await waitForSuccess(on: viewModel)
        viewModel.selectedFilter = .alive

        let selectedCharacter = try XCTUnwrap(viewModel.filteredCharacters.first)
        viewModel.didSelect(character: selectedCharacter)

        XCTAssertEqual(recorder.selectedCharacterIDs, [selectedCharacter.id])
    }

    //harness:criterion=c-filter-fetch-failure-preserved
    @MainActor
    func testFetchFailureStateIsPreservedForNonAllFilters() async throws {
        enum FetchError: Error {
            case failed
        }

        repository.setResult(.failure(FetchError.failed))

        for filter in [CharacterStatusFilter.alive, .dead, .unknown] {
            let viewModel = HomeViewModel()
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()
            try await waitForFailure(on: viewModel)

            guard case .failure = viewModel.state else {
                XCTFail("Expected failure state for filter \(filter)")
                return
            }
        }
    }

    //harness:criterion=c-filter-state-enum-unchanged,c-filter-repository-contract-unchanged
    @MainActor
    func testOriginalHomeViewStateCasesAndRepositoryContractStillCompile() async throws {
        let states: [HomeViewState] = [
            .loading,
            .success(Self.mixedCharacters),
            .failure("error")
        ]

        let renderedStates = states.map { state in
            switch state {
            case .loading:
                return "loading"
            case .success(let characters):
                return "success-\(characters.count)"
            case .failure(let message):
                return "failure-\(message)"
            }
        }

        XCTAssertEqual(renderedStates, ["loading", "success-3", "failure-error"])
        _ = try await repository.fetchCharacters()
    }

    @MainActor
    private func waitForSuccess(
        on viewModel: HomeViewModel,
        timeout: TimeInterval = 1
    ) async throws {
        try await waitForState(on: viewModel, timeout: timeout) {
            if case .success = $0 {
                return true
            }
            return false
        }
    }

    @MainActor
    private func waitForFailure(
        on viewModel: HomeViewModel,
        timeout: TimeInterval = 1
    ) async throws {
        try await waitForState(on: viewModel, timeout: timeout) {
            if case .failure = $0 {
                return true
            }
            return false
        }
    }

    @MainActor
    private func waitForState(
        on viewModel: HomeViewModel,
        timeout: TimeInterval,
        matching predicate: (HomeViewState) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !predicate(viewModel.state) {
            if Date() >= deadline {
                XCTFail("Timed out waiting for expected HomeViewState")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private static let mixedCharacters = [
        Character(
            id: 1,
            name: "Alive Character",
            status: .alive,
            species: "Human",
            gender: "Female",
            image: "https://example.com/alive.png"
        ),
        Character(
            id: 2,
            name: "Dead Character",
            status: .dead,
            species: "Alien",
            gender: "Male",
            image: "https://example.com/dead.png"
        ),
        Character(
            id: 3,
            name: "Unknown Character",
            status: .unknown,
            species: "Robot",
            gender: "unknown",
            image: "https://example.com/unknown.png"
        )
    ]
}

private final class MockCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var privateFetchCallCount = 0
    private var privateResult: Result<[Character], Error>

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return privateFetchCallCount
    }

    init(result: Result<[Character], Error>) {
        privateResult = result
    }

    func setResult(_ result: Result<[Character], Error>) {
        lock.lock()
        defer { lock.unlock() }
        privateResult = result
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        privateFetchCallCount += 1
        let result = privateResult
        lock.unlock()

        return try result.get()
    }
}

private final class SelectedCharacterRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var characters: [Character] = []

    var selectedCharacterIDs: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return characters.map(\.id)
    }

    func record(_ character: Character) {
        lock.lock()
        defer { lock.unlock() }
        characters.append(character)
    }
}
