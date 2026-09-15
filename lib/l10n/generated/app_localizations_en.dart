// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ledger';

  @override
  String get homeTab => 'Home';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get homeEmptyTitle => 'Start your ledger here';

  @override
  String get homeEmptyBody => 'No ledgers yet';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get pageNotFoundBody => 'This page is not available.';

  @override
  String get backToHome => 'Back to home';

  @override
  String get endpointLabel => 'API Endpoint';

  @override
  String get serverTitle => 'Server';

  @override
  String get endpointUnavailable => 'Not configured';

  @override
  String get configurationNeeded =>
      'Client configuration is missing or invalid. Check the deployment configuration.';

  @override
  String get loadingLabel => 'Loading…';

  @override
  String get retryAction => 'Retry';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get createSpace => 'Create your personal space';

  @override
  String get currencyLabel => 'Base currency';

  @override
  String get timezoneLabel => 'Time zone';

  @override
  String get currencyWarning =>
      'The base currency cannot be changed after creation. Review these settings before continuing.';

  @override
  String get defaultsWarning =>
      'Some device settings could not be detected. Review the suggested USD currency and/or UTC time zone.';

  @override
  String get createAction => 'Create personal space';

  @override
  String get requiredValue => 'Enter a valid value.';

  @override
  String get currencyValidation =>
      'Use a three-letter uppercase ISO currency code.';

  @override
  String get booksTitle => 'Books';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get bookDetailsTitle => 'Book details';

  @override
  String get personalSpaceLabel => 'Personal space';

  @override
  String get identityLabel => 'User';

  @override
  String get defaultBookLabel => 'Default book';

  @override
  String get saveAction => 'Save';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get editTimezone => 'Change time zone';

  @override
  String get networkError =>
      'Unable to connect. Check your connection and try again.';

  @override
  String get authenticationError =>
      'Authentication is unavailable. Please retry or sign in again.';

  @override
  String get sessionExpired =>
      'Ledger could not verify your sign-in. Try again. If this continues after signing in again, contact support.';

  @override
  String get userDisabled =>
      'Your account has been disabled. Contact your instance administrator.';

  @override
  String get accessDenied => 'You do not have access to this resource.';

  @override
  String get unsupportedVersion =>
      'This app version is incompatible with the server. Update the app or contact the administrator.';

  @override
  String get invalidRequest =>
      'The server rejected these settings. Check the currency and IANA time zone where applicable.';

  @override
  String get notFoundError =>
      'This book is unavailable or no longer accessible.';

  @override
  String get serviceUnavailable =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get invalidResponse => 'The server returned an unexpected response.';

  @override
  String get signoutError =>
      'Sign out failed. Your local pages have been cleared. Retry signing out.';

  @override
  String get correlationLabel => 'Support reference';

  @override
  String get initializationTitle => 'Personal space setup';

  @override
  String get loginTitle => 'Sign in to Ledger';

  @override
  String get invalidFieldsLabel => 'Check these fields';

  @override
  String get welcomeTitle => 'A little clarity, every day.';

  @override
  String get welcomeBody =>
      'Your money, thoughtfully organized. Start with your personal ledger.';

  @override
  String get browserSignIn => 'Sign in / Sign up';

  @override
  String get browserSignInHint =>
      'Continue securely in your browser. You will return here when you are done.';

  @override
  String get browserSigningIn => 'Waiting for sign-in…';

  @override
  String get browserSignInError =>
      'Could not complete sign-in. Please try again.';

  @override
  String get setupCurrencyTitle => 'Make it your ledger';

  @override
  String get setupCurrencyBody =>
      'Choose the currency you use to see the big picture.';

  @override
  String get setupPreferencesTitle => 'A few personal touches';

  @override
  String get setupPreferencesBody =>
      'Choose your language and local time. You can change these later in Settings.';

  @override
  String get nextAction => 'Continue';

  @override
  String get previousAction => 'Back';

  @override
  String get startLedgerAction => 'Start my ledger';

  @override
  String get setupStepOne => 'STEP 1 OF 2';

  @override
  String get setupStepTwo => 'STEP 2 OF 2';

  @override
  String get searchOptions => 'Search';

  @override
  String get noOptionsFound => 'No matches found';

  @override
  String get currencySummary => 'Your ledger currency';

  @override
  String get catalogError => 'Could not load choices. Please try again.';

  @override
  String get preferencesTitle => 'Preferences';

  @override
  String get appInformationTitle => 'App information';

  @override
  String get personalAccountLabel => 'Personal account';

  @override
  String get defaultBadge => 'Default';

  @override
  String get currentSelectionLabel => 'Current selection';

  @override
  String get suggestedSelectionLabel => 'Suggested';

  @override
  String get supportDetailsLabel => 'Support details';

  @override
  String get refreshingLabel => 'Refreshing…';

  @override
  String get savingPreferencesLabel => 'Saving preferences…';

  @override
  String get booksEmptyExplanation =>
      'Your books will appear here when they are available.';

  @override
  String get loadErrorTitle => 'Could not load this content';

  @override
  String get configurationTitle => 'Connection unavailable';

  @override
  String get reviewTitle => 'Review your choices';

  @override
  String get sessionErrorTitle => 'Sign-in verification failed';

  @override
  String get requestErrorTitle => 'Unable to complete this request';

  @override
  String get accountsTab => 'Accounts';

  @override
  String get transactionsTab => 'Transactions';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountName => 'Account name';

  @override
  String get accountKind => 'Account type';

  @override
  String get accountCash => 'Cash';

  @override
  String get accountBank => 'Bank account';

  @override
  String get accountWallet => 'Digital wallet';

  @override
  String get accountOther => 'Other asset';

  @override
  String get openingBalance => 'Opening balance';

  @override
  String get openingDate => 'Opening date';

  @override
  String get openingType => 'Opening balance';

  @override
  String get incomeType => 'Income';

  @override
  String get expenseType => 'Expense';

  @override
  String get transferType => 'Transfer';

  @override
  String get refundType => 'Refund';

  @override
  String get transactionType => 'Transaction type';

  @override
  String get amountLabel => 'Amount';

  @override
  String get accountLabel => 'Account';

  @override
  String get sourceAccount => 'From account';

  @override
  String get destinationAccount => 'To account';

  @override
  String get sourcePrincipal => 'Transfer principal';

  @override
  String get destinationPrincipal => 'Received principal';

  @override
  String get categoryLabel => 'Category';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get counterpartyLabel => 'Counterparty';

  @override
  String get counterpartiesTitle => 'Counterparties';

  @override
  String get dateLabel => 'Date';

  @override
  String get noteLabel => 'Note';

  @override
  String get feeLabel => 'Fee';

  @override
  String get addFee => 'Add separate fee';

  @override
  String get feeAccount => 'Fee account';

  @override
  String get feeAmount => 'Fee amount';

  @override
  String get feeCategory => 'Fee category';

  @override
  String get saveEntry => 'Save transaction';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveAccount => 'Save account';

  @override
  String get editAction => 'Edit';

  @override
  String get deleteTransaction => 'Delete transaction';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get reviewTransaction => 'Review transaction';

  @override
  String get netAccountChanges => 'Account changes after fees';

  @override
  String get feeSeparateHint =>
      'Fees are separate expense transactions. Principal amounts exclude fees.';

  @override
  String get monthlySummary => 'This month';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get emptyAccountsTitle => 'Add your first account';

  @override
  String get emptyAccountsBody =>
      'Create an account and review its opening balance to start recording.';

  @override
  String get emptyTransactionsTitle => 'No transactions yet';

  @override
  String get emptyTransactionsBody =>
      'Record income, an expense or a transfer in this book.';

  @override
  String get emptySummary => 'No income or expenses in this period.';

  @override
  String get balanceLabel => 'Balance';

  @override
  String get archivedLabel => 'Archived';

  @override
  String get archiveLabel => 'Archive';

  @override
  String get restoreLabel => 'Restore';

  @override
  String get archiveHint => 'Archived items remain visible in history.';

  @override
  String get transactionDetail => 'Transaction';

  @override
  String get relatedTransactions => 'Related transactions';

  @override
  String get linkTransaction => 'Link transaction';

  @override
  String get relatedType => 'Related';

  @override
  String get feeRelation => 'Fee link';

  @override
  String get refundRelation => 'Refund for';

  @override
  String get removeLink => 'Remove association';

  @override
  String get addRefund => 'Record refund';

  @override
  String get refundRemaining => 'Refundable amount';

  @override
  String get historyTitle => 'History';

  @override
  String get voidedLabel => 'Deleted';

  @override
  String get revisionLabel => 'Revision';

  @override
  String get exchangeRateLabel => 'Actual exchange rate';

  @override
  String get includeFeesTitle => 'Include related fees';

  @override
  String get includeFeesHint =>
      'Only selected fees change with this transaction. Unselected fees remain recorded.';

  @override
  String get deleteHint =>
      'This records a reversal and keeps the original history. Review the fees below.';

  @override
  String get filtersTitle => 'Filter transactions';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get fromDate => 'From date';

  @override
  String get toDate => 'To date';

  @override
  String get allOption => 'All';

  @override
  String get noneOption => 'None';

  @override
  String get loadMore => 'Load more';

  @override
  String get bookManagement => 'Book management';

  @override
  String get selectBook => 'Book';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get parentCategory => 'Parent category';

  @override
  String get rootCategory => 'Root category';

  @override
  String get addCounterparty => 'Add counterparty';

  @override
  String get editCounterparty => 'Edit counterparty';

  @override
  String get counterpartyName => 'Counterparty name';

  @override
  String get fieldRequired => 'Complete this field.';

  @override
  String get invalidAmount =>
      'Use a valid amount within this currency’s precision.';

  @override
  String get invalidDate => 'Use a valid YYYY-MM-DD date.';

  @override
  String get selectRequired => 'Choose an account and category where required.';

  @override
  String get accountingConflict =>
      'This record changed, or the operation conflicts with its related transactions. Refresh and review before retrying.';

  @override
  String get pendingWriteTitle => 'Save result not confirmed';

  @override
  String get pendingWriteBody =>
      'Retry the original request to confirm whether it was saved. Its contents and retry key are preserved.';

  @override
  String get resolveWrite => 'Confirm saved result';

  @override
  String get noMatches => 'No matching transactions';

  @override
  String get reloadDetail => 'Reload current record';

  @override
  String get includeDeleted => 'Include deleted transactions';

  @override
  String get sameAccountError => 'Choose two different accounts.';

  @override
  String get categoryArchiveHint =>
      'Archiving a root also archives its children.';

  @override
  String get feeSelectExisting => 'Link existing expense as fee';

  @override
  String get chooseTransaction => 'Choose transaction';

  @override
  String get unselectedFeesRemain => 'Unselected fees remain unchanged.';

  @override
  String get viewAllTransactions => 'View transactions';

  @override
  String get byCategoryTitle => 'By category';

  @override
  String get currentBookLabel => 'Current book';

  @override
  String get principalLabel => 'Principal';

  @override
  String get resultSaved => 'Saved';

  @override
  String get returnToEntry => 'Back to entry';

  @override
  String get reversalLabel => 'Reversal';

  @override
  String get postingLabel => 'Posting';
}
