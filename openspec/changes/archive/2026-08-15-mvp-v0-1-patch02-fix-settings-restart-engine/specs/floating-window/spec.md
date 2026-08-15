Change-Sub-Version: mvp-v0-1-patch02

## MODIFIED Requirements

### Requirement: 悬浮窗外观响应外观通知
悬浮窗内容视图 SHALL 监听 `.appAppearanceDidChange` 通知以刷新外观样式（背景色、字体、透明度、文字颜色等），不再监听 `.appSettingsDidChange` 通知。

#### Scenario: 外观设置变更刷新悬浮窗
- **WHEN** 系统发送 `.appAppearanceDidChange` 通知
- **THEN** 悬浮窗内容视图 SHALL 使用过渡动效刷新背景色、字体、透明度等外观属性

#### Scenario: 背记规则变更不刷新外观
- **WHEN** 系统发送 `.appSettingsDidChange` 通知（背记规则变更）
- **THEN** 悬浮窗内容视图 SHALL 不触发外观刷新（外观由 `.appAppearanceDidChange` 独立控制）
