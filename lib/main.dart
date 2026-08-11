import 'package:flutter/widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/core/session/saved_accounts_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';

export 'package:sakuramedia/app/app.dart';

Future<void> main() async {
  await bootstrapApplication();
  final sessionStore = await SessionStore.create();
  final savedAccountsStore = await SavedAccountsStore.create();
  runApp(MyApp(
    sessionStore: sessionStore,
    savedAccountsStore: savedAccountsStore,
  ));
}
