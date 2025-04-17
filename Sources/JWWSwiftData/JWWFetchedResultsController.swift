import Foundation
import SwiftData
import CoreData
import JWWCore
import os

private extension Logger {
    /// Logger for logging related to SwiftData and CoreData.
    static let package = Logger(subsystem: .default, category: .init(rawValue: "package"))
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public protocol JWWFetchedResultsControllerDelegate: AnyObject {
    func controllerWillChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
    func controllerDidChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@Observable
@MainActor
public final class JWWFetchedResultsController<T: PersistentModel> {
    public unowned(unsafe) var delegate: (any JWWFetchedResultsControllerDelegate)?
    public private(set) var fetchedModels: [T]?

    private let container: ModelContainer
    private let modelContext: ModelContext
    private let fetchDescriptor: FetchDescriptor<T>
    private let databaseMonitor: JWWDatabaseMonitor

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    public init(fetchRequest: FetchDescriptor<T>, container: ModelContainer, delegate: JWWFetchedResultsControllerDelegate? = nil) {
        self.container = container
        self.modelContext = container.mainContext
        self.fetchDescriptor = fetchRequest
        self.databaseMonitor = JWWDatabaseMonitor(modelContainer: container)
        self.delegate = delegate
    }

    deinit {
        print("DEINIT")
    }

    // MARK: Public API
    // ====================================
    // Public API
    // ====================================

    public func fetch() async throws {
        let results  = try modelContext.fetch(fetchDescriptor)

        if let delegate {
            delegate.controllerWillChangeContent(self)
        }

        fetchedModels = results

        if let delegate {
            delegate.controllerDidChangeContent(self)
        }

        Task.detached { [databaseMonitor] in
            await databaseMonitor.subscribeToModelChanges()
        }
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@ModelActor
private actor JWWDatabaseMonitor {
    func subscribeToModelChanges() async {
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave).map({ _ in () }) {
            Logger.package.debug("Reloading widget timelines because of NSPersistentStoreRemoteChange!")
        }
    }
}
