# SakuraMedia UI 实现基线（概览）

> 本文是 UI 全局概览：先讲清产品形态、视觉基调、壳层和页面地图，再给共用模式、
> 共享组件与状态反馈规则。不再逐页记录字段级/交互级实现细节。

## 1. 文档目的

- 让新页面、新组件在开始写之前先对齐全局约定；
- 让维护者不用翻完每个页面就能知道「桌面和移动分别长什么样、共用什么」；
- 只描述**已实现**的现状，不写规划中的能力。

当本文与代码冲突时，以 `lib/theme.dart`、`lib/theme/*.dart`、
`lib/widgets/app_shell/`、`lib/features/**/presentation/` 为准。

## 2. 产品形态

SakuraMedia 是**桌面优先**的媒体管理工作台：

- 桌面端是完整实现：登录、工作台壳层、浏览、详情、搜索、活动中心、系统设置等；
- Web 端复用桌面端路由与页面实现，桌面窗口类系统能力降级；
- 移动端只接入主链路：底部导航（概览 / 影片 / 女优 / 榜单 / PornBox）、
  列表与详情、播放器、搜索、图搜、部分设置子页；其余设置子页仍可能是骨架或占位。

因此布局、导航、页面结构优先复用桌面壳层（`AppDesktopShell` / `AppSidebar` /
`AppTopBar`），不要默认移动端和 Web 端已有完整页面。

## 3. 视觉总基调

- 整体是浅色、克制、偏管理后台的工作台风格；
- 桌面端主背景浅灰、内容以白色卡面承载；移动端主背景统一纯白；
- 品牌强调色为棕红色系，用于主操作、选中态和少量重点信息；
- macOS 桌面端侧边栏使用原生 vibrancy 毛玻璃并叠加轻透明 tint，其它平台使用浅灰底色；
- 图片卡片和详情头图允许使用更强的遮罩与深色渐变。

颜色、间距、圆角、阴影、组件尺寸统一来自 `lib/theme.dart` 导出的 token，
业务页面不散落裸值。

## 4. 主题与 token

- 主主题入口：`lib/theme.dart`；
- 颜色基线：背景、卡片、边框、文字、强调色、状态色都在主题 token 中；
- Typography：统一字号、字重、行高与颜色 tone，通过 `resolveAppTextStyle` 使用；
- 间距 / 圆角 / 阴影：统一 `AppSpacing`、`AppRadius`、`AppShadow`；
- 结构尺寸：表单宽度、卡片宽度、图标尺寸、顶栏高度等有独立 token；
- 组件尺寸与交互基线：按钮、输入框、下拉、图标按钮等共享组件自带 token。
- 小图标命中区：订阅心形等图标视觉与布局保持 24（follow 卡 30），命中区经 `expand_tap_area` 外扩到 `subscriptionHeartHitSize`（44），不改变布局与对齐。

新增设计 token 后必须同步维护本文对应的「视觉总基调」描述，并检查主题测试。

## 5. 桌面端工作台结构

### 5.1 壳层

桌面端统一使用：

- `AppDesktopShell`：整体布局容器；
- `AppSidebar`：左侧导航；
- `AppTopBar`：顶栏；
- 内容区承载具体页面。

### 5.2 路由分层

- 主导航页面统一使用 `go`，子流程页面（详情、播放器、搜索子页、图搜等）统一使用 `push`；
- 返回规则：优先 `pop` 回真实历史栈；无历史时回到该路由的默认入口；
- 路由身份以 URL 为准，页面来源不再依赖 fallback 字符串。

## 6. 页面地图

### 6.1 桌面端

| 页面 | 路由 |
|---|---|
| 概览 | `/desktop/overview` |
| 发现 | `/desktop/library/discover`（含 `/movies`、`/moments`） |
| 女优上新 | `/desktop/library/follow` |
| 影片 | `/desktop/library/movies` |
| 女优 | `/desktop/library/actors` |
| 标签 | `/desktop/library/tags` |
| 时刻 | `/desktop/library/moments` |
| 播放列表 | `/desktop/library/playlists` |
| 切片 / 切片合集 | `/desktop/library/clips`、`/desktop/library/clip-collections` |
| 非 JAV 视频 / 视频合集 | `/desktop/library/videos`、`/desktop/library/video-collections` |
| 排行榜 | `/desktop/library/rankings` |
| 热评 | `/desktop/library/hot-reviews` |
| 搜索 | `/desktop/search` |
| 以图搜图 | `/desktop/search/image` |
| 活动中心 | `/desktop/system/activity` |
| 通知 | `/desktop/system/notifications` |
| 媒体管理 | `/desktop/system/media` |
| 资源导入 | `/desktop/system/media-import` |
| 订阅管理 | `/desktop/system/movie-subscriptions` |
| 系统诊断 | `/desktop/system/diagnostics` |
| 系统设置 | `/desktop/system/configuration` |

影片/女优详情、系列影片、播放器等属于子流程页面，路径挂在对应列表路由之下。

### 6.2 移动端

移动端当前真实页面包括：

- 底部导航：`/mobile/overview`、`/mobile/library/movies`、
  `/mobile/library/actors`、`/mobile/rankings`、`/mobile/pornbox`；
- 搜索与图搜：`/mobile/search`、`/mobile/search/image`；
- 媒体管理：`/mobile/system/media`；
- 设置子页：媒体库、下载器、索引器、播放列表、修改用户名、修改密码等
  `/mobile/settings/*` 页面；
- 影片/女优详情、播放器、播放列表详情、发现子页等子流程。

其余 `/mobile/settings/*` 与移动端扩展页面若未实现，仍保持骨架或占位，文档不写成已完整支持。

## 7. 页面共用模式

大多数列表页遵循同一套模式：

1. 顶部 `AppListHeader`：筛选入口、当前条件、总数/更新时间、操作槽；
2. 内容区为响应式卡片网格；
3. 滚动触底加载更多；
4. 加载失败保留旧内容并提供重试；
5. 下拉刷新（移动端）或页面刷新（桌面端）复用同一套状态层。

筛选交互：

- 桌面端筛选面板就地展开浮层；
- 移动端筛选面板使用底部抽屉；
- 两侧共用同一份筛选状态层和筛选组件；
- 影片筛选含状态（全部/已订阅/未订阅/可播放）、合集类型、番号来源、热度范围、发行年份、排序；
  其中热度范围为 0–2w 的双滑块（拖动中只更新面板显示，松手才应用），
  左端拖到 0 = 下限不限，右端拖到顶 = 无上界（2w 及以上都包含），对应接口 `heat_min` / `heat_max` 不传。

多选交互：

- 桌面端入口在顶栏「选择」，选中后顶栏原地改写；
- 移动端入口在卡片长按菜单，批量动作在贴底操作条。

详情页共用结构：

- 头部摘要（封面/标题/元信息）；
- 主体内容分节；
- 影片详情的「字幕」分节展示后端可用的 `.srt` 文件，点击后在桌面弹窗或移动端底部抽屉中查看原始文本；
- 检查面板或操作区按页面能力接入；
- 双端共用同一份内容层，只差布局容器。

## 8. 共享组件

优先使用以下共享组件，不在业务页面自绘基础控件：

- 动作：`AppButton`、`AppTextButton`、`AppIconButton`、`AppSwitch`（紧凑启停开关，尺寸走组件 token）；
- 表单：`AppTextField`、`AppPasswordField`、`AppSelectField`；
- 导航/结构：`AppTabBar`、`AppListHeader`、`AppContentCard`、`AppPageFrame`；
- 反馈：`AppEmptyState`、`AppBadge`、`AppSectionSkeleton`、`AppSectionError`、
  `AppFilterUpdateBar`、`AppPagedLoadMoreFooter`；
- 弹层：`AppDesktopDialog`、`AppBottomDrawer`、确认弹窗；
- 卡片：影片卡、女优卡、榜单卡、时刻卡、切片卡、合集卡等业务域共享卡片。

新增通用组件或设计 token 后，同步更新 `docs/widgets/` 与本文。

## 9. 状态与反馈规则

- 列表/详情加载优先骨架屏或占位块；
- 空态统一使用 `AppEmptyState`；
- 分页加载失败保留原列表并提供重试入口；
- 轻量操作反馈优先使用 toast；
- 删除、覆盖、离开未保存表单等破坏性操作先确认；
- 筛选更新不阻塞旧内容：失败时保留当前结果并展示失败条；
- 活动中心、下载任务等实时状态优先 SSE 事件流，不支持时降级轮询；
- 订阅管理「导入失败」档在卡片上直接展示失败原因（来自最新导入作业的 `failed_files`
  摘要），并提供「查看导入作业」入口跳资源导入中心；「删除下载记录」按钮复用下载
  中心的删除任务语义（可选删除文件），删除后本片重新参与自动下载；
- 下载任务卡片提供「文件列表」弹窗，按任务实时拉取 qB / 115 文件清单；`.iso` 等
  常见光盘镜像格式在列表中标红提示（仅视觉提示，不参与导入判定）；
- 配置保存后如后端返回需要重启的字段，明确提示「需重启容器才生效」。

## 10. 插件机制相关 UI 现状

- 桌面端「系统设置 > 插件」页提供插件管理：zip 上传安装（small 主按钮）、启停（紧凑 `AppSwitch`）、删除与插件私有 JSON 配置编辑；写操作后需重启容器才生效；
- 已启用插件注册的任务会出现在任务中心「可执行任务」面板，点击「查看任务」后在独立弹层中手动执行；
- 带参数的插件任务按后端返回的 `params_schema` 渲染参数表单，提交时将表单值作为
  JSON body 发送；服务端仍负责最终参数校验；
- 排行榜来源由插件注册：未安装/未启用排行榜插件时，排行榜页显示「暂无可用排行榜」；
- 高级设置页不再提供 JavDB 账号/密码与排行榜同步 cron，这些归插件私有配置和插件任务管理。

## 11. 开发规则

- 桌面端优先：布局、导航、页面结构优先复用桌面壳层；
- 设计系统优先：颜色、间距、圆角、阴影、尺寸统一来自 token；
- 最小可靠实现：不为未来不确定的需求做抽象和兜底；
- feature 内沿用 `data/`（DTO + API）与 `presentation/`（页面 + provider）分层；
- 修改 provider、路由定义后执行 `dart run build_runner build --delete-conflicting-outputs`；
- 修改主题 token、共享组件、路由、页面交互时同步补充或更新对应测试。

## 12. 不应写进本文的内容

- 后端接口实现细节与数据库结构；
- 尚未落地的规划或「未来蓝图」；
- 参考项目的目录结构、组件命名或交互模式；
- 逐页字段级表单说明（需要时以当前代码为准，不再在这里维护长文）。
