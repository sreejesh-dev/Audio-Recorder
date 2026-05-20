//
//  AppTheme.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let card = Color.white
    static let primaryText = Color.black.opacity(0.88)
    static let secondaryText = Color.black.opacity(0.45)
    static let divider = Color.black.opacity(0.08)
    static let searchBackground = Color.black.opacity(0.05)
    static let chipSelected = Color.black.opacity(0.88)
    static let chipUnselected = Color.black.opacity(0.06)
    static let waveformBlue = Color(red: 0.35, green: 0.55, blue: 0.95)
    static let waveformFill = Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.45)
    static let doneGreen = Color(red: 0.72, green: 0.88, blue: 0.72)
    static let doneButtonBackground = Color(red: 0.88, green: 0.97, blue: 0.88)
    static let doneAccentGreen = Color(red: 0.18, green: 0.72, blue: 0.38)
    static let recordingControlBackground = Color.black.opacity(0.06)
    static let sheetWaveBackground = Color.black.opacity(0.04)
    static let durationPill = Color.black.opacity(0.06)
    static let recordingSheetBorder = Color.black.opacity(0.07)
    static let recordingActive = Color(red: 0.95, green: 0.22, blue: 0.22)
    static let recordingActiveSoft = Color(red: 0.95, green: 0.22, blue: 0.22).opacity(0.18)

    static let cornerRadiusLarge: CGFloat = 28
    static let cornerRadiusMedium: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 14

    static let recordingSheetHorizontalPadding: CGFloat = 16
    static let recordingSheetBottomPadding: CGFloat = 10
}
