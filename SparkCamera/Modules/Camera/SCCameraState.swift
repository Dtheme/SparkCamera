enum SCTimerState: Int {
    case off = 0
    case s3 = 3
    case s5 = 5
    case s10 = 10
    
    var title: String {
        switch self {
        case .off:
            return "关闭"
        case .s3:
            return "3秒"
        case .s5:
            return "5秒"
        case .s10:
            return "10秒"
        }
    }
    
    var seconds: Int {
        return self.rawValue
    }
} 