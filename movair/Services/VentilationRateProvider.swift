import Foundation

protocol VentilationRateProvider {
    func prepare() async
    func ventilationRate(heartRateBPM: Double) -> Double
}

final class ConstantVentilationRate: VentilationRateProvider {
    private static let fallbackRateCubicMetersPerMinute = 0.040

    func prepare() async {}

    func ventilationRate(heartRateBPM: Double) -> Double {
        Self.fallbackRateCubicMetersPerMinute
    }
}
