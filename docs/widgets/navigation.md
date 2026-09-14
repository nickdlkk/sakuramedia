# navigation —— Tab、列表头和筛选入口

## `AppTabBar`

路径：`lib/widgets/base/navigation/app_tab_bar.dart`

统一桌面、紧凑和移动顶部 Tab 的样式与选中态。Tab 的数据和切换行为由页面或路由负责。

## `AppListHeader`

路径：`app_list_header.dart`

列表页标题、筛选入口、结果信息和操作槽的统一容器。`AppListHeaderInfo` 用于显示总数、更新时间等辅助信息。

固定或吸顶由页面布局负责：普通列表用 `AppFixedHeaderLayout`，介绍区后的列表用 `AppPinnedListHeader`。`AppListHeader` 本身不控制滚动。多选时使用 `AppListHeader.selection` 在同一位置替换正常内容；移动批量操作放在结果区之外的底部操作条。

标签影片页用 feature 内的 `TagSelectionHeader` 固定选择入口、横向已选摘要和匹配模式；完整 `TagSelectorPanel` 在移动底部抽屉或桌面浮层内滚动，选择即时生效。

## `AppFilterEntryButton`

路径：`app_filter_entry_button.dart`

列表页打开筛选浮层或抽屉的入口。当前筛选摘要由调用方提供。

## `AppMobileFilterDrawerScaffold`

路径：`app_mobile_filter_drawer_scaffold.dart`

移动筛选抽屉的标题、内容和底部操作结构。筛选值和提交动作仍由 feature 管理。

新列表页优先组合 `AppListHeader` + 页面已有筛选容器，不要为每个 feature 重新实现顶栏布局。
