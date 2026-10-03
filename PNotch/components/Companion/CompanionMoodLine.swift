import Foundation

/// What Pixel says about itself: the news it just brought, or its mood.
enum CompanionMoodLine {
    static func text(name: String, companion: CompanionManager, at date: Date) -> String {
        let mood = companion.mood(at: date)
        if mood == .excited, let news = companion.lastNews?.kind {
            switch news {
            case .newTrack: return String(localized: "\(name) likes this song.")
            case .copy: return String(localized: "\(name) caught your copy!")
            case .pluggedIn: return String(localized: "\(name) plugged it in!")
            }
        }

        switch mood {
        case .content, .excited:
            return String(localized: "\(name) is keeping an eye on your Mac.")
        case .dancing:
            if let title = companion.music.playback?.title {
                return String(localized: "\(name) is dancing to “\(title)”.")
            }
            return String(localized: "\(name) is dancing.")
        case .hot:
            if let cpu = companion.system.cpu?.total, cpu >= CompanionMood.busyCPUThreshold {
                return String(localized: "\(name) is overheating: CPU at \(MetricFormatter.percent(cpu)).")
            }
            return String(localized: "\(name) is overheating: the Mac is running hot.")
        case .sleepy:
            let hour = Calendar.current.component(.hour, from: date)
            if hour >= 23 || hour < 6 {
                return String(localized: "It's late, \(name) is dozing off.")
            }
            return String(localized: "\(name) dozed off while you were away.")
        case .loved:
            return String(localized: "\(name) loves that.")
        }
    }
}
