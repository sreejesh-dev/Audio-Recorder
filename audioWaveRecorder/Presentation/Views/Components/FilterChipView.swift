//
//  FilterChipView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.chipSelected : AppTheme.chipUnselected)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
