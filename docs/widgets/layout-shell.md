# layout & shell —— 页面壳层和容器

## 应用壳层

- `AppDesktopShell`：`lib/widgets/shell/desktop/app_desktop_shell.dart`，桌面工作台容器。
- `AppSidebar`、`AppSidebarGroup`、`AppSidebarItem`：`app_sidebar.dart`，桌面导航分组和条目。
- `AppVersionInfoCard`：`app_version_info_card.dart`，应用版本与可用更新提示。
- `AppTopBar`：`app_top_bar.dart`，桌面页面顶栏和操作区。
- `AppMobileShell`、`AppMobileSubpageShell`：`lib/widgets/shell/mobile/`，移动一级入口和子页面容器。
- `AppWindowDragArea`：`lib/widgets/shell/window/`，桌面窗口拖拽区。

新页面先选择对应平台 shell，再在内容区编排 feature 页面；不要在 feature 页面重新搭一套应用级导航。

## 页面和卡片容器

- `AppPageFrame`：页面最大宽度、边距和滚动内容容器。
- `AppContentCard`：承载一组内容或表单的卡片。
- `AppSettingsGroup`、`AppSettingCell`、`AppSettingIconBox`、`AppSettingCellChevron`、`AppSettingsRail`：设置页分组、条目和桌面设置导航。
- `AppNoticeCard` / `AppNoticeStat`：页面顶部说明和统计摘要。
- `AppStatTile`：突出数字统计；`AppInfoBlock`：标签和值的普通信息块。
- `AppBadge`：小型徽标或状态标记。

这些组件位于 `lib/widgets/base/layout/cards/`。尺寸和间距走 theme token，页面只传语义内容和必要布局参数。


## 固定列表控制栏与吸顶

- `AppFixedHeaderLayout`：`lib/widgets/base/layout/scrolling/app_fixed_header_layout.dart`。`header` 自然占高，`child` 在剩余空间内滚动，适用于影片、女优、排行、搜索和管理列表。结果加载层放在 `child` 内，不覆盖固定控制栏。
- `AppPinnedListHeader`：同目录 `app_pinned_list_header.dart`。用于资料/合集预览之后的控制栏，保持一个主滚动容器。必须传页面对应的主题背景色，避免卡片从栏内透出；正常/多选内容在同一个头中替换。
- 吸顶页面切筛选时，使用控制栏的稳定 `GlobalKey` 和原滚动控制器调用 `AppPinnedListHeader.scrollToStart`。已经滚过介绍区时回到结果起点，尚未滚过时保留位置。
- `AppFilterResultLoadingOverlay` 在吸顶页面传相同的 `protectedHeaderKey` 和 `scrollController`，按实际头部位置裁剪结果遮罩，兼容头部动态高度。
- `AppAdaptiveRefreshScrollView` / `AppPullToRefresh` 在下拉期间发送 `AppPullRefreshNotification`，外层结果加载层据此暂停筛选加载标记。桌面页刷新和正常筛选不受影响，页面无需再维护一份图标互斥状态。

页面保留自己的滚动控制器、缓存键、Provider 和分页回调；不通过嵌套纵向列表或全量 `shrinkWrap` 网格实现固定栏。已有固定的合集详情布局可直接沿用。

## 桌面一级页面保留

`DesktopBranchCache` 配合桌面一级导航的 StatefulShellRoute，按最近访问顺序最多保留 8 个分支；未访问页面不挂载，详情不加入缓存。隐藏分支停用 TickerMode 和焦点，离开桌面 shell 时一起释放。

## TabBarView 页面保留

`AppKeepAlive` 位于 `lib/widgets/base/layout/keep_alive_page.dart`。它只保留已访问的 `PageView` / `TabBarView` 子页 Widget 生命周期，用于输入、滚动和局部交互在切换标签后恢复；不要用它把页面 Provider 提升为全局常驻状态。
