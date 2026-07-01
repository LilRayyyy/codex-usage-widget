public enum HeatmapScale {
    public static func intensity(for tokens: Int, maximum: Int) -> Int {
        guard tokens > 0 else { return 0 }
        guard maximum > 0 else { return 1 }

        let ratio = min(Double(tokens) / Double(maximum), 1.0)
        switch ratio {
        case 0..<0.25:
            return 1
        case 0.25..<0.5:
            return 2
        case 0.5..<0.75:
            return 3
        default:
            return 4
        }
    }
}
