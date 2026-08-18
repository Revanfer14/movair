import SwiftUI

struct OnboardingWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - 65))
        path.addCurve(
            to: CGPoint(x: w * 0.48, y: h - 35),
            control1: CGPoint(x: w * 0.10, y: h + 14),
            control2: CGPoint(x: w * 0.28, y: h + 14)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h - 45),
            control1: CGPoint(x: w * 0.68, y: h - 80),
            control2: CGPoint(x: w * 0.88, y: h - 40)
        )
        path.addLine(to: CGPoint(x: w, y: 0))
        path.closeSubpath()
        return path
    }
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            imageName: "OnboardingHero1",
            title: "Every ride comes with exposure",
            description: "Pollution levels can change across roads and throughout the day."
        ),
        OnboardingPage(
            id: 1,
            imageName: "OnboardingHero2",
            title: "See what's ahead",
            description: "Get an estimated PM2.5 exposure forecast for your ride"
        ),
        OnboardingPage(
            id: 2,
            imageName: "OnboardingHero3",
            title: "Make every ride a smarter ride.",
            description: "Compare your exposure and plan when and where to ride"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            let heroHeight = max(380, geometry.size.height * 0.54)

            ZStack {
                Color.Brand.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ForEach(pages) { page in
                            pageContent(page, heroHeight: heroHeight)
                                .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(edges: .top)

                    bottomControls
                }
            }
        }
    }

    private func pageContent(_ page: OnboardingPage, heroHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Color.Brand.blue900
                    .clipShape(OnboardingWaveShape())
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
                    .ignoresSafeArea(edges: .top)

                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .padding(.top, 24)
            }
            .frame(height: heroHeight)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.Brand.labelPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(page.description)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.Brand.labelPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)
        }
        .background(Color.Brand.white)
    }

    private var bottomControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == currentPage
                                ? Color.Brand.blue900
                                : Color.Brand.blue900.opacity(0.2)
                        )
                        .frame(width: 7, height: 7)
                }
            }

            PrimaryButton(
                title: currentPage == pages.count - 1 ? "Get Started" : "Next"
            ) {
                if currentPage < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onFinish()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.Brand.white)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
