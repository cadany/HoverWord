import CoreData

/// Core Data 持久化栈管理
///
/// 单例，负责：
/// - NSPersistentContainer 初始化与生命周期
/// - 提供主上下文与后台上下文
/// - 统一的保存与错误处理
class DataStack {
    static let shared = DataStack()

    /// 持久化容器
    private(set) lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HoverWord")

        // 启用轻量迁移：模型版本升级时自动迁移 store，不丢失数据
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(NSNumber(value: true), forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(NSNumber(value: true), forKey: NSInferMappingModelAutomaticallyOption)
            // 同步加载：让损坏时的自愈重试在 initialize() 返回前完成
            description.shouldAddStoreAsynchronously = false
        }

        var loadError: NSError?
        container.loadPersistentStores { _, error in
            loadError = error as NSError?
        }

        // 自愈：store 损坏/迁移失败时销毁重建（词库丢失但应用可用），
        // 否则每次启动命中同一损坏 store，形成永久崩溃循环
        if let error = loadError {
            NSLog("[DataStack] store 加载失败，销毁重建: \(error), \(error.userInfo)")
            if let url = container.persistentStoreDescriptions.first?.url {
                try? container.persistentStoreCoordinator.destroyPersistentStore(
                    at: url, ofType: NSSQLiteStoreType, options: nil
                )
            }
            container.loadPersistentStores { _, retryError in
                if let retryError = retryError as NSError? {
                    fatalError("Core Data 栈重建后仍加载失败: \(retryError), \(retryError.userInfo)")
                }
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
