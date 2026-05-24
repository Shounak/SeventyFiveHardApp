import Foundation
import HealthKit
import Observation

@Observable
final class WaterReader {
    static let goalFlOz: Double = 128

    private(set) var ounces: Double = 0
    private(set) var authStatus: AuthStatus = .unknown

    enum AuthStatus { case unknown, denied, authorized, unavailable }

    private let store = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private var waterType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .dietaryWater)
    }

    var metGoal: Bool { ounces >= Self.goalFlOz }

    func requestAuthorizationAndStartObserving() async {
        guard HKHealthStore.isHealthDataAvailable(), let waterType else {
            authStatus = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [waterType])
            authStatus = .authorized
            await refresh()
            startObserving(type: waterType)
        } catch {
            authStatus = .denied
        }
    }

    func refresh() async {
        guard let waterType else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit.fluidOunceUS()

        let total: Double = await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
        ounces = total
    }

    private func startObserving(type: HKQuantityType) {
        if let existing = observerQuery {
            store.stop(existing)
        }
        let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, _, _ in
            Task { await self?.refresh() }
        }
        observerQuery = q
        store.execute(q)
    }

    /// Returns the total fl oz consumed on a given day (used for past-day reset checks).
    func ouncesOn(date: Date) async -> Double {
        guard let waterType else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit.fluidOunceUS()
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }
}
