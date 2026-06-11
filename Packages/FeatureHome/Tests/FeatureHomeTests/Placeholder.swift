import Core
import Domain
@testable import FeatureHome
import XCTest

@MainActor
final class HomeViewModelStatusFilterTests: XCTestCase {
    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    //harness:criterion=c-status-filter-enum-cases
    func testCharacterStatusFilterExposesExactlyTheContractCases() {
        XCTAssertEqual(CharacterStatusFilter.allCases.count, 4)

        let caseNames = CharacterStatusFilter.allCases.map { filter in
            switch filter {
            case .all:
                return "all"
            case .alive:
                return "alive"
            case .dead:
                return "dead"
            case .unknown:
                return "unknown"
            }
        }

        XCTAssertEqual(caseNames, ["all", "alive", "dead", "unknown"])
    }

    //harness:criterion=c-viewmodel-selected-filter-default
    func testSelectedFilterDefaultsToAllBeforeFetching() {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)

        let viewModel = HomeViewModel()

        guard case .all = viewModel.selectedFilter else {
            return XCTFail("Expected selectedFilter to default to .all")
        }
    }

    //harness:criterion=c-filter-all-shows-all-characters
    func testAllFilterPublishesEveryFetchedCharacter() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .all

        let characters = try successCharacters(from: viewModel)
        XCTAssertEqual(characters.map(\.id), mixedCharacters.map(\.id))
    }

    //harness:criterion=c-filter-alive-shows-only-alive
    func testAliveFilterPublishesOnlyAliveCharacters() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .alive

        let characters = try successCharacters(from: viewModel)
        XCTAssertEqual(characters.count, 2)
        XCTAssertTrue(characters.allSatisfy { $0.status == .alive })
    }

    //harness:criterion=c-filter-dead-shows-only-dead
    func testDeadFilterPublishesOnlyDeadCharacters() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .dead

        let characters = try successCharacters(from: viewModel)
        XCTAssertEqual(characters.map(\.id), [3])
        XCTAssertTrue(characters.allSatisfy { $0.status == .dead })
    }

    //harness:criterion=c-filter-unknown-shows-only-unknown
    func testUnknownFilterPublishesOnlyUnknownCharacters() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .unknown

        let characters = try successCharacters(from: viewModel)
        XCTAssertEqual(characters.map(\.id), [4])
        XCTAssertTrue(characters.allSatisfy { $0.status == .unknown })
    }

    //harness:criterion=c-filter-change-no-refetch
    func testChangingFilterAfterFetchDoesNotFetchAgain() async throws {
        let repository = SpyCharacterRepository(characters: mixedCharacters)
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .alive
        viewModel.selectedFilter = .dead
        viewModel.selectedFilter = .unknown
        viewModel.selectedFilter = .all

        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    //harness:criterion=c-filter-switch-updates-state
    func testSwitchingFilterPublishesNewFilteredSuccessState() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .alive
        XCTAssertEqual(try successCharacters(from: viewModel).map(\.id), [1, 2])

        viewModel.selectedFilter = .dead
        XCTAssertEqual(try successCharacters(from: viewModel).map(\.id), [3])
    }

    //harness:criterion=c-filter-alive-empty-result
    func testAliveFilterPublishesEmptySuccessWhenNoAliveCharactersWereFetched() async throws {
        let characters = [
            makeCharacter(id: 10, name: "Dead Fixture", status: .dead),
            makeCharacter(id: 11, name: "Unknown Fixture", status: .unknown)
        ]
        ServiceLocator.shared.register(SpyCharacterRepository(characters: characters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .alive

        XCTAssertTrue(try successCharacters(from: viewModel).isEmpty)
    }

    //harness:criterion=c-didselect-filtered-routes-correct-character
    func testDidSelectWithFilteredCharacterRequestsDetailForThatCharacter() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)
        viewModel.selectedFilter = .alive
        let pickedCharacter = try XCTUnwrap(try successCharacters(from: viewModel).first)

        var routedCharacter: Character?
        viewModel.onDetailRequested = { routedCharacter = $0 }
        viewModel.didSelect(character: pickedCharacter)

        assertSameCharacter(routedCharacter, pickedCharacter)
    }

    //harness:criterion=c-detail-nav-triggers-coordinator
    func testDidSelectRoutesSelectedCharacterForEveryActiveFilter() async throws {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        let viewModel = HomeViewModel()

        _ = try await fetchSuccess(from: viewModel)

        for filter in CharacterStatusFilter.allCases {
            viewModel.selectedFilter = filter
            let pickedCharacter = try XCTUnwrap(try successCharacters(from: viewModel).first)

            var routedCharacter: Character?
            viewModel.onDetailRequested = { routedCharacter = $0 }
            viewModel.didSelect(character: pickedCharacter)

            assertSameCharacter(routedCharacter, pickedCharacter)
        }
    }

    //harness:criterion=c-existing-loading-state-preserved
    func testFetchPublishesLoadingBeforeCompletionForEveryFilter() async throws {
        for filter in CharacterStatusFilter.allCases {
            ServiceLocator.shared.unregisterAll()
            ServiceLocator.shared.register(
                SpyCharacterRepository(characters: mixedCharacters, delayNanoseconds: 100_000_000) as CharacterRepositoryProtocol
            )
            let viewModel = HomeViewModel()
            viewModel.state = .success(mixedCharacters)
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()

            guard case .loading = viewModel.state else {
                return XCTFail("Expected loading state for filter \(filter)")
            }

            _ = try await waitForSuccess(from: viewModel)
        }
    }

    //harness:criterion=c-existing-failure-state-preserved
    func testFetchFailurePublishesFailureForEveryFilter() async throws {
        for filter in CharacterStatusFilter.allCases {
            ServiceLocator.shared.unregisterAll()
            ServiceLocator.shared.register(SpyCharacterRepository(error: TestError.fetchFailed) as CharacterRepositoryProtocol)
            let viewModel = HomeViewModel()
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()

            let message = try await waitForFailure(from: viewModel)
            XCTAssertFalse(message.isEmpty)
        }
    }

    //harness:criterion=c-repository-protocol-unchanged
    func testCharacterRepositoryProtocolStillAcceptsFetchOnlyConformance() async throws {
        let repository: CharacterRepositoryProtocol = SpyCharacterRepository(characters: mixedCharacters)

        let characters = try await repository.fetchCharacters()

        XCTAssertEqual(characters.map(\.id), mixedCharacters.map(\.id))
    }

    //harness:criterion=c-feature-home-tests-target-added
    func testFeatureHomeTestsTargetCanUseFeatureHomeAndCoreDependencies() {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)

        let viewModel = HomeViewModel()

        guard case .all = viewModel.selectedFilter else {
            return XCTFail("FeatureHomeTests should compile against FeatureHome and Core dependencies.")
        }
    }

    //harness:criterion=c-unit-tests-use-servicelocator-teardown
    func testServiceLocatorTeardownRemovesRegisteredRepositoryBetweenTests() {
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)
        ServiceLocator.shared.unregisterAll()
        ServiceLocator.shared.register(SpyCharacterRepository(characters: mixedCharacters) as CharacterRepositoryProtocol)

        let viewModel = HomeViewModel()

        guard case .all = viewModel.selectedFilter else {
            return XCTFail("Expected a fresh HomeViewModel to be independent of prior registrations")
        }
    }

    private var mixedCharacters: [Character] {
        [
            makeCharacter(id: 1, name: "Alive One", status: .alive),
            makeCharacter(id: 2, name: "Alive Two", status: .alive),
            makeCharacter(id: 3, name: "Dead One", status: .dead),
            makeCharacter(id: 4, name: "Unknown One", status: .unknown)
        ]
    }

    private func makeCharacter(id: Int, name: String, status: CharacterStatusType) -> Character {
        Character(
            id: id,
            name: name,
            status: status,
            species: "Human",
            gender: "unknown",
            image: "https://example.com/\(id).png"
        )
    }

    private func fetchSuccess(from viewModel: HomeViewModel) async throws -> [Character] {
        viewModel.fetchCharacters()
        return try await waitForSuccess(from: viewModel)
    }

    private func waitForSuccess(from viewModel: HomeViewModel) async throws -> [Character] {
        try await waitUntilState(timeoutNanoseconds: 2_000_000_000) {
            if case .success(let characters) = viewModel.state {
                return characters
            }
            return nil
        }
    }

    private func waitForFailure(from viewModel: HomeViewModel) async throws -> String {
        try await waitUntilState(timeoutNanoseconds: 2_000_000_000) {
            if case .failure(let message) = viewModel.state {
                return message
            }
            return nil
        }
    }

    private func waitUntilState<T>(
        timeoutNanoseconds: UInt64,
        readValue: () -> T?
    ) async throws -> T {
        let started = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
            if let value = readValue() {
                return value
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw TestError.timedOutWaitingForState
    }

    private func successCharacters(from viewModel: HomeViewModel) throws -> [Character] {
        guard case .success(let characters) = viewModel.state else {
            throw TestError.expectedSuccessState
        }
        return characters
    }

    private func assertSameCharacter(
        _ actual: Character?,
        _ expected: Character,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual?.id, expected.id, file: file, line: line)
        XCTAssertEqual(actual?.name, expected.name, file: file, line: line)
        XCTAssertEqual(actual?.status, expected.status, file: file, line: line)
        XCTAssertEqual(actual?.species, expected.species, file: file, line: line)
        XCTAssertEqual(actual?.gender, expected.gender, file: file, line: line)
        XCTAssertEqual(actual?.image, expected.image, file: file, line: line)
    }
}

private final class SpyCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let characters: [Character]
    private let error: Error?
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var calls = 0

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    init(characters: [Character] = [], error: Error? = nil, delayNanoseconds: UInt64 = 0) {
        self.characters = characters
        self.error = error
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        calls += 1
        lock.unlock()

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        if let error {
            throw error
        }

        return characters
    }
}

private enum TestError: Error {
    case expectedSuccessState
    case fetchFailed
    case timedOutWaitingForState
}
