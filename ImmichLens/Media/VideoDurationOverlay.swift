//
//  VideoDurationOverlay.swift
//  ImmichLens
//
//  Created on 10/05/2025.
//

import SwiftUI

struct VideoDurationOverlay: View {
  let duration: String?

  var body: some View {
    HStack(spacing: 4) {
      Text(formattedDuration)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.white)
    }
    .padding(6)
    .cornerRadius(6)
    .padding(8)
  }

  private var formattedDuration: String {
    guard let durationString = duration else { return "0:00" }

    let components = durationString.components(separatedBy: ":")
    if components.count >= 3,
      let hours = Int(components[0]),
      let minutes = Int(components[1]),
      let secondsWithMs = Double(components[2])
    {

      let seconds = Int(secondsWithMs)

      // If hours > 0, show as HH:MM:SS, otherwise just MM:SS
      if hours > 0 {
        return String(format: "%d:%d:%02d", hours, minutes, seconds)
      } else {
        return String(format: "%d:%02d", minutes, seconds)
      }
    }

    return "0:00"
  }

  private func formatDuration(_ duration: Int) -> String {
    let minutes = duration / 60
    let seconds = duration % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }
}
