import Foundation
import SwiftData

/// A `Person` object represents a person in the SwiftData model.
/// This is only used for exercising the `JWWSwiftData` framework.
@Model
class Person: Identifiable {
    @Attribute(.unique)
    var id: UUID
    var birthDate: Date?
    var firstName: String?
    var lastName: String?

    init(id: UUID, firstName: String? = nil, lastName: String? = nil, birthDate: Date? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
    }
}
