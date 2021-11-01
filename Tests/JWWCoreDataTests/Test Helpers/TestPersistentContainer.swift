import Foundation
import Combine
import CoreData
import JWWCoreData

final class TestPersistentContainer: NSPersistentContainer, JWWPersistentContainerProviding {
    /// The current loading state of the persistent stores managed by the container.
    @Published public private(set) var state: NSPersistentContainer.State = .inactive

    /// Publisher that fires when the persistent container has loaded its attached stores.
    public private(set) lazy var isLoadedPublisher: AnyPublisher<Void, Never> = {
        $state
            .drop(while: { state in
                state != .loaded
            })
            .map({ _ in () })
            .share()
            .eraseToAnyPublisher()
    }()

    private var persistentStoreLoadingSubscriber: AnyCancellable?

    override class func defaultDirectoryURL() -> URL {
        URL(fileURLWithPath: "/dev/null")
    }

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    init(name: String, bundle: Bundle) {
        guard let url = bundle.url(forResource: name, withExtension: "momd") else {
            fatalError("Failed to find model \(name) in bundle.")
        }

        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load momd file \(name) at url \(url).")
        }

        super.init(name: name, managedObjectModel: model)

        persistentStoreLoadingSubscriber = isLoadedPublisher
            .receive(on: ImmediateScheduler.shared)
            .sink(receiveValue: { [self] _ in
                viewContext.name = "UI / Main thread context"
                viewContext.automaticallyMergesChangesFromParent = true
                viewContext.shouldDeleteInaccessibleFaults = true
                viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            })
    }

    // MARK: Loading Methods
    // ====================================
    // Loading Methods
    // ====================================

    func loadPersistentStores() -> AnyPublisher<[NSPersistentStoreDescription], Error> {
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
