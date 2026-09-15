import 'package:flutter/widgets.dart';
import 'package:ledger_app/features/accounting/common.dart';
import 'package:ledger_app/features/accounting/pages.dart';

/// Session-scoped financial overview and the primary manual entry action.
class HomePage extends StatelessWidget {
  /// Creates the home entrypoint.
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const AccountingGate(child: AccountingHomePage());
}
