//
//  Copyright 2024, Jamf
//

import SwiftUI

enum Phase: CaseIterable {
    case initial
    case moveToMiddle
    case moveToEnd
    case moveToBackToStart

    var horizontalOffset: Double {
        switch self {
        case .initial: -100
        case .moveToMiddle: 0
        case .moveToEnd: 100
        case .moveToBackToStart: -100
        }
    }

    var verticalOffset: Double {
        switch self {
        case .initial: 0
        case .moveToMiddle: -10
        case .moveToEnd: 0
        case .moveToBackToStart: 0
        }
    }

    var scale: Double {
        switch self {
        case .initial: 1.0
        case .moveToMiddle: 1.1
        case .moveToEnd: 1.0
        case .moveToBackToStart: 1.0
        }
    }

    var opacity: Double {
        switch self {
        case .initial: 0.0
        case .moveToMiddle: 1.0
        case .moveToEnd: 0.0
        case .moveToBackToStart: 0.0
        }
    }
}

struct PackageAnimationView: View {
    @State var trigger = 0

    var body: some View {
        HStack {
            Image("pkgIcon")
                .phaseAnimator(
                    Phase.allCases,
                    trigger: trigger
                ) { content, phase in
                    content
                        .scaleEffect(phase.scale)
                        .offset(x: phase.horizontalOffset)
                        .offset(y: phase.verticalOffset)
                        .opacity(phase.opacity)
                } animation: { phase in
                    animationForPhase(phase: phase)
                }
        }
        .frame(width: 200, height: 50)
        .onAppear() {
            trigger += 1
        }
    }

    func animationForPhase(phase: Phase) -> Animation {
        switch phase {
        case .initial: return .smooth(duration: 0.0)
        case .moveToMiddle: return .easeIn(duration: 1.0)
        case .moveToEnd: return .easeOut(duration: 1.0)
        case .moveToBackToStart:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                trigger += 1 // Once the animation is complete, trigger it again
            }
            return .smooth(duration: 0.0)
        }
    }
}

struct PackageAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        PackageAnimationView()
    }
}

struct BackAndForthAnimation: View {
    @Binding var leftOffset: CGFloat
    @Binding var rightOffset: CGFloat

    var body: some View {
        HStack {
            ZStack {
                Image("pkgIcon")
                    .offset(x: leftOffset)
                    .opacity(0.7)
                    .animation(Animation.easeInOut(duration: 1), value: leftOffset)
            }
            .frame(width: 200)
        }
        .frame(width: 210, height: 50)
    }
}
