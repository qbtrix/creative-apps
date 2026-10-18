// LibraryPersistGolden.swift: the catalog v1 golden (persist PE-2, QB-LIB-V7).
// `catalogV1` is pasted from `LiveCatalogCoding().encode(photos)` on Linux;
// a change to the file's bytes must change it on purpose. A Swift literal,
// not a JSON file: LibraryModelTests declares no resources.
import CoreColor
import Foundation
@testable import LibraryModel

enum LibraryPersistGolden {
    /// The fixed three-photo catalog: a developed, cropped, labelled pick; a
    /// plain reject; a sample with no file.
    static var photos: [PhotoItem] {
        let crop = CropSettings(angle: 5, rect: UnitRect(x: 0.25, y: 0, width: 0.5, height: 1), aspect: .square)
        let develop = DevelopSettings.neutral.setting(.exposure, to: 1).setting(.contrast, to: -20).setting(crop: crop)
        return [
            PhotoItem(
                id: "/Users/me/Pictures/IMG_0001.jpg", name: "IMG_0001",
                captureDate: Date(timeIntervalSince1970: 1_780_308_000), color: Color3(0.5, 0.25, 0.75), rating: 3,
                label: .red, flag: .pick, path: "/Users/me/Pictures/IMG_0001.jpg",
                pixelSize: PixelSize(width: 6000, height: 4000), develop: develop),
            PhotoItem(
                id: "/Users/me/Pictures/IMG_0002.jpg", name: "IMG_0002",
                captureDate: Date(timeIntervalSince1970: 1_780_308_060), color: Color3(0.5, 0.5, 0.5),
                flag: .reject, path: "/Users/me/Pictures/IMG_0002.jpg", pixelSize: PixelSize(width: 4000, height: 6000)),
            PhotoItem(
                name: "Sample 3", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0.125), rating: 5),
        ]
    }

    static let catalogV1 = #"""
{
  "photos" : [
    {
      "captureDate" : 1780308000,
      "color" : [
        0.5,
        0.25,
        0.75
      ],
      "develop" : {
        "contrast" : -20,
        "crop" : {
          "angle" : 5,
          "aspect" : "1:1",
          "rect" : {
            "height" : 1,
            "width" : 0.5,
            "x" : 0.25,
            "y" : 0
          }
        },
        "exposure" : 1,
        "highlights" : 0,
        "shadows" : 0,
        "temperature" : 0,
        "tint" : 0
      },
      "flag" : "Pick",
      "id" : "/Users/me/Pictures/IMG_0001.jpg",
      "label" : "Red",
      "name" : "IMG_0001",
      "path" : "/Users/me/Pictures/IMG_0001.jpg",
      "pixelSize" : {
        "height" : 4000,
        "width" : 6000
      },
      "rating" : 3
    },
    {
      "captureDate" : 1780308060,
      "color" : [
        0.5,
        0.5,
        0.5
      ],
      "flag" : "Reject",
      "id" : "/Users/me/Pictures/IMG_0002.jpg",
      "name" : "IMG_0002",
      "path" : "/Users/me/Pictures/IMG_0002.jpg",
      "pixelSize" : {
        "height" : 6000,
        "width" : 4000
      },
      "rating" : 0
    },
    {
      "captureDate" : 0,
      "color" : [
        1,
        0,
        0.125
      ],
      "flag" : "None",
      "id" : "Sample 3",
      "name" : "Sample 3",
      "pixelSize" : {
        "height" : 3024,
        "width" : 4032
      },
      "rating" : 5
    }
  ],
  "version" : 1
}

"""#
}
