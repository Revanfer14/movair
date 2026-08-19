import Foundation

enum BiologicalSexForFormula: Double {
    case male = 1
    case female = 2
}

enum MinuteVentilationEstimator {

    private static let fvcInterceptMale = -3.349
    private static let fvcAgeCoefficientMale = -0.0224
    private static let fvcHeightCoefficientMale = 0.0458

    private static let fvcInterceptFemale = -1.533
    private static let fvcAgeCoefficientFemale = -0.0200
    private static let fvcHeightCoefficientFemale = 0.0305

    private static let ventilationRateScale = exp(-9.59)
    private static let heartRateExponent = 2.39
    private static let ageExponent = 0.274
    private static let sexExponent = -0.204
    private static let fvcExponent = 0.520
    private static let litersPerMinuteToCubicMetersPerMinute = 1.0 / 1000.0

    static func estimatedFVC(
        ageYears: Double,
        heightCm: Double,
        sex: BiologicalSexForFormula
    ) -> Double {
        switch sex {
        case .male:
            return fvcInterceptMale
                + fvcAgeCoefficientMale * ageYears
                + fvcHeightCoefficientMale * heightCm
        case .female:
            return fvcInterceptFemale
                + fvcAgeCoefficientFemale * ageYears
                + fvcHeightCoefficientFemale * heightCm
        }
    }

    static func estimatedVentilationRate(
        heartRateBPM: Double,
        ageYears: Double,
        sex: BiologicalSexForFormula,
        fvcLiters: Double
    ) -> Double {
        let ventilationRateLitersPerMinute = ventilationRateScale
            * pow(heartRateBPM, heartRateExponent)
            * pow(ageYears, ageExponent)
            * pow(sex.rawValue, sexExponent)
            * pow(fvcLiters, fvcExponent)
        return ventilationRateLitersPerMinute * litersPerMinuteToCubicMetersPerMinute
    }
}
