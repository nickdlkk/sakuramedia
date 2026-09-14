import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_branch_cache.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

void main() {
  testWidgets(
    'lazy LRU retains eight pages and refresh targets only visible page',
    (tester) async {
      final mounts = <int, int>{};
      final disposed = <int>[];
      final refreshed = <int>[];
      final callbacks = <AppPageRefreshCallback>[];
      final registrar = AppPageRefreshRegistrar(
        register: callbacks.add,
        unregister: callbacks.remove,
      );
      Future<void> visit(int index) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppPageRefreshRegistrarScope(
            registrar: registrar,
            child: DesktopBranchCache(
              currentIndex: index,
              children: List.generate(
                9,
                (i) => _Probe(
                  index: i,
                  mounts: mounts,
                  disposed: disposed,
                  refreshed: refreshed,
                ),
              ),
            ),
          ),
        ),
      );
      await visit(0);
      expect(mounts, {0: 1});
      for (var i = 1; i < 8; i++) {
        await visit(i);
      }
      expect(disposed, isEmpty);
      await visit(0); // Touch oldest so page 1 becomes the eviction candidate.
      await visit(8);
      expect(disposed, [1]);
      expect(callbacks, hasLength(1));
      await callbacks.single();
      expect(refreshed, [8]);
      await visit(0);
      expect(mounts[0], 1);
      await visit(1);
      expect(mounts[1], 2);
      expect(callbacks, hasLength(1));
      await callbacks.single();
      expect(refreshed, [8, 1]);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Probe extends StatefulWidget {
  const _Probe({
    required this.index,
    required this.mounts,
    required this.disposed,
    required this.refreshed,
  });
  final int index;
  final Map<int, int> mounts;
  final List<int> disposed;
  final List<int> refreshed;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.mounts.update(widget.index, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.disposed.add(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageRefreshScope(
    onRefresh: () async {
      widget.refreshed.add(widget.index);
    },
    child: const SizedBox.expand(),
  );
}
