import Core
import Domain
import SwiftUI
import XCTest
@testable import FeatureHome

@MainActor
final class HomeViewModelFilterTests: XCTestCase {
    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    func testSelectedFilterDefaultsToAll() {
        // harness:criterion=c-filter-published-property-exists
        let viewModel = makeViewModel(characters: mixedCharacters)

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    func testFilterAllReturnsFullList() async {
        // harness:criterion=c-filter-all-returns-full-list
        let viewModel = makeViewModel(characters: mixedCharacters)

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .all

        let characters = assertSuccess(viewModel.state)
        XCTAssertEqual(characterIDs(characters), [1, 2, 3])
    }

    func testFilterAliveReturnsOnlyAlive() async {
        // harness:criterion=c-filter-alive-returns-only-alive
        let viewModel = makeViewModel(characters: mixedCharacters)

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .alive

        let characters = assertSuccess(viewModel.state)
        XCTAssertEqual(characters.count, 1)
        XCTAssertTrue(characters.allSatisfy { $0.status == .alive })
        assertSameCharacter(characters.first, aliveCharacter)
    }

    func testFilterDeadReturnsOnlyDead() async {
        // harness:criterion=c-filter-dead-returns-only-dead
        let viewModel = makeViewModel(characters: mixedCharacters)

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .dead

        let characters = assertSuccess(viewModel.state)
        XCTAssertEqual(characters.count, 1)
        XCTAssertTrue(characters.allSatisfy { $0.status == .dead })
        assertSameCharacter(characters.first, deadCharacter)
    }

    func testFilterUnknownReturnsOnlyUnknown() async {
        // harness:criterion=c-filter-unknown-returns-only-unknown
        let viewModel = makeViewModel(characters: mixedCharacters)

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .unknown

        let characters = assertSuccess(viewModel.state)
        XCTAssertEqual(characters.count, 1)
        XCTAssertTrue(characters.allSatisfy { $0.status == .unknown })
        assertSameCharacter(characters.first, unknownCharacter)
    }

    func testFilterChangeDoesNotIssueFetch() async {
        // harness:criterion=c-filter-change-updates-state-no-new-fetch
        let repository = MockCharacterRepository(characters: mixedCharacters)
        let viewModel = makeViewModel(repository: repository)

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .alive

        let characters = assertSuccess(viewModel.state)
        XCTAssertEqual(repository.callCount, 1)
        XCTAssertEqual(characterIDs(characters), [aliveCharacter.id])
    }

    func testFilterDeadEmptyResultIsSuccessEmpty() async {
        // harness:criterion=c-filter-empty-result-success-empty
        let viewModel = makeViewModel(characters: [aliveCharacter, secondAliveCharacter])

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .dead

        let characters = assertSuccess(viewModel.state)
        XCTAssertTrue(characters.isEmpty)
    }

    func testDidSelectAfterAliveFilter() async {
        // harness:criterion=c-didselect-routes-correct-character-after-alive-filter
        let viewModel = makeViewModel(characters: [aliveCharacter, deadCharacter])
        var routedCharacter: Character?
        var routeCount = 0
        viewModel.onDetailRequested = { character in
            routedCharacter = character
            routeCount += 1
        }

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .alive
        viewModel.didSelect(character: aliveCharacter)

        XCTAssertEqual(routeCount, 1)
        assertSameCharacter(routedCharacter, aliveCharacter)
    }

    func testDidSelectAfterDeadFilter() async {
        // harness:criterion=c-didselect-routes-correct-character-after-dead-filter
        let viewModel = makeViewModel(characters: [aliveCharacter, deadCharacter])
        var routedCharacter: Character?
        var routeCount = 0
        viewModel.onDetailRequested = { character in
            routedCharacter = character
            routeCount += 1
        }

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .dead
        viewModel.didSelect(character: deadCharacter)

        XCTAssertEqual(routeCount, 1)
        assertSameCharacter(routedCharacter, deadCharacter)
    }

    func testDidSelectAfterUnknownFilter() async {
        // harness:criterion=c-didselect-routes-correct-character-after-unknown-filter
        let viewModel = makeViewModel(characters: [aliveCharacter, unknownCharacter])
        var routedCharacter: Character?
        var routeCount = 0
        viewModel.onDetailRequested = { character in
            routedCharacter = character
            routeCount += 1
        }

        viewModel.fetchCharacters()
        await waitForTerminalState(viewModel)
        viewModel.selectedFilter = .unknown
        viewModel.didSelect(character: unknownCharacter)

        XCTAssertEqual(routeCount, 1)
        assertSameCharacter(routedCharacter, unknownCharacter)
    }

    func testFetchFailureUnaffectedByFilter() async {
        // harness:criterion=c-fetch-failure-unaffected-by-filter
        for filter in CharacterStatusFilter.allCases {
            let viewModel = makeViewModel(error: StubError.fetchFailed)
            viewModel.selectedFilter = filter

            viewModel.fetchCharacters()
            await waitForTerminalState(viewModel)

            guard case .failure = viewModel.state else {
                return XCTFail("Expected failure for filter \(filter), got \(viewModel.state)")
            }
        }
    }
}

@MainActor
final class HomeViewTests: XCTestCase {
    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    func testFilterControlVisibleOnlyInSuccessBranch() {
        // harness:criterion=c-filter-control-visible-in-success-branch
        XCTAssertTrue(bodyStrings(for: .success([])).contains("status_filter_all"))
        XCTAssertFalse(bodyStrings(for: .loading).contains("status_filter_all"))
        XCTAssertFalse(bodyStrings(for: .failure("Failed")).contains("status_filter_all"))
    }

    func testFilterControlBoundToSelectedFilter() {
        // harness:criterion=c-filter-control-bound-to-selected-filter
        let viewModel = makeViewModel(characters: mixedCharacters)
        viewModel.state = .success(mixedCharacters)
        let view = HomeView(viewModel: viewModel)

        guard let binding: Binding<CharacterStatusFilter> = firstValue(in: view.body) else {
            return XCTFail("Expected HomeView success body to contain a CharacterStatusFilter binding")
        }

        binding.wrappedValue = .alive

        XCTAssertEqual(viewModel.selectedFilter, .alive)
    }

    func testFilterSegmentAccessibilityIdentifiersExistInSuccessBranch() {
        // harness:criterion=c-accessibility-id-all,c-accessibility-id-alive,c-accessibility-id-dead,c-accessibility-id-unknown
        let strings = bodyStrings(for: .success([]))

        XCTAssertTrue(strings.contains("status_filter_all"))
        XCTAssertTrue(strings.contains("status_filter_alive"))
        XCTAssertTrue(strings.contains("status_filter_dead"))
        XCTAssertTrue(strings.contains("status_filter_unknown"))
    }

    func testFilterControlAppearsBeforeCharacterList() {
        // harness:criterion=c-filter-control-above-list
        let strings = bodyStrings(for: .success([aliveCharacter]))

        guard let filterIndex = strings.firstIndex(of: "status_filter_all") else {
            return XCTFail("Expected status filter in success branch")
        }
        guard let listIndex = strings.firstIndex(of: "character_list") else {
            return XCTFail("Expected character list in success branch")
        }

        XCTAssertLessThan(filterIndex, listIndex)
    }
}

@MainActor
private func makeViewModel(characters: [Character]) -> HomeViewModel {
    makeViewModel(repository: MockCharacterRepository(characters: characters))
}

@MainActor
private func makeViewModel(error: Error) -> HomeViewModel {
    makeViewModel(repository: MockCharacterRepository(error: error))
}

@MainActor
private func makeViewModel(repository: MockCharacterRepository) -> HomeViewModel {
    ServiceLocator.shared.unregisterAll()
    ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
    return HomeViewModel()
}

@MainActor
private func waitForTerminalState(
    _ viewModel: HomeViewModel,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0..<100 {
        switch viewModel.state {
        case .success, .failure:
            return
        case .loading:
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    XCTFail("Timed out waiting for HomeViewModel state to settle", file: file, line: line)
}

@discardableResult
private func assertSuccess(
    _ state: HomeViewState,
    file: StaticString = #filePath,
    line: UInt = #line
) -> [Character] {
    guard case .success(let characters) = state else {
        XCTFail("Expected success state, got \(state)", file: file, line: line)
        return []
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

private func characterIDs(_ characters: [Character]) -> [Int] {
    characters.map(\.id)
}

@MainActor
private func bodyStrings(for state: HomeViewState) -> [String] {
    let viewModel = makeViewModel(characters: [])
    viewModel.state = state
    let view = HomeView(viewModel: viewModel)
    return allStrings(in: view.body)
}

private func allStrings(in value: Any, maxDepth: Int = 80) -> [String] {
    var strings: [String] = []
    visit(value, maxDepth: maxDepth) { candidate in
        if let string = candidate as? String {
            strings.append(string)
        }
    }
    return strings
}

private func firstValue<T>(in value: Any, maxDepth: Int = 80) -> T? {
    var match: T?
    visit(value, maxDepth: maxDepth) { candidate in
        if match == nil {
            match = candidate as? T
        }
    }
    return match
}

private func visit(_ value: Any, maxDepth: Int, _ inspect: (Any) -> Void) {
    guard maxDepth >= 0 else { return }

    inspect(value)

    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        if let child = mirror.children.first {
            visit(child.value, maxDepth: maxDepth - 1, inspect)
        }
        return
    }

    for child in mirror.children {
        visit(child.value, maxDepth: maxDepth - 1, inspect)
    }
}

private final class MockCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let characters: [Character]
    private let error: Error?
    private let queue = DispatchQueue(label: "FeatureHomeTests.MockCharacterRepository")
    private var fetchCount = 0

    init(characters: [Character] = [], error: Error? = nil) {
        self.characters = characters
        self.error = error
    }

    var callCount: Int {
        queue.sync { fetchCount }
    }

    func fetchCharacters() async throws -> [Character] {
        queue.sync {
            fetchCount += 1
        }

        if let error {
            throw error
        }

        return characters
    }
}

private enum StubError: Error {
    case fetchFailed
}

private let aliveCharacter = Character(
    id: 1,
    name: "Rick Sanchez",
    status: .alive,
    species: "Human",
    gender: "Male",
    image: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
)

private let deadCharacter = Character(
    id: 2,
    name: "Adjudicator Rick",
    status: .dead,
    species: "Human",
    gender: "Male",
    image: "https://rickandmortyapi.com/api/character/avatar/8.jpeg"
)

private let unknownCharacter = Character(
    id: 3,
    name: "Alien Googah",
    status: .unknown,
    species: "Alien",
    gender: "unknown",
    image: "https://rickandmortyapi.com/api/character/avatar/13.jpeg"
)

private let secondAliveCharacter = Character(
    id: 4,
    name: "Morty Smith",
    status: .alive,
    species: "Human",
    gender: "Male",
    image: "https://rickandmortyapi.com/api/character/avatar/2.jpeg"
)

private let mixedCharacters = [
    aliveCharacter,
    deadCharacter,
    unknownCharacter
]
