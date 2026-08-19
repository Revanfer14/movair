import SwiftUI

struct OnboardingWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - 70))
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h - 55),
            control1: CGPoint(x: w * 0.05, y: h + 10),
            control2: CGPoint(x: w * 0.32, y: h + 10)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h - 50),
            control1: CGPoint(x: w * 0.72, y: h - 105),
            control2: CGPoint(x: w * 0.88, y: h - 80)
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
            let w = geometry.size.width
            let safeTop = geometry.safeAreaInsets.top
            let heroHeight = max(380, geometry.size.height * 0.58)

            ZStack(alignment: .top) {
                Color.Brand.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ForEach(pages) { page in
                            pageContent(page, width: w, heroHeight: heroHeight, safeTop: safeTop)
                                .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    bottomControls
                }
            }
        }
        .ignoresSafeArea()
    }

    private func pageContent(_ page: OnboardingPage, width: CGFloat, heroHeight: CGFloat, safeTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Color.Brand.blue900

                heroImage(for: page, width: width, height: heroHeight, safeTop: safeTop)
            }
            .frame(width: width, height: heroHeight)
            .clipShape(OnboardingWaveShape())
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

            Spacer(minLength: 12)

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

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func heroImage(for page: OnboardingPage, width: CGFloat, height: CGFloat, safeTop: CGFloat) -> some View {
        switch page.id {
        case 0:
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width, maxHeight: height - safeTop - 10, alignment: .leading)
                .scaleEffect(1.5)
                .offset(x: -65, y: -40)
                .padding(.bottom, 20)
        case 1:
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width * 0.95, maxHeight: height - safeTop - 30, alignment: .bottom)
                .scaleEffect(1.5)
                .offset(x: 0, y: 100)
                .padding(.top, safeTop + 8)
                .padding(.bottom, 16)
        default:
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width * 0.95, maxHeight: height - safeTop - 30, alignment: .bottom)
                .scaleEffect(1.6)
                .offset(x: -98, y: -90)
                .padding(.top, safeTop + 8)
                .padding(.bottom, 16)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
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
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
