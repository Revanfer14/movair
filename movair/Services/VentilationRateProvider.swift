import Foundation

protocol VentilationRateProvider: Sendable {
    func prepare() async
    func ventilationRate(heartRateBPM: Double) -> Double
}

final class ConstantVentilationRate: VentilationRateProvider, Sendable {
    func prepare() async {}

    func ventilationRate(heartRateBPM: Double) -> Double {
        DoseConstants.ventilationRateCubicMetersPerMinute
    }
}
