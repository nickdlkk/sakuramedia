---
outline: [2, 3, 4]
---

# 插件化机制

SakuraMedia 的插件机制让服务能力可以通过**插件目录**扩展，而不是把每个外部站点、
抓取任务或榜单来源都写进主程序。插件代码运行在宿主服务进程内，宿主在启动阶段加载
插件，插件通过固定的契约向宿主声明「我要注册什么任务、提供什么扩展」。

本文同时面向两类读者：

- **使用人员 / 部署者**：怎么安装、启用、配置插件，以及已提供的示例插件怎么用。
- **插件开发人员**：怎么写一个合法插件，能调用宿主哪些能力，有什么边界。

> 当前宿主插件接口版本为 `2`，兼容声明范围为 `1`～`2`。旧版插件可以继续加载，
> 但运行时按 v2 语义执行；新开发的插件应在 `manifest.json` 中声明 `2`。

## 插件是什么

一个插件就是**插件根目录下的一个子目录**：

```text
/data/plugins/
└── <plugin_id>/
    ├── manifest.json   # 插件声明：ID、名称、版本、宿主接口版本
    ├── __init__.py     # 必须暴露 register(context)
    └── ...             # 插件自己的代码
```

宿主默认从 `/data/plugins` 读取插件。只有同时满足以下条件，插件才会被加载：

1. 目录在插件根目录下，目录名与 `manifest.json` 的 `plugin_id` 一致；
2. 插件处于启用状态（安装时默认启用，也可在插件管理页开关）；
3. 重启了 api 与 aps 两个进程。

单个插件加载失败**不会拖垮整个服务**：错误会被记录下来，其余插件和宿主自带功能
照常运行。`plugins list` 可以查看每个插件的启停状态和加载错误。

插件目前能做两类事：

- **注册后台任务**：定时任务、手动任务、带参数任务，统一进入宿主任务中心；
- **声明业务扩展点**：让宿主把插件提供的数据收编进自己的业务接口，当前唯一的扩展点是
  `discovery.ranking_source`（排行榜来源）。

## 使用篇

### 安装与生命周期

插件通过**前端插件管理页**安装：进入「系统设置 → 插件」，点击「安装插件」上传 zip 包，
安装后默认自动启用。zip 包要求插件根内容直接打包（不含外层目录），根目录须包含
`manifest.json`；重新上传相同 `plugin_id` 的 zip 会替换代码并保留 `data/` 运行数据。
页面还支持启停、删除和在线编辑插件配置。

常用管理命令：

| 命令 | 作用 |
|---|---|
| `plugins list` | 列出已安装插件、启停状态、加载状态和加载错误 |
| `plugins install <目录或 zip>` | 安装插件；可用 `--sha256` 校验 zip，`--no-enable` 安装后不启用 |
| `plugins enable <plugin_id>` | 启用插件 |
| `plugins disable <plugin_id>` | 停用插件（目录保留） |
| `plugins remove <plugin_id>` | 删除插件目录（**包含 data/ 运行数据**） |
| `plugins check <目录>` | 校验插件目录是否合法，供插件作者使用 |
| `plugins clear-field-owners --plugin-id <plugin_id>` | 释放插件接管的影片字段；可用 `--field` 限定字段 |

前端插件管理页底层即登录鉴权后的 `/system/plugins` API，也可以直接调用：

| 方法 | 路径 | 说明 |
|---|---|---|
| `GET` | `/system/plugins` | 插件列表 |
| `GET` | `/system/plugins/{plugin_id}` | 插件详情 |
| `POST` | `/system/plugins` | multipart 上传 zip，字段 `file`、可选 `sha256`、`enable` |
| `PATCH` | `/system/plugins/{plugin_id}?enabled=true/false` | 启停 |
| `DELETE` | `/system/plugins/{plugin_id}` | 删除插件 |
| `GET` | `/system/plugins/{plugin_id}/settings` | 读取插件私有配置 |
| `PUT` | `/system/plugins/{plugin_id}/settings` | 整体替换插件私有配置（JSON） |

生命周期要点：

- **升级**：用相同 `plugin_id` 重新安装即可，旧插件目录里的 `data/` 会保留；
- **没有版本回滚**：升级前需要自己备份插件目录；
- **停用**：只是从 `plugins.enabled` 移除，目录和 `data/` 仍在；
- **删除**：会连插件代码和 `data/` 一起删除，删除前先备份；
- 如果插件曾接管 Movie 字段，删除后字段 owner 记录仍会保留；需要额外执行
  `plugins clear-field-owners`，字段才会回到宿主管理；
- 任何安装、升级、启停、删除或配置修改后，都要重启 **api 与 aps**。

### 插件配置

插件私有配置在「系统设置 → 插件」里点击插件行在线编辑，也可以通过
`/system/plugins/{plugin_id}/settings` 或直接编辑 `config.toml` 修改。前端按明文
JSON 对象整体替换配置，后端不接受 `null`；配置字段由插件自己定义，可能包含账号等
敏感信息。保存后需重启 api 与 aps（或容器）才生效。

### 前端能看到什么

- 插件注册的任务会出现在**任务中心**的「可执行任务」里，可以查看 cron、手动执行和运行记录；
- 排行榜插件提供的来源会出现在**排行榜页**，没有安装/启用排行榜插件时，排行榜页没有可用来源；
- 插件管理在**系统设置 → 插件**页：支持 zip 上传安装、启停、删除和 JSON 配置编辑，
  写操作后需重启 api 与 aps（或容器）才生效；
- 带参数的插件任务当前**不提供参数表单**，前端任务中心只能列出它；需要带参触发时请按插件说明使用
  后端 CLI 或接口。

### 排查插件问题

| 症状 | 处理方式 |
|---|---|
| 插件没生效 | `plugins list` 看 `enabled` 和 `load_status`；确认已写入 `enabled` 并重启 |
| 任务没出现在任务中心 | 插件可能未启用、`manifest.json` 缺失、`register` 报错或任务 key 冲突；`plugins list` 会显示加载错误 |
| 手动执行任务报 422 | 该任务声明了参数但前端没有参数表单，需按插件文档用 CLI/接口带参触发 |
| 排行榜页没有来源 | 没有安装/启用排行榜插件，或插件加载失败 |

## 示例插件：JavDB 排行榜

官方示例插件：[sakuramedia_javdb_ranking](https://github.com/tinypinglite/sakuramedia_javdb_ranking)。

它通过 `discovery.ranking_source` 扩展点注册了 `source_key="javdb"` 的排行榜来源，
并注册了定时全量同步和手动单榜同步两个任务。安装并启用后，排行榜页会出现 JavDB 来源。

### 安装

从插件仓库的 GitHub Release 下载 zip，在「系统设置 → 插件」页点击「安装插件」上传，
然后重启容器。

### 配置

在插件管理页点击本插件行，在线编辑：

```json
{
  "javdb_username": "",
  "javdb_password": ""
}
```

保存后需重启 api 与 aps 才生效。

账号说明：

- `javdb_username` / `javdb_password` 只对 **TOP250** 榜需要；
- 不配置账号时，TOP250 整榜跳过，其余五个免费榜照常同步；
- 配置账号后登录失败只影响当次运行，下次任务会自动重试。

### 提供的榜单

| board key | 周期 | 说明 |
|---|---|---|
| `playback_all` | daily / weekly / monthly | 热播榜 |
| `playback_high_score` | daily / weekly / monthly | 高评分榜 |
| `censored` | daily / weekly / monthly | 有码 |
| `uncensored` | daily / weekly / monthly | 无码 |
| `fc2` | daily / weekly / monthly | FC2 |
| `top250` | all / uncensored / censored / fc2 + 当前年份到 2008 | 需要账号；历史年份已有数据不重复抓取 |

### 提供的任务

| 任务 | 类型 | 说明 |
|---|---|---|
| `sakuramedia_javdb_ranking_sync` | 定时 | 全量同步本插件声明的全部榜单，默认每天 01:45 |
| `sakuramedia_javdb_ranking_sync_board` | 手动带参 | 手动同步单个榜单，参数 `board_key` / `period` |

## 开发篇

### 最小插件

一个最小插件只需要三个部分：

```text
<plugin_id>/
├── manifest.json
├── __init__.py          # 暴露 register(context)
└── plugin.py            # 实现 register
```

`manifest.json`：

```json
{
  "plugin_id": "example_plugin",
  "display_name": "示例插件",
  "version": "1.0.0",
  "host_api_version": 2,
  "requires_python": ">=3.10",
  "author": "example",
  "homepage": "https://example.com/example_plugin"
}
```

`plugin.py`：

```python
from src.plugins import PluginContext, PluginRegistration


def register(context: PluginContext) -> PluginRegistration:
    return PluginRegistration(
        plugin_id="example_plugin",
        display_name="示例插件",
        version="1.0.0",
    )
```

`register(context)` 只做**声明**，不要在这里发网络请求或做重型初始化，那些应该放进任务执行体。

### manifest.json 字段

| 字段 | 必填 | 说明 |
|---|---|---|
| `plugin_id` | 是 | 只能包含小写字母、数字、下划线，且必须以字母开头（`^[a-z][a-z0-9_]*$`），必须与目录名一致 |
| `display_name` | 是 | 展示名 |
| `version` | 是 | 插件版本，格式为 PEP 440 |
| `host_api_version` | 是 | 插件声明的宿主接口版本，必须在 `[1, 2]` 范围内；新插件使用 `2` |
| `requires_python` | 否 | Python 版本约束，如 `>=3.10` |
| `author` / `homepage` | 否 | 展示信息 |

未知字段会被严格拒绝，不要随意添加自定义字段。

### 注册契约：PluginRegistration

`register(context)` 必须返回 `PluginRegistration`：

| 字段 | 说明 |
|---|---|
| `plugin_id` | 与 manifest / 目录名一致 |
| `display_name` | 展示名 |
| `version` | 与 manifest 完全一致 |
| `host_api_version` | 必须在 `[1, 2]` 范围内；以 manifest 声明为准 |
| `jobs` | 后台任务元组，允许为空 |
| `extensions` | 扩展点声明元组，允许为空 |

### 任务声明：JobDefinition

插件任务从 `src.scheduler.contracts` 导入 `JobDefinition`：

```python
from pydantic import BaseModel
from src.scheduler.contracts import JobDefinition
```

常用字段：

| 字段 | 必填 | 说明 |
|---|---|---|
| `task_key` | 是 | 任务稳定标识，全局唯一 |
| `log_name` | 是 | 任务日志文件名，全局唯一 |
| `cli_name` | 是 | `aps` 子命令名，全局唯一 |
| `cli_help` | 是 | CLI 帮助与任务中心展示文案 |
| `default_cron` | 视形态 | 定时任务的默认 cron |
| `service_factory` | 视形态 | 定时执行体，接收 `TaskRunReporter` |
| `params_schema` | 否 | 手动参数模型（pydantic `BaseModel`） |
| `params_handler` | 否 | 带参执行体，接收 `TaskRunReporter` 和参数 dict |
| `manual_only` | 否 | `True` 表示无 cron、只能手动触发 |
| `manual_trigger_allowed` | 否 | 是否允许 HTTP 手动触发，默认 `True` |
| `business_recovery` | 否 | 崩溃恢复钩子 |
| `format_stats` | 否 | 把结果 dict 格式化为 CLI 统计文案 |

三种任务形态：

**定时任务**：

```python
JobDefinition(
    task_key="daily_sync",
    log_name="daily-sync",
    cli_name="sync-daily",
    cli_help="每日同步",
    default_cron="0 4 * * *",
    service_factory=lambda reporter: run_sync(reporter),
)
```

**手动带参任务**：

```python
class SyncParams(BaseModel):
    board_key: str
    period: str | None = None

JobDefinition(
    task_key="sync_one",
    log_name="sync-one",
    cli_name="sync-one",
    cli_help="手动同步单个榜单",
    manual_only=True,
    params_schema=SyncParams,
    params_handler=lambda reporter, params: run_one(reporter, params),
)
```

**混合任务**：同时声明 `default_cron + service_factory` 和
`params_schema + params_handler`，定时触发走 `service_factory`，手动带参触发走
`params_handler`。

任务校验规则（违反会让该插件加载失败并被隔离）：

- 必须提供 `service_factory` 或 `params_handler` 至少一个；
- 定时任务必须提供 `service_factory`；
- `manual_only` 任务不能声明 cron；
- `params_schema` 和 `params_handler` 必须成对出现；
- `default_cron` 必须是合法 crontab；
- `task_key` / `log_name` / `cli_name` 不能与宿主或其它插件重复。

### 宿主能力：PluginContext

插件通过 `PluginContext` 访问宿主能力。常用方法：

| 方法 | 说明 |
|---|---|
| `ensure_data_dir()` | 确保插件数据目录存在并返回路径 |
| `data_dir` | 插件专属数据目录 `<root>/<plugin_id>/data/`，重装保留 |
| `build_javdb_provider(username=None, password=None)` | 构造 JavDB provider；需要登录的榜单传入插件自己的账号 |
| `build_catalog_import_service()` | 构造目录入库服务 |
| `import_movie_by_number(movie_number)` | 通过 JavDB 获取详情并完整入库；已存在影片跳过不更新，返回 `MovieSnapshot` |
| `movies` | 影片只读快照与受保护字段 patch 出口，见下文 |
| `list_existing_movie_numbers()` | 主库全部影片番号集合，用于批量任务做存在性判断 |
| `import_subtitle(movie_number, content, filename, language=None)` | 写入字幕，宿主统一做扩展名校验、去重、落盘和登记 |
| `sync_ranking_sources(progress_callback=None)` | 同步本插件声明的全部排行榜来源 |
| `sync_ranking_board(source_key, board_key, period=None)` | 同步单个榜单；`source_key` 必须是本插件声明的 |
| `get_task_logger(name)` | 获取绑定到任务日志文件的 logger |

插件能读到的配置只有 `context.settings`（对应 `plugins.settings.<plugin_id>`），
它是**深冻结只读**的，插件不能修改。部署者可以通过插件管理页、插件 settings API
或 `config.toml` 修改，修改后重启 api 与 aps。

批量导入时不要为每个番号反复构造 provider/importer，应该在一个任务运行内复用：

```python
plugin_settings = context.settings
provider = context.build_javdb_provider(
    username=plugin_settings.get("javdb_username"),
    password=plugin_settings.get("javdb_password"),
)
importer = context.build_catalog_import_service()
```

### 影片快照与字段主权（v2）

影片读取和导入都返回 `MovieSnapshot`，插件不会拿到可写的 ORM 对象。快照包含
`movie_id`、`revision`、公开字段 `values` 和字段接管映射 `owners`；`values` 当前包含
番号、标题、简介、发布时间、时长、评分、评分人数、观看数、想看数、评论数、厂商、导演、
系列、合集标记和订阅标记。

```python
from src.plugins import MovieSnapshot

snapshot: MovieSnapshot | None = context.movies.get(movie_id)
snapshots = context.movies.find_by_numbers(["ABP-123", "IPX-456"])

if snapshot is not None:
    updated = context.movies.patch(
        snapshot.movie_id,
        {"summary": "插件补充的简介"},
        expected_revision=snapshot.revision,
    )
```

规则如下：

- `get()` 按影片内部 id 读取，`find_by_numbers()` 按番号读取；找不到的番号会跳过；
- `import_movie_by_number()` 保持纯新建语义，已有影片不会被覆盖；更新已有影片必须先读取快照，再调用 `movies.patch()`；
- `patch()` 只允许写宿主白名单字段，当前是 `title`、`summary`、`maker_name`、`director_name`，且值必须是字符串；
- `expected_revision` 过期，或字段已被其他插件接管时，整次写入返回 `False`，不会部分修改；
- 插件成功写入后会接管对应字段，宿主后续刷新不会覆盖这些字段；插件删除后 owner 不会自动清理，需执行 `plugins clear-field-owners --plugin-id <plugin_id>`。

### 扩展点机制

插件通过 `extensions` 声明业务领域扩展：

```python
from src.plugins import PluginExtension

PluginExtension(
    key="discovery.ranking_source",
    data=PluginRankingSource(...),
)
```

宿主只做通用结构校验，领域语义由对应扩展点的校验器解释。当前唯一已登记的扩展点是
`discovery.ranking_source`；插件声明宿主未登记的扩展点 key 会被拒绝。

### 排行榜扩展点

```python
from src.plugins import (
    PluginExtension,
    PluginRankingBoard,
    PluginRankingSource,
    PluginRegistration,
    RANKING_SOURCE_EXTENSION_KEY,
)


def fetch_hot(period: str) -> list[str]:
    # 插件自己抓取外部站点，返回番号列表，顺序即 rank
    return ["ABP-123", "IPX-456"]


def register(context):
    return PluginRegistration(
        plugin_id="example_rank",
        display_name="示例榜单",
        version="1.0.0",
        extensions=(
            PluginExtension(
                key=RANKING_SOURCE_EXTENSION_KEY,
                data=PluginRankingSource(
                    source_key="example",
                    name="示例站",
                    boards=(
                        PluginRankingBoard(
                            key="hot",
                            name="热榜",
                            supported_periods=("daily", "weekly", "monthly"),
                            default_period="daily",
                            fetch_numbers=fetch_hot,
                        ),
                    ),
                ),
            ),
        ),
    )
```

关键语义：

- `source_key` 全局唯一，两个插件声明相同 `source_key` 时后加载的插件整插件隔离；
- `board.key` 在来源内唯一；
- `supported_periods` 和 `supported_periods_provider` 二选一，后者用于动态周期（如逐年滚动的年份）；
- `should_fetch(period, has_items)` 返回 `False` 时该周期跳过，可用于「未配置账号不抓」「历史年份已有数据不重抓」；
- `fetch_numbers(period)` 返回番号列表，列表顺序就是榜单排名。

需要登录的账号由插件自己从 `plugins.settings.<plugin_id>` 读取，宿主不感知账号配置。

### 任务进度与日志

任务执行体接收 `TaskRunReporter`：

```python
def handler(reporter, params):
    reporter.emit(
        current=1,
        total=10,
        text="processing ...",
        summary_patch={"processed": 1},
    )
    return {"done": True}
```

- 进度会写入任务运行记录，前端任务中心通过任务运行接口和 SSE 看到；
- 任务完成/失败会走通知中心；
- 每个任务按 `log_name` 写独立日志文件；
- 同一个 `task_key` 同时只运行一个实例：定时触发重复时会丢弃，手动触发遇到运行中实例返回 409。

### 安全与边界

- **插件是可信代码**：与宿主同进程运行，拥有相同的数据/网络/文件权限，只应安装可信来源的插件；
- **zip 有介质防护，没有代码沙箱**：安装时限制 zip 大小（100MB）、解压体积（500MB）、文件数（5000），
  拒绝绝对路径、`..` 越界路径和符号链接，可选 sha256 校验；
- 插件**不能**注册 HTTP 路由/API、事件钩子、中间件或 Webhook；
- 插件**不能**直接访问宿主数据库；需要持久化时使用自己的 `data/`（如 SQLite、JSON）；
- 插件**不能**安装第三方依赖，只能使用宿主环境已装的包和标准库；
- 插件**不能**注册前端页面或 UI 组件。

### 开发、校验与发布

本地开发可以在 `config.toml` 里把 `root_dir` 指到本地目录：

```toml
[plugins]
root_dir = "./storage/plugins"
enabled = ["example_plugin"]

[plugins.job_crons.example_plugin]
daily_sync = "0 4 * * *"

[plugins.settings.example_plugin]
api_token = "..."
```

`plugins.job_crons.<plugin_id>.<task_key>` 可以覆盖任务默认 cron；插件私有配置通过
`context.settings` 只读读取。整个 `[plugins]` 节不由通用 `/config` API 暴露，插件安装、
启停和私有配置请使用插件管理 API、CLI 或配置文件，修改后重启 api 与 aps。

部署前校验插件目录：

```bash
python -m src.start.commands plugins check ./example_plugin
```

`plugins check` 会真实执行 import、`register` 和契约校验。zip 打包时：

```bash
cd example_plugin
zip -r ../example_plugin-1.0.0.zip . \
  -x '.git/*' -x 'tests/*' -x '__pycache__/*' -x '.venv/*' -x 'data/*'
```

zip 根必须是 `manifest.json` 和 `__init__.py`，不要包一层外层目录。

发布到 GitHub 时，示例插件仓库的 release workflow 会自动生成安装 zip：

1. 更新 `manifest.json` 和插件代码里的版本号并提交；
2. 打 `v<version>` 标签并推送；
3. 基于该标签创建正式 Release，workflow 会生成并附加 `sakuramedia_javdb_ranking-<version>.zip`。

插件版本和 `host_api_version` 是宿主兼容性信号：当前支持 `[1, 2]`，不满足范围时插件会被
拒绝加载。虽然 v1 manifest 仍可加载，但运行期 `import_movie_by_number()` 已返回
`MovieSnapshot`；依赖旧版可写返回值的插件必须升级。开发插件时只依赖本文描述的公开契约，
不要绑定宿主内部实现。
