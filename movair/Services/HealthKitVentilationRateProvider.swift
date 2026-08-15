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
        let fvcLiters: Double
    }

    private let healthStore = HKHealthStore()
    private let fallback: VentilationRateProvider
    private var cachedProfile: Profile?

    init(fallback: VentilationRateProvider = ConstantVentilationRate()) {
        self.fallback = fallback
    }

    func prepare() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let heightType = HKObjectType.quantityType(forIdentifier: .height),
              let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
              let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) else {
            cachedProfile = nil
            return
        }

        let readTypes: Set<HKObjectType> = [heartRateType, heightType, dateOfBirthType, biologicalSexType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)

            let ageYears = try resolvedAgeYears()
            let sex = resolvedSex()
            let heightCm = try await resolvedHeightCm(heightType: heightType)

            cachedProfile = Profile(
                ageYears: ageYears,
                sex: sex,
                fvcLiters: MinuteVentilationEstimator.estimatedFVC(
                    ageYears: ageYears,
                    heightCm: heightCm,
                    sex: sex
                )
            )
        } catch {
            cachedProfile = nil
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
            return .male
        }
        switch biologicalSex {
        case .female:
            return .female
        case .male, .other, .notSet:
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
