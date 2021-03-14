import Foundation
import Combine
import CoreData
import JWWCore
import os

/// A container that encapsulates the Core Data stack in your app.
open class JWWPersistentContainer: NSPersistentContainer {
    /// The current loading state of the persistent stores managed by the container.
    @Published public private(set) var state: State = .inactive

    /// The main thread / UI managed object context.
    public var mainObjectContext: NSManagedObjectContext {
        viewContext
    }

    /// The potential states the persistent container can be in.
    public enum State: Equatable {
        /// The container has not loaded its stores.
        case inactive

        /// The persistent stores have been loaded.
        case loaded

        /// Loading persistent stores failed with an error.
        case failed(Error)

        public static func == (lhs: JWWPersistentContainer.State, rhs: JWWPersistentContainer.State) -> Bool {
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

    private let log = Logger(category: .database)

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    /// Initializes a persistent container with the given name and model.
    /// - Parameters:
    ///   - name: The name used by the persistent container
    ///   - bundle: The bundle to search for the managed object model.
    public init(name: String, bundle: Bundle) {
        guard let url = bundle.url(forResource: name, withExtension: "momd") else {
            fatalError("Failed to find model \(name) in bundle.")
        }

        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load momd file \(name) at url \(url).")
        }

        super.init(name: name, managedObjectModel: model)
    }

    // MARK: Subclass Methods
    // ====================================
    // Subclass Methods
    // ====================================

    public override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        let completion = {(storeDescription: NSPersistentStoreDescription, error: Error?) -> Void in
            self.viewContext.name = "UI / Main thread context"
            self.viewContext.automaticallyMergesChangesFromParent = true
            self.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            block(storeDescription, error)
        }
        super.loadPersistentStores(completionHandler: completion)
    }

    public override func newBackgroundContext() -> NSManagedObjectContext {
        let context = super.newBackgroundContext()
        context.undoManager = nil
        context.name = "Persistent Container Background Context"
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        return context
    }

    // MARK: Public Methods
    // ====================================
    // Public Methods
    // ====================================

    @discardableResult
    public func performBackgroundTask(andSave shouldSave: Bool, closure: @escaping (NSManagedObjectContext) -> Void) -> Future<Void, Error> {
        return Future { promise in
            self.performBackgroundTask { context in
                closure(context)

                guard shouldSave else {
                    promise(.success(()))
                    return
                }

                do {
                    promise(.success(try context.save()))
                } catch let error as NSError {
                    context.rollback()
                    self.log.error("Error inserting default assets \(error.userInfo)")
                    promise(.failure(error))
                }

            }
        }
    }

    public func load(store: NSPersistentStoreDescription) -> AnyPublisher<NSPersistentStoreDescription, Error> {
        Future { [self] promise in
            persistentStoreCoordinator.addPersistentStore(with: store) { (desc, error) in
                if let error = error {
                    return promise(.failure(error))
                }

                return promise(.success((store)))
            }
        }.eraseToAnyPublisher()
    }

    /// Returns a publisher that wraps the `loadPersistentStores(completionHandler:)` function.
    ///
    /// - Returns: An `AnyPublisher` wrapping this publisher.
    public func loadPersistentStores() -> AnyPublisher<[NSPersistentStoreDescription], Error> {
        Publishers.MergeMany(persistentStoreDescriptions.map(load(store:)))
            .collect()
            .handleEvents(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.state = .failed(error)
                case .finished:
                    self.state = .loaded
                }
            })
            .eraseToAnyPublisher()
    }
}
