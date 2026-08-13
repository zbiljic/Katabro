import Foundation

struct PickerShortcut: Hashable, Sendable {
    let rawValue: String

    init?(
        _ value: String
    ) {
        let uppercasedValue = value.uppercased()
        let scalars = uppercasedValue.unicodeScalars

        guard
            scalars.count == 1,
            let scalar = scalars.first,
            (UnicodeScalar("A").value ... UnicodeScalar("Z").value).contains(
                scalar.value
            )
        else {
            return nil
        }

        rawValue = uppercasedValue
    }

    var displayValue: String {
        rawValue
    }

    static func replacement(
        in editedValue: String,
        replacing currentValue: String
    ) -> Self? {
        if let replacement = Self(editedValue) {
            return replacement
        }

        let insertedCharacters = editedValue
            .difference(from: currentValue)
            .compactMap { change -> Character? in
                guard case let .insert(_, character, _) = change else {
                    return nil
                }

                return character
            }

        guard
            insertedCharacters.count == 1,
            let insertedCharacter = insertedCharacters.first
        else {
            return nil
        }

        return Self(String(insertedCharacter))
    }
}

extension PickerShortcut: Codable {
    init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let shortcut = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected one ASCII letter from A through Z."
            )
        }

        self = shortcut
    }

    func encode(
        to encoder: any Encoder
    ) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
