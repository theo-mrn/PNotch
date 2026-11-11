import Foundation
import Observation

/// Live machine metrics for the System page, sampled every second while someone is watching.
@Observable
final class SystemMonitor {
    static let historyLength = 60

    private(set) var cpu: CPUUsage?
    private(set) var gpuUtilization: Double?
    private(set) var memory: MemoryUsage?
    private(set) var network: NetworkRates?
    private(set) var storage: StorageUsage?
    private(set) var battery: BatteryStatus?
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var uptime: TimeInterval = 0

    private(set) var cpuHistory = MetricHistory(capacity: historyLength)
    private(set) var gpuHistory = MetricHistory(capacity: historyLength)
    private(set) var memoryHistory = MetricHistory(capacity: historyLength)
    private(set) var downloadHistory = MetricHistory(capacity: historyLength)
    private(set) var uploadHistory = MetricHistory(capacity: historyLength)

    /// How much is read. Pixel only needs the processor's load; the System page needs everything.
    enum Detail {
        case load
        case full
    }

    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private let sampler: @Sendable () -> SystemSample
    @ObservationIgnored private let loadSampler: @Sendable () -> SystemSample
    @ObservationIgnored private var samplingTask: Task<Void, Never>?
    @ObservationIgnored private var observerCount = 0
    @ObservationIgnored private var fullObserverCount = 0
    @ObservationIgnored private var previousSample: SystemSample?

    init(
        interval: Duration = .seconds(1),
        sampler: @escaping @Sendable () -> SystemSample = SystemMetricsReader.sample,
        loadSampler: @escaping @Sendable () -> SystemSample = SystemMetricsReader.loadSample
    ) {
        self.interval = interval
        self.sampler = sampler
        self.loadSampler = loadSampler
    }

    /// Whether everything is being read, or only the load.
    var isReadingEverything: Bool {
        fullObserverCount > 0
    }

    /// Starts sampling for one more observer. Every call must be balanced by `stopObserving` with the same detail.
    func startObserving(_ detail: Detail = .full) {
        observerCount += 1
        if detail == .full {
            fullObserverCount += 1
        }
        // The first observer starts the readings; the first one wanting everything gets them at once.
        if observerCount == 1 || (detail == .full && fullObserverCount == 1) {
            restartSampling()
        }
    }

    func stopObserving(_ detail: Detail = .full) {
        observerCount = max(observerCount - 1, 0)
        if detail == .full {
            fullObserverCount = max(fullObserverCount - 1, 0)
        }
        guard observerCount == 0 else { return }
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// Everything each second while the System page shows; the load alone every other second otherwise.
    private func restartSampling() {
        samplingTask?.cancel()
        resetHistory()
        samplingTask = Task { [weak self, interval, sampler, loadSampler] in
            while !Task.isCancelled {
                guard let full = self?.isReadingEverything else { return }
                let read = full ? sampler : loadSampler
                let sample = await Task.detached(priority: .utility) { read() }.value
                guard let self, !Task.isCancelled else { return }
                apply(sample)
                try? await Task.sleep(for: full ? interval : interval * 2)
            }
        }
    }

    // MARK: Updates

    /// Rates and CPU usage need two readings: the first sample only sets the baseline for them.
    func apply(_ sample: SystemSample) {
        if let previous = previousSample {
            if let ticks = sample.cpuTicks, let previousTicks = previous.cpuTicks, let usage = ticks.usage(since: previousTicks) {
                cpu = usage
                cpuHistory.append(usage.total)
            }
            if let counters = sample.network, let previousCounters = previous.network {
                let rates = counters.rates(since: previousCounters, interval: sample.date.timeIntervalSince(previous.date))
                network = rates
                downloadHistory.append(rates.download)
                uploadHistory.append(rates.upload)
            }
        }

        if let utilization = sample.gpuUtilization {
            gpuUtilization = utilization
            gpuHistory.append(utilization)
        }
        if let memory = sample.memory {
            self.memory = memory
            memoryHistory.append(memory.fraction)
        }
        if sample.storage != nil || isReadingEverything {
            storage = sample.storage
        }
        if sample.battery != nil || isReadingEverything {
            battery = sample.battery
        }
        thermalState = sample.thermalState
        uptime = sample.uptime
        previousSample = sample
    }

    private func resetHistory() {
        previousSample = nil
        cpuHistory.removeAll()
        gpuHistory.removeAll()
        memoryHistory.removeAll()
        downloadHistory.removeAll()
        uploadHistory.removeAll()
    }
}
