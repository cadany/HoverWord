# 设计：Section 顺序随机化

## 核心决策

### 1. 随机化触发时机：仅"新开始"，恢复进度时队列确定性重建

队列随机化（randomStart 的 rotate、shuffled 的 permute）只在**无有效进度的新开始**时执行一次，结果随进度持久化。恢复进度时 `buildQueue()` 按固定规则（词本顺序 × 升序）重建基础队列，再由**保存的队列布局**（见下）还原实际推进序。

理由：恢复路径若重新随机，"恢复到的 Section"与"接下来的推进序"都会与保存时不同，进度语义漂移；确定性重建 + 布局还原让恢复后的队列与离开时完全一致。

### 2. 队列布局持久化（而非仅存起点）

进度新增存储「Section 布局」：随机起点存 `(起点身份)`,随机打乱存 `(完整顺序的身份列表)`。恢复时按身份把布局套到重建的基础队列上：

- `sequential`：布局 = 基础队列，无需存储
- `randomStart`：存储起点 Section 的 `(wordbookId, sectionIndex)`，恢复时队列 rotate 到该起点
- `shuffled`：存储打乱后的完整身份列表，恢复时按列表重排队列（列表中不再存在于队列的身份剔除——词本启停场景）

布局与 `AppSettings.sectionOrder` 独立：保存时的策略决定布局形态，用户中途改策略设置不影响进行中的进度（下次新开始才生效）——与既有「背记规则变化重置进度」语义一致，策略变更同样走 `handleSettingsChange` 清进度重开。

### 3. 身份寻址

进度从「队列索引」改为 `(wordbookId, sectionIndex)`：

- **保存**：`currentSectionQueueIndex` → 当前 Section 身份；`progressOrderKey`（Section 内顺序 wordId 列表）不变
- **恢复**：重建基础队列后，由布局还原实际队列，再按身份查找 `currentSectionQueueIndex`；找不到（词本已停用/Section 消失）→ 既有回退路径（清进度从策略起点开始）
- 旧格式迁移：检测到旧键（索引值）存在而新键缺失 → 视为失效清零（一次性，与既有"旧版本进度一次性失效"场景合并）

### 4. 续背语义

全部 Section 完成时（`advanceToNextSection` 越界）：

- 旧行为：`clearProgress` + `allComplete`，下次从起点重来
- 新行为：记录「续背锚点」= 完成时的最后一 Section 身份，状态仍进 `allComplete`（UI 语义不变），进度键保留
- 下次 `start()`：检测续背锚点存在 → 从锚点的**下一 Section**（环形）开始新的一轮，`restart()` 显式清除锚点与全部进度

锚点复用进度键存储（新增 `ReciteProgressLastCompletedKey` 存身份），与进行中进度互斥：进行中进度存在时锚点必为空，锚点存在时进行中进度已消费。

### 5. 随机起点 rotate 实现即队列重排

`randomStart` 在 `buildQueue` 末尾按随机起点 rotate 数组，之后所有推进逻辑（`advanceToNextSection` 的 `+1` 与越界判定）零改动——环形语义由 rotate 天然表达（起点后的顺序推进，末尾即队列末，绕回即新起点所在队列头）。

## 边界场景

| 场景 | 行为 |
| --- | --- |
| 恢复进度时保存的起点身份不在队列（词本停用） | 布局失效 → 清进度从当前策略起点重新随机开始 |
| shuffled 布局列表含已消失身份 | 剔除后重排；列表空 → 同上 |
| 单 Section 词书（含收藏夹） | randomStart/shuffled 退化为 sequential（无随机空间），不报错 |
| 策略设置变更（进行中） | 走既有 `handleSettingsChange` 清进度重开，新策略立即生效 |
| 旧版本进度（索引寻址） | 首次启动检测格式失效 → 清零从策略起点开始 |
| 续背锚点的下一 Section 越界（完成的是队列最后一个 Section） | 环形绕回队列第一个 Section |
| 10000 词库 | 队列构建在既有性能预算内（500 Section rotate/shuffle 为 O(n)） |

## 测试策略

引擎纯逻辑（队列构建/进度存取/续背）用 UserDefaults 注入临时 suite 隔离测试；随机性测试断言**性质**而非具体值（如 randomStart 后队列是原队列的 rotate 结果、shuffled 是排列、多次新开始分布覆盖多个起点——统计断言容差放宽）。
