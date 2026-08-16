## Purpose

完成状态下不再显示"重新开始"按钮（右键菜单已提供同功能入口），避免重复入口；完成态不显示任何操作按钮。

## MODIFIED Requirements

### Requirement: 完成状态展示
当背记队列中所有 Section 全部完成时，悬浮窗 SHALL 停止单词切换，居中显示"已学完"文字。完成状态下悬浮窗 SHALL 不显示任何操作按钮，"重新开始"入口由右键菜单提供。

#### Scenario: 全部学完
- **WHEN** 队列中所有 Section 完成
- **THEN** 悬浮窗 SHALL 居中显示"已学完"文字，停止单词切换

#### Scenario: 已学完状态悬停
- **WHEN** 悬浮窗处于"已学完"状态，鼠标悬停
- **THEN** 窗口 SHALL 不显示任何操作按钮，"重新开始"由右键菜单提供

#### Scenario: 点击重新开始
- **WHEN** 用户在"已学完"状态通过右键菜单点击"重新开始"
- **THEN** 系统 SHALL 从队列第一个 Section 重新开始背记
