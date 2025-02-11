//
//  BottomSheetView.swift
//
//  Created by Lucas Zischka.
//  Copyright © 2021-2022 Lucas Zischka. All rights reserved.
//

import SwiftUI
import Combine

internal struct BottomSheetView<HContent: View,
                                MContent: View,
                                BottomSheetPositionEnum: RawRepresentable>: View
where BottomSheetPositionEnum.RawValue == CGFloat,
      BottomSheetPositionEnum: CaseIterable,
      BottomSheetPositionEnum: Equatable {
    
    @Binding fileprivate var bottomSheetPosition: BottomSheetPositionEnum
    
    fileprivate var trueHeight: Binding<Double>?
    
    @State fileprivate var translation: CGFloat = .zero
    @State fileprivate var isScrollEnabled: Bool = false
    @State fileprivate var dragState: DragGesture.DragState = .none
    
    fileprivate let options: [BottomSheet.Options]
    fileprivate let headerContent: HContent?
    fileprivate let mainContent: MContent
    
    fileprivate let allCases = BottomSheetPositionEnum.allCases.sorted(by: { $0.rawValue < $1.rawValue })
    
    // Position
    fileprivate var isHiddenPosition: Bool {
        return self.bottomSheetPosition.rawValue == 0
    }
    
    fileprivate var isBottomPosition: Bool {
        if !self.options.noBottomPosition, let bottomPosition = self.allCases.first(where: { $0.rawValue != 0}) {
            return self.bottomSheetPosition == bottomPosition
        } else {
            return false
        }
    }
    
    fileprivate var isTopPosition: Bool {
        if let topPosition = self.allCases.last {
            return self.bottomSheetPosition == topPosition
        } else {
            return false
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Full sceen background used for .backgroundBlur and .tapToDissmiss
            if !self.isHiddenPosition && (self.options.backgroundBlur || self.options.tapToDismiss) {
                EffectView(effect: self.options.backgroundBlurEffect)
                    .opacity(self.opacityValue(geometry: geometry))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: self.tapToDismiss)
                    .transition(.opacity)
            }
            
            VStack(spacing: 0) {
                // Drag indicator
                if !self.options.notResizeable && !self.options.noDragIndicator {
                    Button(action: self.switchPositionIndicator, label: {
                        Capsule()
                            .fill(self.options.dragIndicatorColor)
                            .frame(width: 36, height: 5)
                            .padding(.top, 5)
                            .padding(.bottom, 7)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        self.translation = value.translation.height
                                        self.endEditing()
                                    }
                                    .onEnded { value in
                                        let height: CGFloat = value.translation.height / geometry.size.height
                                        self.switchPosition(with: height)
                                    }
                            )
                    })
                }
                
                // Header
                if self.headerContent != nil || self.options.showCloseButton {
                    HStack(alignment: .top, spacing: 0) {
                        // Header content
                        if let headerContent = self.headerContent {
                            headerContent
                        }
                        
                        Spacer(minLength: 0)
                        
                        // Close button
                        if self.options.showCloseButton {
                            Button(action: self.closeButton) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                            .font(.title)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !self.options.notResizeable {
                                    self.translation = value.translation.height
                                    self.endEditing()
                                }
                            }
                            .onEnded { value in
                                if !self.options.notResizeable {
                                    let height: CGFloat = value.translation.height / geometry.size.height
                                    self.switchPosition(with: height)
                                }
                            }
                    )
                    .padding(.horizontal)
                    .padding(.top, self.options.notResizeable || self.options.noDragIndicator ? 20 : 0)
                    .padding(.bottom, self.headerContentPadding(geometry: geometry))
                }
                
                // Content
                Group {
                    if !self.isBottomPosition {
                        Group {
                            if self.options.appleScrollBehavior && !self.options.notResizeable {
                                // Content for .appleScrollBehavior
                                UIScrollViewWrapper(isScrollEnabled: self.$isScrollEnabled,
                                                    dragState: self.$dragState) {
                                    self.mainContent
                                }
                                .gesture(
                                    self.isScrollEnabled ? nil :
                                        DragGesture()
                                        .onChanged { value in
                                            if self.isTopPosition && value.translation.height < 0 {
                                                self.dragState = .changed(value: value)
                                                self.translation = 0
                                            } else {
                                                self.dragState = .none
                                                self.translation = value.translation.height
                                            }
                                            self.endEditing()
                                        }
                                        .onEnded { value in
                                            if value.translation.height < 0 && self.isTopPosition {
                                                self.dragState = .ended(value: value)
                                                self.translation = 0
                                                self.isScrollEnabled = true
                                            } else {
                                                self.dragState = .none
                                                let height: CGFloat = value.translation.height / geometry.size.height
                                                self.switchPosition(with: height)
                                            }
                                        }
                                )
                            } else if self.options.allowContentDrag && !self.options.notResizeable {
                                // Content for .allowContentDrag
                                self.mainContent
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                self.translation = value.translation.height
                                                self.endEditing()
                                            }
                                            .onEnded { value in
                                                let height: CGFloat = value.translation.height / geometry.size.height
                                                self.switchPosition(with: height)
                                            }
                                    )
                            } else {
                                // Default content
                                self.mainContent
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .padding(.bottom,
                                 self.options.disableBottomSafeAreaInsets ? nil : geometry.safeAreaInsets.bottom)
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            .edgesIgnoringSafeArea(.bottom)
            .background(
                // Sheet background
                self.options.background
                    .cornerRadius(self.options.cornerRadius, corners: [.topRight, .topLeft])
                    .edgesIgnoringSafeArea(.bottom)
                    .shadow(color: self.options.shadowColor,
                            radius: self.options.shadowRadius,
                            x: self.options.shadowX,
                            y: self.options.shadowY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !self.options.notResizeable {
                                    self.translation = value.translation.height
                                    self.endEditing()
                                }
                            }
                            .onEnded { value in
                                if !self.options.notResizeable {
                                    let height: CGFloat = value.translation.height / geometry.size.height
                                    self.switchPosition(with: height)
                                }
                            }
                    )
            )
            .frame(
                width: geometry.size.width, 
                height: {
                    let value = self.frameHeightValue(geometry: geometry)
                    
                    if let binding: Binding<Double> = trueHeight {
                        binding.wrappedValue = value
                    }
                    
                    return value
                }(), 
                alignment: .top
            )
            .offset(y: self.offsetYValue(geometry: geometry))
            .transition(.move(edge: .bottom))
        }
        .animation(self.options.animation, value: self.bottomSheetPosition)
        .animation(self.options.animation, value: self.translation)
        .animation(self.options.animation, value: self.isScrollEnabled)
        .animation(self.options.animation, value: self.options)
    }
    
    // Functions
    fileprivate func opacityValue(geometry: GeometryProxy) -> Double {
        if self.options.backgroundBlur {
            if self.options.absolutePositionValue {
                return Double(
                    (self.bottomSheetPosition.rawValue - self.translation) / geometry.size.height
                )
            } else {
                return Double(
                    (self.bottomSheetPosition.rawValue * geometry.size.height - self.translation) / geometry.size.height
                )
            }
        } else {
            return 0
        }
    }
    
    fileprivate func headerContentPadding(geometry: GeometryProxy) -> CGFloat {
        if self.isBottomPosition {
            return geometry.safeAreaInsets.bottom + 25
        } else if self.headerContent == nil &&
                    !self.options.showCloseButton {
            return 20
        } else {
            return 0
        }
    }
    
    fileprivate func frameHeightValue(geometry: GeometryProxy) -> Double {
        if self.options.absolutePositionValue {
            return min(
                max(
                    self.bottomSheetPosition.rawValue - self.translation,
                    0
                ),
                geometry.size.height * 1.05
            )
        } else {
            return min(
                max(
                    (geometry.size.height * self.bottomSheetPosition.rawValue) - self.translation,
                    0
                ),
                geometry.size.height * 1.05
            )
        }
    }
    
    fileprivate func offsetYValue(geometry: GeometryProxy) -> Double {
        if self.isHiddenPosition {
            return max(
                geometry.size.height + geometry.safeAreaInsets.bottom,
                geometry.size.height * -0.05
            )
        } else if self.isBottomPosition {
            if self.options.absolutePositionValue {
                return max(
                    geometry.size.height - self.bottomSheetPosition.rawValue +
                    self.translation + geometry.safeAreaInsets.bottom,
                    geometry.size.height * -0.05
                )
            } else {
                return max(
                    geometry.size.height - (geometry.size.height * self.bottomSheetPosition.rawValue) +
                    self.translation + geometry.safeAreaInsets.bottom,
                    geometry.size.height * -0.05
                )
            }
        } else {
            if self.options.absolutePositionValue {
                return max(
                    geometry.size.height - self.bottomSheetPosition.rawValue + self.translation,
                    geometry.size.height * -0.05
                )
            } else {
                return max(
                    geometry.size.height - (geometry.size.height * self.bottomSheetPosition.rawValue) +
                    self.translation,
                    geometry.size.height * -0.05
                )
            }
        }
    }
    
    fileprivate func endEditing() {
        UIApplication.shared.endEditing()
    }
    
    fileprivate func tapToDismiss() {
        if self.options.tapToDismiss {
            self.closeSheet()
        }
    }
    
    fileprivate func closeButton() {
        self.options.closeAction()
        self.closeSheet()
    }
    
    fileprivate func closeSheet() {
        if let hiddenPosition = BottomSheetPositionEnum(rawValue: 0) {
            self.bottomSheetPosition = hiddenPosition
        }
        self.endEditing()
    }
    
    fileprivate func switchPositionIndicator() {
        if !self.isHiddenPosition &&
            self.allCases.count > 1 {
            if let currentIndex = self.allCases.firstIndex(where: { $0 == self.bottomSheetPosition }) {
                if currentIndex == self.allCases.endIndex - 1 {
                    if self.allCases[currentIndex - 1].rawValue != 0 {
                        self.bottomSheetPosition = self.allCases[currentIndex - 1]
                    }
                } else {
                    self.bottomSheetPosition = self.allCases[currentIndex + 1]
                }
                
                self.endEditing()
            }
        }
    }
    
    fileprivate func switchPosition(with height: CGFloat) {
        if !self.isHiddenPosition {
            if let currentIndex = self.allCases.firstIndex(where: { $0 == self.bottomSheetPosition }),
               self.allCases.count > 1 {
                if self.options.disableFlickThrough {
                    self.switchPositonWithoutFlickThrough(with: height, currentIndex: currentIndex)
                } else {
                    self.switchPositonWithFlickThrough(with: height, currentIndex: currentIndex)
                }
            }
            
            self.translation = 0
            self.endEditing()
        }
    }
    
    fileprivate func switchPositonWithoutFlickThrough(with height: CGFloat, currentIndex: Int) {
        if height <= -0.1 {
            if currentIndex < self.allCases.endIndex - 1 {
                self.bottomSheetPosition = self.allCases[currentIndex + 1]
            }
        } else if height >= 0.1 {
            if currentIndex > self.allCases.startIndex &&
                (self.allCases[currentIndex - 1].rawValue != 0 ||
                 (self.allCases[currentIndex - 1].rawValue == 0 &&
                  self.options.swipeToDismiss)
                ) {
                self.bottomSheetPosition = self.allCases[currentIndex - 1]
            }
        }
    }
    
    fileprivate func switchPositonWithFlickThrough(with height: CGFloat, currentIndex: Int) {
        if height <= -0.1 && height > -0.3 {
            if currentIndex < self.allCases.endIndex - 1 {
                self.bottomSheetPosition = self.allCases[currentIndex + 1]
            }
        } else if height <= -0.3 {
            self.bottomSheetPosition = self.allCases[self.allCases.endIndex - 1]
        } else if height >= 0.1 && height < 0.3 {
            if currentIndex > self.allCases.startIndex &&
                (self.allCases[currentIndex - 1].rawValue != 0 ||
                 (self.allCases[currentIndex - 1].rawValue == 0 &&
                  self.options.swipeToDismiss)
                ) {
                self.bottomSheetPosition = self.allCases[currentIndex - 1]
            }
        } else if height >= 0.3 {
            if (self.allCases[self.allCases.startIndex].rawValue == 0 &&
                self.options.swipeToDismiss) ||
                self.allCases[self.allCases.startIndex].rawValue != 0 {
                self.bottomSheetPosition = self.allCases[self.allCases.startIndex]
            } else {
                self.bottomSheetPosition = self.allCases[self.allCases.startIndex + 1]
            }
        }
    }
    
    // Initializer
    init(bottomSheetPosition: Binding<BottomSheetPositionEnum>,
         trueHeight: Binding<Double>? = nil,
         options: [BottomSheet.Options],
         @ViewBuilder headerContent: () -> HContent?,
         @ViewBuilder mainContent: () -> MContent) {
        self._bottomSheetPosition = bottomSheetPosition
        self.trueHeight = trueHeight
        self.options = options
        self.headerContent = headerContent()
        self.mainContent = mainContent()
    }
}

internal extension BottomSheetView
where HContent == ModifiedContent<ModifiedContent<Text, _EnvironmentKeyWritingModifier<Int?>>, _PaddingLayout> {
    init(bottomSheetPosition: Binding<BottomSheetPositionEnum>,
         trueHeight: Binding<Double>? = nil,
         options: [BottomSheet.Options],
         title: String?,
         @ViewBuilder content: () -> MContent) {
        if title == nil {
            self.init(bottomSheetPosition: bottomSheetPosition,
                      trueHeight: trueHeight,
                      options: options,
                      headerContent: { return nil },
                      mainContent: content)
        } else {
            let hContent = Text(title!).font(.title).bold().lineLimit(1).padding(.bottom) as? HContent
            self.init(bottomSheetPosition: bottomSheetPosition,
                      trueHeight: trueHeight,
                      options: options,
                      headerContent: { hContent },
                      mainContent: content)
        }
    }
}
