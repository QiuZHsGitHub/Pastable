import Foundation

/// Storage-specific errors
enum StorageError: LocalizedError {
    case containerInitializationFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case cleanupFailed(underlying: Error)
    case initializationFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .containerInitializationFailed(let error):
            return "无法初始化数据库：\(error.localizedDescription)"
        case .fetchFailed(let error):
            return "获取数据失败：\(error.localizedDescription)"
        case .cleanupFailed(let error):
            return "清理数据失败：\(error.localizedDescription)"
        case .initializationFailed(let error):
            return "初始化失败：\(error.localizedDescription)"
        }
    }
}

/// Application-specific errors with user-friendly descriptions
enum AppError: LocalizedError {
    case storageInitializationFailed(underlying: Error)
    case clipboardAccessDenied
    case clipboardReadFailed(reason: String)
    case itemStorageFailed(reason: String)
    case itemRetrievalFailed(reason: String)
    case invalidContent(reason: String)
    case imageProcessingFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .storageInitializationFailed(let error):
            return "无法初始化数据库，请检查权限设置。"
        case .clipboardAccessDenied:
            return "无法访问剪贴板，请授予剪贴板权限。"
        case .clipboardReadFailed(let reason):
            return "读取剪贴板失败：\(reason)"
        case .itemStorageFailed(let reason):
            return "保存项目失败：\(reason)"
        case .itemRetrievalFailed(let reason):
            return "获取项目失败：\(reason)"
        case .invalidContent(let reason):
            return "无效的内容：\(reason)"
        case .imageProcessingFailed(let reason):
            return "图片处理失败：\(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .storageInitializationFailed:
            return "尝试重启应用，或重置应用数据。"
        case .clipboardAccessDenied:
            return "前往系统设置 > 隐私与安全 > 剪贴板，授予应用权限。"
        case .clipboardReadFailed:
            return "稍后重试，或检查是否有其他应用正在访问剪贴板。"
        case .itemStorageFailed, .itemRetrievalFailed:
            return "尝试删除一些历史记录，或重启应用。"
        case .invalidContent:
            return "请复制有效的内容。"
        case .imageProcessingFailed:
            return "尝试复制更小的图片，或使用不同的图片格式。"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .storageInitializationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

/// Clipboard-specific errors
enum ClipboardError: LocalizedError {
    case pasteboardUnavailable
    case invalidContentType
    case dataExtractionFailed(reason: String)
    case noPlainTextToPaste
    
    var errorDescription: String? {
        switch self {
        case .pasteboardUnavailable:
            return "剪贴板不可用。"
        case .invalidContentType:
            return "不支持的内容类型。"
        case .dataExtractionFailed(let reason):
            return "提取数据失败：\(reason)"
        case .noPlainTextToPaste:
            return "无法获取纯文本用于粘贴。"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .pasteboardUnavailable:
            return "尝试重启应用或系统。"
        case .invalidContentType:
            return "复制文本、图片或链接。"
        case .dataExtractionFailed:
            return "尝试复制不同的内容。"
        case .noPlainTextToPaste:
            return "复制文本内容后再试。"
        }
    }
}
