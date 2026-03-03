import Foundation

extension Components.Schemas.AssetResponseDto {
    /// Extract the average normalized face center Y from all faces in the asset.
    /// Returns nil if no faces detected, otherwise 0.0 = top, 1.0 = bottom.
    var faceCenterY: Double? {
        var allCenters: [Double] = []

        if let people {
            for person in people {
                for face in person.faces {
                    guard face.imageHeight > 0 else { continue }
                    let centerY = Double(face.boundingBoxY1 + face.boundingBoxY2) / 2.0
                    allCenters.append(centerY / Double(face.imageHeight))
                }
            }
        }

        if let unassignedFaces {
            for face in unassignedFaces {
                guard face.imageHeight > 0 else { continue }
                let centerY = Double(face.boundingBoxY1 + face.boundingBoxY2) / 2.0
                allCenters.append(centerY / Double(face.imageHeight))
            }
        }

        guard !allCenters.isEmpty else { return nil }
        return allCenters.reduce(0, +) / Double(allCenters.count)
    }
}
