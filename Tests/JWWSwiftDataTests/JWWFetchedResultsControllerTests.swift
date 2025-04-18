import Foundation
import Testing
import SwiftData
import JWWSwiftData

/// Tests to verify the functionality of `JWWFetchedResultsController`.
@MainActor
final class JWWFetchedResultsControllerTests {
    private let sut: JWWFetchedResultsController<Person>
    private let container: ModelContainer
    private var delegate: JWWFetchedResultsControllerTestsDelegate?

    init() throws {
        container = JWWSwiftDataTestingStack().testingModelContainer
        sut = JWWFetchedResultsController(fetchRequest: FetchDescriptor<Person>(), container: container)
    }

    @Test("init")
    func initController() async {
        #expect(sut.fetchedModels == nil)
        #expect(sut.delegate == nil)
    }

    @Test("Fetching initial data")
    func fetchData() async throws {
        let people = [
            Person(id: UUID(), firstName: "John"),
            Person(id: UUID(), firstName: "Jane"),
            Person(id: UUID(), firstName: "Doe")
        ]

        for person in people {
            container.mainContext.insert(person)
        }
        try container.mainContext.save()

        try await sut.fetch()

        let result = try #require(sut.fetchedModels)
        #expect(result.count == 3, "Expected 3 people, but got \(result.count)")
    }

    @Test("Updating already fetched data")
    func updateData() async throws {
        delegate = JWWFetchedResultsControllerTestsDelegate()
        sut.delegate = delegate

        let people = [
            Person(id: UUID(), firstName: "John"),
            Person(id: UUID(), firstName: "Jane"),
            Person(id: UUID(), firstName: "Doe")
        ]

        for person in people {
            container.mainContext.insert(person)
        }
        try container.mainContext.save()

        try await sut.fetch()

        let result = try #require(delegate)
        #expect(result.controllerWillChangeContentCalled == true)
        #expect(result.controllerDidChangeContentCalled == true)

        container.mainContext.insert(Person(id: UUID(), firstName: "Steve"))
        try container.mainContext.save()


    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
final class JWWFetchedResultsControllerTestsDelegate: JWWFetchedResultsControllerDelegate {
    func controller(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>, didChange object: Any, at indexPath: IndexPath?, for type: JWWSwiftData.JWWFetchedResultsChangeType, newIndexPath: IndexPath?) {
        controllerDidChangeForTypeCalled = true
    }
    
    func controllerWillChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerWillChangeContentCalled = true
    }
    
    func controllerDidChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerDidChangeContentCalled = true
    }

    private(set) var controllerWillChangeContentCalled: Bool
    private(set) var controllerDidChangeForTypeCalled: Bool
    private(set) var controllerDidChangeContentCalled: Bool

    init() {
        self.controllerWillChangeContentCalled = false
        self.controllerDidChangeContentCalled = false
        self.controllerDidChangeForTypeCalled = false
    }
}
