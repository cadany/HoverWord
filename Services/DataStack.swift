import CoreData

/// Core Data 持久化栈管理
///
/// 单例，负责：
/// - NSPersistentContainer 初始化与生命周期
/// - 提供主上下文与后台上下文
/// - 统一的保存与错误处理
///
/// 当前为骨架实现，Core Data 模型文件尚未创建。
/// 任务 2.1 创建 xcdatamodeld 后，此处将自动加载模型。
class DataStack {
    static let shared = DataStack()

    /// 持久化容器
    private(set) lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HoverWord")

        // 启用轻量迁移：模型版本升级时自动迁移 store，不丢失数据
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(NSNumber(value: true), forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(NSNumber(value: true), forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data 栈加载失败: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    /// 主上下文（UI 线程使用）
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {}

    /// 初始化栈（触发 lazy 加载）
    func initialize() {
        _ = persistentContainer
    }

    /// 创建新的后台上下文，用于批量写入操作
    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }

    /// 在后台上下文中执行闭包，自动处理保存
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    /// 保存主上下文
    func saveContext() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Core Data 保存失败: \(nsError), \(nsError.userInfo)")
        }
    }
}
