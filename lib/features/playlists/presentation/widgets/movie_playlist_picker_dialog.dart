import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

enum MoviePlaylistPickerPresentation { dialog, bottomDrawer }

Future<void> showMoviePlaylistPickerDialog(
  BuildContext context, {
  required String movieNumber,
  required List<MoviePlaylistSummaryDto> initialPlaylists,
  MoviePlaylistPickerPresentation presentation =
      MoviePlaylistPickerPresentation.dialog,
}) {
  switch (presentation) {
    case MoviePlaylistPickerPresentation.dialog:
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => MoviePlaylistPickerDialog(
          movieNumber: movieNumber,
          initialPlaylists: initialPlaylists,
          presentation: MoviePlaylistPickerPresentation.dialog,
        ),
      );
    case MoviePlaylistPickerPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('movie-playlist-picker-bottom-sheet'),
        heightFactor: 0.7,
        builder: (sheetContext) => MoviePlaylistPickerDialog(
          movieNumber: movieNumber,
          initialPlaylists: initialPlaylists,
          presentation: MoviePlaylistPickerPresentation.bottomDrawer,
        ),
      );
  }
}

class MoviePlaylistPickerDialog extends ConsumerStatefulWidget {
  const MoviePlaylistPickerDialog({
    super.key,
    required this.movieNumber,
    required this.initialPlaylists,
    this.presentation = MoviePlaylistPickerPresentation.dialog,
  });

  final String movieNumber;
  final List<MoviePlaylistSummaryDto> initialPlaylists;
  final MoviePlaylistPickerPresentation presentation;

  @override
  ConsumerState<MoviePlaylistPickerDialog> createState() =>
      _MoviePlaylistPickerDialogState();
}

class _MoviePlaylistPickerDialogState
    extends ConsumerState<MoviePlaylistPickerDialog> {
  final ScrollController _scrollController = ScrollController();

  List<PlaylistDto> _playlists = const <PlaylistDto>[];
  late Set<int> _selectedPlaylistIds;
  final Set<int> _updatingPlaylistIds = <int>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPlaylistIds = widget.initialPlaylists
        .map((playlist) => playlist.id)
        .toSet();
    _load();
  }

  Future<void> _load() async {
    try {
      final playlists = await ref.read(playlistsApiProvider).getPlaylists();
      if (!mounted) {
        return;
      }
      setState(() {
        _playlists = playlists
            .where((playlist) => !playlist.isSystem)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '播放列表加载失败';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final isBottomDrawer =
        widget.presentation == MoviePlaylistPickerPresentation.bottomDrawer;
    final playlistList = Scrollbar(
      controller: _scrollController,
      thumbVisibility: !isBottomDrawer,
      child: ListView.builder(
        key: const Key('movie-playlist-list'),
        controller: _scrollController,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          final selected = _selectedPlaylistIds.contains(playlist.id);
          final updating = _updatingPlaylistIds.contains(playlist.id);
          return Material(
            color: context.appColors.surfaceCard,
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              key: Key('movie-playlist-option-${playlist.id}'),
              hoverColor: context.appColors.surfaceMuted.withValues(
                alpha: 0.45,
              ),
              highlightColor: context.appColors.surfaceMuted.withValues(
                alpha: 0.6,
              ),
              splashFactory: NoSplash.splashFactory,
              onTap: updating ? null : () => _togglePlaylist(playlist),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Text(
                      '${playlist.movieCount} 部',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    if (updating)
                      SizedBox.square(
                        dimension:
                            kMinInteractiveDimension +
                            Theme.of(
                              context,
                            ).visualDensity.baseSizeAdjustment.dy,
                        child: Center(
                          child: SizedBox.square(
                            dimension: tokens.iconSizeXs,
                            child: CircularProgressIndicator.adaptive(
                              key: Key(
                                'movie-playlist-updating-${playlist.id}',
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Checkbox(
                        key: Key('movie-playlist-checkbox-${playlist.id}'),
                        value: selected,
                        onChanged: (_) => _togglePlaylist(playlist),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final Widget body;
    if (_isLoading) {
      body = const Center(
        key: Key('movie-playlist-loading'),
        child: CircularProgressIndicator.adaptive(),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.muted,
          ),
        ),
      );
    } else if (_playlists.isEmpty) {
      body = Center(
        child: Text(
          '暂无播放列表',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.muted,
          ),
        ),
      );
    } else {
      body = playlistList;
    }
    final content = Column(
      mainAxisSize: isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '加入播放列表',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.medium,
                ),
              ),
            ),
            AppIconButton(
              key: const Key('movie-playlist-close-button'),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        if (isBottomDrawer)
          Expanded(child: body)
        else
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: _isLoading || _errorMessage != null || _playlists.isEmpty
                  ? SizedBox(height: 160, child: body)
                  : body,
            ),
          ),
        Divider(color: context.appColors.divider, height: spacing.lg),
        AppTextButton(
          key: const Key('movie-playlist-create-button'),
          label: '新建播放列表',
          icon: const Icon(Icons.add_rounded),
          onPressed: _createPlaylist,
        ),
      ],
    );
    if (!isBottomDrawer) {
      return AppDesktopDialog(
        dialogKey: const Key('movie-playlist-picker-dialog'),
        width: tokens.playlistDialogWidth,
        showCloseButton: false,
        child: content,
      );
    }
    return content;
  }

  Future<void> _togglePlaylist(PlaylistDto playlist) async {
    final isSelected = _selectedPlaylistIds.contains(playlist.id);
    setState(() {
      _updatingPlaylistIds.add(playlist.id);
      if (isSelected) {
        _selectedPlaylistIds.remove(playlist.id);
      } else {
        _selectedPlaylistIds.add(playlist.id);
      }
    });

    try {
      if (isSelected) {
        await ref
            .read(playlistsApiProvider)
            .removeMovieFromPlaylist(
              playlistId: playlist.id,
              movieNumber: widget.movieNumber,
            );
      } else {
        await ref
            .read(playlistsApiProvider)
            .addMovieToPlaylist(
              playlistId: playlist.id,
              movieNumber: widget.movieNumber,
            );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isSelected) {
          _selectedPlaylistIds.add(playlist.id);
        } else {
          _selectedPlaylistIds.remove(playlist.id);
        }
      });
      showToast(
        apiErrorMessage(error, fallback: isSelected ? '移出播放列表失败' : '加入播放列表失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlaylistIds.remove(playlist.id);
        });
      }
    }
  }

  Future<void> _createPlaylist() async {
    final playlist = await showCreatePlaylistDialog(
      context,
      presentation:
          widget.presentation == MoviePlaylistPickerPresentation.bottomDrawer
          ? CreatePlaylistDialogPresentation.bottomDrawer
          : CreatePlaylistDialogPresentation.dialog,
    );
    if (!mounted || playlist == null) {
      return;
    }
    setState(() {
      _playlists = <PlaylistDto>[playlist, ..._playlists];
    });
    await _togglePlaylist(playlist);
  }
}
