import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/import_job_card.dart';
import 'package:sakuramedia/features/media_import/presentation/import_jobs_view_controller.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_provider.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/subtitle_import_provider.dart';
import 'package:sakuramedia/features/media_import/presentation/subtitle_import_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_import_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/imports/video_import_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

class DesktopMediaImportPage extends ConsumerStatefulWidget {
  const DesktopMediaImportPage({super.key});

  @override
  ConsumerState<DesktopMediaImportPage> createState() =>
      _DesktopMediaImportPageState();
}

enum _ImportTab { javMovie, pornBoxMovie, javSubtitle }

class _DesktopMediaImportPageState extends ConsumerState<DesktopMediaImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final ScrollController _scrollController = ScrollController();
  final Map<_ImportTab, Set<int>> _expandedByTab = <_ImportTab, Set<int>>{
    for (final tab in _ImportTab.values) tab: <int>{},
  };
  // 「重新导入」会新建作业；提交期间锁住对应按钮，避免重复创建任务。
  final Map<_ImportTab, Set<int>> _reimportingByTab = <_ImportTab, Set<int>>{
    for (final tab in _ImportTab.values) tab: <int>{},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _ImportTab.values.length,
      vsync: this,
    )..addListener(_handleTabChanged);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  _ImportTab get _activeTab => _ImportTab.values[_tabController.index];

  ImportJobsViewController get _activeController => switch (_activeTab) {
    _ImportTab.javMovie => ref.read(mediaImportProvider.notifier),
    _ImportTab.pornBoxMovie => ref.read(videoImportProvider.notifier),
    _ImportTab.javSubtitle => ref.read(subtitleImportProvider.notifier),
  };

  ImportJobsViewData? get _activeData => switch (_activeTab) {
    _ImportTab.javMovie => ref.read(mediaImportProvider).value,
    _ImportTab.pornBoxMovie => ref.read(videoImportProvider).value,
    _ImportTab.javSubtitle => ref.read(subtitleImportProvider).value,
  };

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    // 切标签时回到顶部，避免新标签内容沿用上一个标签的滚动位置。
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {});
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    // loadMore 失败时不再自动重试，避免用户上下滑动就把失败请求反复打出去；
    // 由 footer 的「重试」按钮承担唯一重试入口。对齐 PagedLoadController 的约定。
    if (_activeData?.loadMoreError != null) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_activeController.loadMore());
    }
  }

  Future<void> _openJavCreateDialog() async {
    final request = await showDirectoryPickerDialog(context);
    if (request == null || !mounted) {
      return;
    }
    final error = await ref
        .read(mediaImportProvider.notifier)
        .triggerImport(
          libraryId: request.libraryId,
          source: request.source,
          transferMode: request.transferMode,
        );
    if (!mounted) {
      return;
    }
    showToast(error ?? '导入任务已提交，可在下方查看进度');
  }

  Future<void> _openPornCreateDialog() async {
    final request = await showVideoImportDialog(context);
    if (request == null || !mounted) {
      return;
    }
    final error = await ref
        .read(videoImportProvider.notifier)
        .triggerImport(
          libraryId: request.libraryId,
          source: request.source,
          transferMode: request.transferMode,
          collectionId: request.collectionId,
        );
    if (!mounted) {
      return;
    }
    showToast(error ?? '导入任务已提交，可在下方查看进度');
  }

  Future<void> _openSubtitleCreateDialog() async {
    final sourcePath = await showSubtitleImportDialog(context);
    if (sourcePath == null || !mounted) {
      return;
    }
    final error = await ref
        .read(subtitleImportProvider.notifier)
        .triggerImport(sourcePath: sourcePath);
    if (!mounted) {
      return;
    }
    showToast(error ?? '字幕导入任务已提交，可在下方查看进度');
  }

  void _createImport(_ImportTab tab) {
    switch (tab) {
      case _ImportTab.javMovie:
        unawaited(_openJavCreateDialog());
        return;
      case _ImportTab.pornBoxMovie:
        unawaited(_openPornCreateDialog());
        return;
      case _ImportTab.javSubtitle:
        unawaited(_openSubtitleCreateDialog());
        return;
    }
  }

  String _tabTitle(_ImportTab tab) => switch (tab) {
    _ImportTab.javMovie => 'JAV 影片导入',
    _ImportTab.pornBoxMovie => 'PornBox 影片导入',
    _ImportTab.javSubtitle => 'JAV 字幕导入',
  };

  String _createLabel(_ImportTab tab) => switch (tab) {
    _ImportTab.javSubtitle => '新建字幕导入',
    _ => '新建导入',
  };

  String _tabDescription(_ImportTab tab) => switch (tab) {
    _ImportTab.javMovie =>
      '从后端本地目录或 115 网盘目录中选择 JAV 媒体导入到对应媒体库。导入在后台运行，可在此查看实时进度与失败文件处理。',
    _ImportTab.pornBoxMovie =>
      '从后端白名单目录中选择 PornBox 视频导入到媒体库，必须归入一个合集。导入在后台运行，可在此查看实时进度与失败文件处理。',
    _ImportTab.javSubtitle =>
      '从后端白名单目录选择字幕文件夹。系统仅扫描 .srt，并按文件名中的番号匹配已入库的 JAV 影片；源文件会保留。',
  };

  String _emptyMessage(_ImportTab tab) => switch (tab) {
    _ImportTab.javSubtitle => '还没有字幕导入作业。点击「新建字幕导入」选择一个字幕目录。',
    _ => '还没有导入作业。点击「新建导入」从后端目录选择媒体导入。',
  };

  void _toggleExpanded(ImportJobsViewController controller, int jobId) {
    final expanded = _expandedByTab[_activeTab]!;
    setState(() {
      if (expanded.contains(jobId)) {
        expanded.remove(jobId);
      } else {
        expanded.add(jobId);
        unawaited(controller.ensureDetail(jobId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 三个 provider 与页面同生命周期；只 watch 激活标签的完整状态，其他标签仅
    // 保持订阅，因此切换标签后实时流和分页快照仍保留，也不会引发当前页面重建。
    ref.watch(mediaImportProvider.select((_) => null));
    ref.watch(videoImportProvider.select((_) => null));
    ref.watch(subtitleImportProvider.select((_) => null));
    final ImportJobsViewData activeData;
    final ImportJobsViewController activeController;
    switch (_activeTab) {
      case _ImportTab.javMovie:
        activeData =
            ref.watch(mediaImportProvider).value ??
            MediaImportState(isInitialLoading: true);
        activeController = ref.read(mediaImportProvider.notifier);
      case _ImportTab.pornBoxMovie:
        activeData =
            ref.watch(videoImportProvider).value ??
            VideoImportState(isInitialLoading: true);
        activeController = ref.read(videoImportProvider.notifier);
      case _ImportTab.javSubtitle:
        activeData =
            ref.watch(subtitleImportProvider).value ??
            SubtitleImportState(isInitialLoading: true);
        activeController = ref.read(subtitleImportProvider.notifier);
    }

    // 顶栏刷新按钮 / Cmd+R 刷新当前 tab 的导入历史；跨 tab 时也只刷激活的那个，
    // 避免误触发另一 tab 的 SSE 重放。
    return AppPageRefreshScope(
      onRefresh: () => activeController.refresh(),
      child: CustomScrollView(
        key: const Key('media-import-page'),
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: AppTabBar(
              controller: _tabController,
              tabs: const [
                Tab(key: Key('media-import-tab-jav'), text: 'JAV 影片'),
                Tab(key: Key('media-import-tab-pornbox'), text: 'PornBox 影片'),
                Tab(key: Key('media-import-tab-jav-subtitle'), text: 'JAV 字幕'),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
          ..._buildTabSlivers(
            context,
            data: activeData,
            controller: activeController,
            tab: _activeTab,
            expanded: _expandedByTab[_activeTab]!,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTabSlivers(
    BuildContext context, {
    required ImportJobsViewData data,
    required ImportJobsViewController controller,
    required _ImportTab tab,
    required Set<int> expanded,
  }) {
    final hasHistory =
        !data.isInitialLoading &&
        data.initialError == null &&
        data.jobs.isNotEmpty;
    return [
      SliverToBoxAdapter(
        child: _Header(
          title: _tabTitle(tab),
          description: _tabDescription(tab),
          createLabel: _createLabel(tab),
          isLoading: data.isInitialLoading,
          onCreate: () => _createImport(tab),
          onRefresh: () => unawaited(controller.refresh()),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
      if (hasHistory) ...[
        const SliverToBoxAdapter(child: _HistorySectionTitle()),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.md)),
      ],
      _buildBodySliver(context, data, controller, tab, expanded),
      if (data.jobs.isNotEmpty &&
          (data.isLoadingMore || data.loadMoreError != null))
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: context.appSpacing.lg),
            child: AppPagedLoadMoreFooter(
              isLoading: data.isLoadingMore,
              errorMessage: data.loadMoreError,
              onRetry: () => unawaited(controller.loadMore()),
            ),
          ),
        ),
    ];
  }

  Widget _buildBodySliver(
    BuildContext context,
    ImportJobsViewData data,
    ImportJobsViewController controller,
    _ImportTab tab,
    Set<int> expanded,
  ) {
    if (data.isInitialLoading) {
      return SliverToBoxAdapter(
        child: AppContentCard(
          title: '正在加载',
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.appLayoutTokens.emptySectionVerticalPadding,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth:
                    context.appComponentTokens.movieCardLoaderStrokeWidth,
              ),
            ),
          ),
        ),
      );
    }

    if (data.initialError != null) {
      return SliverToBoxAdapter(
        child: AppContentCard(
          title: '加载失败',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppEmptyState(message: data.initialError!),
              SizedBox(height: context.appSpacing.lg),
              Center(
                child: AppButton(
                  key: const Key('media-import-initial-retry-button'),
                  label: '重试',
                  variant: AppButtonVariant.primary,
                  onPressed: () => unawaited(controller.loadFirstPage()),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (data.jobs.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: _emptyMessage(tab)),
      );
    }

    final reimporting = _reimportingByTab[tab]!;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final job = data.jobs[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: ImportJobCard(
            job: job,
            taskRun: data.taskRunFor(job.taskRunId),
            expanded: expanded.contains(job.id),
            detail: data.detailFor(job.id),
            isDetailLoading: data.isDetailLoading(job.id),
            detailError: data.detailError(job.id),
            onToggle: () => _toggleExpanded(controller, job.id),
            onRetryAll: () => _retryAll(controller, job.id),
            onRetryFile: (path) =>
                _retryFiles(controller, job.id, <String>[path]),
            onDeleteFile: job.canMutateFailedSource
                ? (path) => _deleteFile(tab, job.id, path)
                : null,
            onRenameFile: job.canMutateFailedSource
                ? (path, name) => _renameFile(tab, job.id, path, name)
                : null,
            onReimport: job.canReimport
                ? () => _reimport(tab, controller, job.id)
                : null,
            isReimporting: reimporting.contains(job.id),
            onReloadDetail: () =>
                unawaited(controller.ensureDetail(job.id, force: true)),
          ),
        );
      }, childCount: data.jobs.length),
    );
  }

  Future<void> _retryAll(ImportJobsViewController controller, int jobId) async {
    final error = await controller.retryFailedFiles(jobId);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  Future<void> _retryFiles(
    ImportJobsViewController controller,
    int jobId,
    List<String> files,
  ) async {
    final error = await controller.retryFailedFiles(jobId, files: files);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  /// 任务级失败作业的整体重跑：按原参数新建一个导入作业。
  Future<void> _reimport(
    _ImportTab tab,
    ImportJobsViewController controller,
    int jobId,
  ) async {
    final reimporting = _reimportingByTab[tab]!;
    if (reimporting.contains(jobId)) {
      return;
    }
    setState(() => reimporting.add(jobId));
    final error = await controller.reimportJob(jobId);
    if (!mounted) {
      return;
    }
    setState(() => reimporting.remove(jobId));
    showToast(error ?? '已按原参数提交重新导入');
  }

  Future<void> _deleteFile(_ImportTab tab, int jobId, String path) async {
    final confirmed = await _confirmDelete(path);
    if (!mounted || !confirmed) {
      return;
    }
    final error = switch (tab) {
      _ImportTab.javMovie =>
        await ref
            .read(mediaImportProvider.notifier)
            .deleteFailedFile(jobId, path: path),
      _ImportTab.javSubtitle =>
        await ref
            .read(subtitleImportProvider.notifier)
            .deleteFailedFile(jobId, path: path),
      _ImportTab.pornBoxMovie => '该导入类型不支持删除失败源文件。',
    };
    if (!mounted) {
      return;
    }
    showToast(error ?? '源文件已删除');
  }

  Future<void> _renameFile(
    _ImportTab tab,
    int jobId,
    String path,
    String currentName,
  ) async {
    final newName = await _promptRename(
      currentName,
      hintText: tab == _ImportTab.javSubtitle
          ? '例如 ABP-123.cht.srt'
          : '例如 ABP-123.mp4',
    );
    if (!mounted || newName == null || newName.trim().isEmpty) {
      return;
    }
    final error = switch (tab) {
      _ImportTab.javMovie =>
        await ref
            .read(mediaImportProvider.notifier)
            .renameFailedFile(jobId, path: path, newName: newName.trim()),
      _ImportTab.javSubtitle =>
        await ref
            .read(subtitleImportProvider.notifier)
            .renameFailedFile(jobId, path: path, newName: newName.trim()),
      _ImportTab.pornBoxMovie => '该导入类型不支持重命名失败源文件。',
    };
    if (!mounted) {
      return;
    }
    showToast(error ?? '已重命名');
  }

  Future<bool> _confirmDelete(String path) {
    return showAppConfirmDialog(
      context,
      title: '删除源文件',
      message: '确认删除该失败源文件？该操作不可恢复。\n\n$path',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('media-import-delete-confirm-dialog'),
    );
  }

  Future<String?> _promptRename(
    String currentName, {
    required String hintText,
  }) {
    final textController = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('media-import-rename-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '重命名源文件',
              style: resolveAppTextStyle(dialogContext, size: AppTextSize.s18),
            ),
            SizedBox(height: dialogContext.appSpacing.lg),
            AppTextField(
              fieldKey: const Key('media-import-rename-field'),
              controller: textController,
              label: '新文件名',
              hintText: hintText,
            ),
            SizedBox(height: dialogContext.appSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                SizedBox(width: dialogContext.appSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '确认',
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(textController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(textController.dispose);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.description,
    required this.createLabel,
    required this.isLoading,
    required this.onCreate,
    required this.onRefresh,
  });

  final String title;
  final String description;
  final String createLabel;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: title,
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              description,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          AppButton(
            key: const Key('media-import-refresh-button'),
            label: '刷新',
            onPressed: onRefresh,
          ),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-create-button'),
            label: createLabel,
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            onPressed: isLoading ? null : onCreate,
          ),
        ],
      ),
    );
  }
}

class _HistorySectionTitle extends StatelessWidget {
  const _HistorySectionTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入任务历史',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            '按创建时间倒序展示历史导入任务的状态与处理结果。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}
