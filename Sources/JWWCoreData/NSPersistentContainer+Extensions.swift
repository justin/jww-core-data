import Foundation
import CoreData
import Combine
import os
import JWWCore

public extension NSPersistentContainer {
    /// The supported storage types.
    enum Storage: String {
        /// Load the container using in-memory storage.
        case memory

        /// Load the container using a SQLite database.
        case persisted

        /// Returns the URL where the store will keep its data.
        public var url: URL {
            switch self {
            case .memory:
                return URL(fileURLWithPath: "/dev/null")
            case .persisted:
                return NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("Storage.sqlite")
            }
        }
    }

    /// The potential states the persistent container can be in.
    enum State: Equatable {
        /// The container has not loaded its stores.
        case inactive

        /// The persistent stores have been loaded.
        case loaded

        /// Loading persistent stores failed with an error.
        case failed(Error)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive),
                (.loaded, .loaded),
                (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
}

/// Protocol that declares the extensions and custom attributes 
public protocol JWWPersistentContainerProviding {
    /// The current loading state of the persistent stores managed by the container.
    var state: NSPersistentContainer.State { get }

    /// Publisher that fires when the persistent container has loaded its attached stores.
    var isLoadedPublisher: AnyPublisher<Void, Never> { get }

    /// The main thread / UI managed object context.
    var mainObjectContext: NSManagedObjectContext { get }

    /// Initializes a persistent container with the given name and model.
    /// - Parameters:
    ///   - name: The name used by the persistent container
    ///   - bundle: The bundle to search for the managed object model.
    init(name: String, bundle: Bundle)


    /// Perform a background task against the loaded persistent container.
    @discardableResult
    func performBackgroundTask(andSave shouldSave: Bool,
                               transactionAuthor: String?,
                               contextName name: String?,
                               closure: @escaping (NSManagedObjectContext) -> Void) -> Future<Void, Error>

    /// Returns a publisher that wraps the `loadPersistentStores(completionHandler:)` function.
    ///
    /// - Returns: An `AnyPublisher` wrapping this publisher.
    func loadPersistentStores() -> AnyPublisher<[NSPersistentStoreDescription], Error>

    /// Load a single persistent store.
    func load(store: NSPersistentStoreDescription) -> AnyPublisher<NSPersistentStoreDescription, Error>
}

// MARK: Default Implementations
// ====================================
// Default Implementations
// ====================================
public extension JWWPersistentContainerProviding where Self:NSPersistentContainer {
    var mainObjectContext: NSManagedObjectContext {
        viewContext
    }

    @discardableResult
    func performBackgroundTask(andSave shouldSave: Bool,
                               transactionAuthor: String? = nil,
                               contextName name: String? = nil,
                               closure: @escaping (NSManagedObjectContext) -> Void) -> Future<Void, Error> {
        return Future { promise in
            self.performBackgroundTask { context in
                context.transactionAuthor = transactionAuthor
                context.name = name
                closure(context)

                guard shouldSave, context.hasChanges else {
                    promise(.success(()))
                    return
                }

                do {
                    promise(.success(try context.save()))
                } catch let error as NSError {
                    context.rollback()
                    Logger(category: .database).error("Error inserting default assets \(error.userInfo)")
                    promise(.failure(error))
                }
            }
        }
    }

    func load(store: NSPersistentStoreDescription) -> AnyPublisher<NSPersistentStoreDescription, Error> {
        Future { [self] promise in
            persistentStoreCoordinator.addPersistentStore(with: store) { (desc, error) in
                if let error = error {
                    return promise(.failure(error))
                }

                return promise(.success((store)))
            }
        }.eraseToAnyPublisher()
    }

}
