import Foundation
import HealthKit

private enum HealthKitProfileError: Error {
    case objectTypesUnavailable
    case missingDateOfBirth
    case missingHeight
}

final class HealthKitVentilationRateProvider: VentilationRateProvider {
    private struct Profile {
        let ageYears: Double
        let sex: BiologicalSexForFormula
        let heightCm: Double
        let fvcLiters: Double
    }

    private let healthStore = HKHealthStore()
    private let fallback: VentilationRateProvider
    private var cachedProfile: Profile?

    init(fallback: VentilationRateProvider = ConstantVentilationRate()) {
        self.fallback = fallback
    }

    func prepare() async {
        print("[HealthKit VE] prepare() started")

        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit VE] Health data NOT available on this device")
            cachedProfile = nil
            return
        }

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let heightType = HKObjectType.quantityType(forIdentifier: .height),
              let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
              let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) else {
            print("[HealthKit VE] Required HealthKit types unavailable")
            cachedProfile = nil
            return
        }

        let readTypes: Set<HKObjectType> = [heartRateType, heightType, dateOfBirthType, biologicalSexType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            print("[HealthKit VE] Authorization requested (read: DOB, sex, height, heartRate)")

            let ageYears = try resolvedAgeYears()
            let sex = resolvedSex()
            let heightCm = try await resolvedHeightCm(heightType: heightType)
            let fvc = MinuteVentilationEstimator.estimatedFVC(
                ageYears: ageYears,
                heightCm: heightCm,
                sex: sex
            )

            cachedProfile = Profile(
                ageYears: ageYears,
                sex: sex,
                heightCm: heightCm,
                fvcLiters: fvc
            )

            print("[HealthKit VE] Profile OK")
            print("[HealthKit VE]   ageYears  = \(ageYears)")
            print("[HealthKit VE]   sex       = \(sex == .female ? "female" : "male") (raw=\(sex.rawValue))")
            print("[HealthKit VE]   heightCm  = \(String(format: "%.1f", heightCm))")
            print("[HealthKit VE]   fvcLiters = \(String(format: "%.3f", fvc))")
            // Sample VE at resting HR ~70 for console visibility only
            let sampleVE = MinuteVentilationEstimator.estimatedVentilationRate(
                heartRateBPM: 70,
                ageYears: ageYears,
                sex: sex,
                fvcLiters: fvc
            )
            print("[HealthKit VE]   sample VE @70 bpm = \(String(format: "%.5f", sampleVE)) m³/min")
        } catch {
            cachedProfile = nil
            print("[HealthKit VE] prepare() FAILED: \(error)")
            print("[HealthKit VE] Falling back to ConstantVentilationRate (0.040 m³/min)")
        }
    }

    func ventilationRate(heartRateBPM: Double) -> Double {
        guard let cachedProfile else {
            return fallback.ventilationRate(heartRateBPM: heartRateBPM)
        }

        return MinuteVentilationEstimator.estimatedVentilationRate(
            heartRateBPM: heartRateBPM,
            ageYears: cachedProfile.ageYears,
            sex: cachedProfile.sex,
            fvcLiters: cachedProfile.fvcLiters
        )
    }

    private func resolvedAgeYears() throws -> Double {
        let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
        guard let dateOfBirth = Calendar.current.date(from: dateOfBirthComponents) else {
            throw HealthKitProfileError.missingDateOfBirth
        }
        guard let ageYears = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year else {
            throw HealthKitProfileError.missingDateOfBirth
        }
        return Double(ageYears)
    }

    private func resolvedSex() -> BiologicalSexForFormula {
        guard let biologicalSex = try? healthStore.biologicalSex().biologicalSex else {
            print("[HealthKit VE] biologicalSex unavailable → default male")
            return .male
        }
        switch biologicalSex {
        case .female:
            return .female
        case .male, .other, .notSet:
            if biologicalSex != .male {
                print("[HealthKit VE] biologicalSex=\(biologicalSex.rawValue) → mapped to male")
            }
            return .male
        @unknown default:
            return .male
        }
    }

    private func resolvedHeightCm(heightType: HKQuantityType) async throws -> Double {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heightType)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: healthStore)
        guard let mostRecentHeightSample = samples.first else {
            throw HealthKitProfileError.missingHeight
        }
        return mostRecentHeightSample.quantity.doubleValue(for: .meterUnit(with: .centi))
    }
}
