import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get appTitle;

  /// Home navigation tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// Settings page title and navigation tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Title displayed before a ledger exists.
  ///
  /// In en, this message translates to:
  /// **'Start your ledger here'**
  String get homeEmptyTitle;

  /// Empty ledger list message.
  ///
  /// In en, this message translates to:
  /// **'No ledgers yet'**
  String get homeEmptyBody;

  /// Theme preferences section heading.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Follow the system color theme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Use the light color theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Use the dark color theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Application language section heading.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// English language option, shown in its native name.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Simplified Chinese language option, shown in its native name.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// Title for an unknown route.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFoundTitle;

  /// Description for an unknown route.
  ///
  /// In en, this message translates to:
  /// **'This page is not available.'**
  String get pageNotFoundBody;

  /// Return to the home page from an unknown route.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// Endpoint configuration UI: API Endpoint
  ///
  /// In en, this message translates to:
  /// **'API Endpoint'**
  String get endpointLabel;

  /// Endpoint configuration UI: Server
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// Shown when the deployment API endpoint is missing or invalid.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get endpointUnavailable;

  /// Personal identity interface: configurationNeeded
  ///
  /// In en, this message translates to:
  /// **'Client configuration is missing or invalid. Check the deployment configuration.'**
  String get configurationNeeded;

  /// Personal identity interface: loadingLabel
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingLabel;

  /// Personal identity interface: retryAction
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// Personal identity interface: signOutAction
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutAction;

  /// Personal identity interface: createSpace
  ///
  /// In en, this message translates to:
  /// **'Create your personal space'**
  String get createSpace;

  /// Personal identity interface: currencyLabel
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get currencyLabel;

  /// Personal identity interface: timezoneLabel
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timezoneLabel;

  /// Personal identity interface: currencyWarning
  ///
  /// In en, this message translates to:
  /// **'The base currency cannot be changed after creation. Review these settings before continuing.'**
  String get currencyWarning;

  /// Personal identity interface: defaultsWarning
  ///
  /// In en, this message translates to:
  /// **'Some device settings could not be detected. Review the suggested USD currency and/or UTC time zone.'**
  String get defaultsWarning;

  /// Personal identity interface: createAction
  ///
  /// In en, this message translates to:
  /// **'Create personal space'**
  String get createAction;

  /// Personal identity interface: requiredValue
  ///
  /// In en, this message translates to:
  /// **'Enter a valid value.'**
  String get requiredValue;

  /// Personal identity interface: currencyValidation
  ///
  /// In en, this message translates to:
  /// **'Use a three-letter uppercase ISO currency code.'**
  String get currencyValidation;

  /// Personal identity interface: booksTitle
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get booksTitle;

  /// Personal identity interface: refreshAction
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAction;

  /// Personal identity interface: bookDetailsTitle
  ///
  /// In en, this message translates to:
  /// **'Book details'**
  String get bookDetailsTitle;

  /// Personal identity interface: personalSpaceLabel
  ///
  /// In en, this message translates to:
  /// **'Personal space'**
  String get personalSpaceLabel;

  /// Personal identity interface: identityLabel
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get identityLabel;

  /// Personal identity interface: defaultBookLabel
  ///
  /// In en, this message translates to:
  /// **'Default book'**
  String get defaultBookLabel;

  /// Personal identity interface: saveAction
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// Phase two accounting interface: cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Personal identity interface: editTimezone
  ///
  /// In en, this message translates to:
  /// **'Change time zone'**
  String get editTimezone;

  /// Personal identity interface: networkError
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your connection and try again.'**
  String get networkError;

  /// Personal identity interface: authenticationError
  ///
  /// In en, this message translates to:
  /// **'Authentication is unavailable. Please retry or sign in again.'**
  String get authenticationError;

  /// Personal identity interface: sessionExpired
  ///
  /// In en, this message translates to:
  /// **'Ledger could not verify your sign-in. Try again. If this continues after signing in again, contact support.'**
  String get sessionExpired;

  /// Personal identity interface: userDisabled
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled. Contact your instance administrator.'**
  String get userDisabled;

  /// Personal identity interface: accessDenied
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this resource.'**
  String get accessDenied;

  /// Personal identity interface: unsupportedVersion
  ///
  /// In en, this message translates to:
  /// **'This app version is incompatible with the server. Update the app or contact the administrator.'**
  String get unsupportedVersion;

  /// Personal identity interface: invalidRequest
  ///
  /// In en, this message translates to:
  /// **'The server rejected these settings. Check the currency and IANA time zone where applicable.'**
  String get invalidRequest;

  /// Personal identity interface: notFoundError
  ///
  /// In en, this message translates to:
  /// **'This book is unavailable or no longer accessible.'**
  String get notFoundError;

  /// Personal identity interface: serviceUnavailable
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again later.'**
  String get serviceUnavailable;

  /// Personal identity interface: genericError
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// Personal identity interface: invalidResponse
  ///
  /// In en, this message translates to:
  /// **'The server returned an unexpected response.'**
  String get invalidResponse;

  /// Personal identity interface: signoutError
  ///
  /// In en, this message translates to:
  /// **'Sign out failed. Your local pages have been cleared. Retry signing out.'**
  String get signoutError;

  /// Personal identity interface: correlationLabel
  ///
  /// In en, this message translates to:
  /// **'Support reference'**
  String get correlationLabel;

  /// Personal identity interface: initializationTitle
  ///
  /// In en, this message translates to:
  /// **'Personal space setup'**
  String get initializationTitle;

  /// Personal identity interface: loginTitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to Ledger'**
  String get loginTitle;

  /// Personal identity interface: invalidFieldsLabel
  ///
  /// In en, this message translates to:
  /// **'Check these fields'**
  String get invalidFieldsLabel;

  /// Authentication and onboarding: welcomeTitle
  ///
  /// In en, this message translates to:
  /// **'A little clarity, every day.'**
  String get welcomeTitle;

  /// Authentication and onboarding: welcomeBody
  ///
  /// In en, this message translates to:
  /// **'Your money, thoughtfully organized. Start with your personal ledger.'**
  String get welcomeBody;

  /// Authentication and onboarding: browserSignIn
  ///
  /// In en, this message translates to:
  /// **'Sign in / Sign up'**
  String get browserSignIn;

  /// Authentication and onboarding: browserSignInHint
  ///
  /// In en, this message translates to:
  /// **'Continue securely in your browser. You will return here when you are done.'**
  String get browserSignInHint;

  /// Authentication and onboarding: browserSigningIn
  ///
  /// In en, this message translates to:
  /// **'Waiting for sign-in…'**
  String get browserSigningIn;

  /// Authentication and onboarding: browserSignInError
  ///
  /// In en, this message translates to:
  /// **'Could not complete sign-in. Please try again.'**
  String get browserSignInError;

  /// Authentication and onboarding: setupCurrencyTitle
  ///
  /// In en, this message translates to:
  /// **'Make it your ledger'**
  String get setupCurrencyTitle;

  /// Authentication and onboarding: setupCurrencyBody
  ///
  /// In en, this message translates to:
  /// **'Choose the currency you use to see the big picture.'**
  String get setupCurrencyBody;

  /// Authentication and onboarding: setupPreferencesTitle
  ///
  /// In en, this message translates to:
  /// **'A few personal touches'**
  String get setupPreferencesTitle;

  /// Authentication and onboarding: setupPreferencesBody
  ///
  /// In en, this message translates to:
  /// **'Choose your language and local time. You can change these later in Settings.'**
  String get setupPreferencesBody;

  /// Authentication and onboarding: nextAction
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get nextAction;

  /// Authentication and onboarding: previousAction
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get previousAction;

  /// Authentication and onboarding: startLedgerAction
  ///
  /// In en, this message translates to:
  /// **'Start my ledger'**
  String get startLedgerAction;

  /// Authentication and onboarding: setupStepOne
  ///
  /// In en, this message translates to:
  /// **'STEP 1 OF 2'**
  String get setupStepOne;

  /// Authentication and onboarding: setupStepTwo
  ///
  /// In en, this message translates to:
  /// **'STEP 2 OF 2'**
  String get setupStepTwo;

  /// Authentication and onboarding: searchOptions
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchOptions;

  /// Authentication and onboarding: noOptionsFound
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noOptionsFound;

  /// Authentication and onboarding: currencySummary
  ///
  /// In en, this message translates to:
  /// **'Your ledger currency'**
  String get currencySummary;

  /// Authentication and onboarding: catalogError
  ///
  /// In en, this message translates to:
  /// **'Could not load choices. Please try again.'**
  String get catalogError;

  /// Shared Ledger design system: preferencesTitle
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesTitle;

  /// Shared Ledger design system: appInformationTitle
  ///
  /// In en, this message translates to:
  /// **'App information'**
  String get appInformationTitle;

  /// Shared Ledger design system: personalAccountLabel
  ///
  /// In en, this message translates to:
  /// **'Personal account'**
  String get personalAccountLabel;

  /// Shared Ledger design system: defaultBadge
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultBadge;

  /// Shared Ledger design system: currentSelectionLabel
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get currentSelectionLabel;

  /// Shared Ledger design system: suggestedSelectionLabel
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get suggestedSelectionLabel;

  /// Shared Ledger design system: supportDetailsLabel
  ///
  /// In en, this message translates to:
  /// **'Support details'**
  String get supportDetailsLabel;

  /// Shared Ledger design system: refreshingLabel
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get refreshingLabel;

  /// Shared Ledger design system: savingPreferencesLabel
  ///
  /// In en, this message translates to:
  /// **'Saving preferences…'**
  String get savingPreferencesLabel;

  /// Shared Ledger design system: booksEmptyExplanation
  ///
  /// In en, this message translates to:
  /// **'Your books will appear here when they are available.'**
  String get booksEmptyExplanation;

  /// Shared Ledger design system: loadErrorTitle
  ///
  /// In en, this message translates to:
  /// **'Could not load this content'**
  String get loadErrorTitle;

  /// Shared Ledger design system: configurationTitle
  ///
  /// In en, this message translates to:
  /// **'Connection unavailable'**
  String get configurationTitle;

  /// Shared Ledger design system: reviewTitle
  ///
  /// In en, this message translates to:
  /// **'Review your choices'**
  String get reviewTitle;

  /// Heading for rejected authentication.
  ///
  /// In en, this message translates to:
  /// **'Sign-in verification failed'**
  String get sessionErrorTitle;

  /// Heading for a failed request.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete this request'**
  String get requestErrorTitle;

  /// Phase two accounting interface: accountsTab.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTab;

  /// Phase two accounting interface: transactionsTab.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTab;

  /// Phase two accounting interface: addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// Phase two accounting interface: addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// Phase two accounting interface: editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// Phase two accounting interface: accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// Phase two accounting interface: accountKind.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountKind;

  /// Phase two accounting interface: accountCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountCash;

  /// Phase two accounting interface: accountBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get accountBank;

  /// Phase two accounting interface: accountWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get accountWallet;

  /// Phase two accounting interface: accountOther.
  ///
  /// In en, this message translates to:
  /// **'Other asset'**
  String get accountOther;

  /// Phase two accounting interface: openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingBalance;

  /// Phase two accounting interface: openingDate.
  ///
  /// In en, this message translates to:
  /// **'Opening date'**
  String get openingDate;

  /// Phase two accounting interface: openingType.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingType;

  /// Phase two accounting interface: incomeType.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeType;

  /// Phase two accounting interface: expenseType.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseType;

  /// Phase two accounting interface: transferType.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferType;

  /// Phase two accounting interface: refundType.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refundType;

  /// Phase two accounting interface: transactionType.
  ///
  /// In en, this message translates to:
  /// **'Transaction type'**
  String get transactionType;

  /// Phase two accounting interface: amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// Phase two accounting interface: accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// Phase two accounting interface: sourceAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get sourceAccount;

  /// Phase two accounting interface: destinationAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get destinationAccount;

  /// Phase two accounting interface: sourcePrincipal.
  ///
  /// In en, this message translates to:
  /// **'Transfer principal'**
  String get sourcePrincipal;

  /// Phase two accounting interface: destinationPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Received principal'**
  String get destinationPrincipal;

  /// Phase two accounting interface: categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// Phase two accounting interface: categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// Phase two accounting interface: counterpartyLabel.
  ///
  /// In en, this message translates to:
  /// **'Counterparty'**
  String get counterpartyLabel;

  /// Phase two accounting interface: counterpartiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Counterparties'**
  String get counterpartiesTitle;

  /// Phase two accounting interface: dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// Phase two accounting interface: noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// Phase two accounting interface: feeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get feeLabel;

  /// Phase two accounting interface: addFee.
  ///
  /// In en, this message translates to:
  /// **'Add separate fee'**
  String get addFee;

  /// Phase two accounting interface: feeAccount.
  ///
  /// In en, this message translates to:
  /// **'Fee account'**
  String get feeAccount;

  /// Phase two accounting interface: feeAmount.
  ///
  /// In en, this message translates to:
  /// **'Fee amount'**
  String get feeAmount;

  /// Phase two accounting interface: feeCategory.
  ///
  /// In en, this message translates to:
  /// **'Fee category'**
  String get feeCategory;

  /// Phase two accounting interface: saveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save transaction'**
  String get saveEntry;

  /// Phase two accounting interface: saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// Phase two accounting interface: saveAccount.
  ///
  /// In en, this message translates to:
  /// **'Save account'**
  String get saveAccount;

  /// Phase two accounting interface: editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// Phase two accounting interface: deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransaction;

  /// Phase two accounting interface: confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// Phase two accounting interface: reviewTransaction.
  ///
  /// In en, this message translates to:
  /// **'Review transaction'**
  String get reviewTransaction;

  /// Phase two accounting interface: netAccountChanges.
  ///
  /// In en, this message translates to:
  /// **'Account changes after fees'**
  String get netAccountChanges;

  /// Phase two accounting interface: feeSeparateHint.
  ///
  /// In en, this message translates to:
  /// **'Fees are separate expense transactions. Principal amounts exclude fees.'**
  String get feeSeparateHint;

  /// Phase two accounting interface: monthlySummary.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get monthlySummary;

  /// Phase two accounting interface: recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactions;

  /// Phase two accounting interface: emptyAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first account'**
  String get emptyAccountsTitle;

  /// Phase two accounting interface: emptyAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'Create an account and review its opening balance to start recording.'**
  String get emptyAccountsBody;

  /// Phase two accounting interface: emptyTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get emptyTransactionsTitle;

  /// Phase two accounting interface: emptyTransactionsBody.
  ///
  /// In en, this message translates to:
  /// **'Record income, an expense or a transfer in this book.'**
  String get emptyTransactionsBody;

  /// Phase two accounting interface: emptySummary.
  ///
  /// In en, this message translates to:
  /// **'No income or expenses in this period.'**
  String get emptySummary;

  /// Phase two accounting interface: balanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balanceLabel;

  /// Phase two accounting interface: archivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedLabel;

  /// Phase two accounting interface: archiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveLabel;

  /// Phase two accounting interface: restoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreLabel;

  /// Phase two accounting interface: archiveHint.
  ///
  /// In en, this message translates to:
  /// **'Archived items remain visible in history.'**
  String get archiveHint;

  /// Phase two accounting interface: transactionDetail.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionDetail;

  /// Phase two accounting interface: relatedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Related transactions'**
  String get relatedTransactions;

  /// Phase two accounting interface: linkTransaction.
  ///
  /// In en, this message translates to:
  /// **'Link transaction'**
  String get linkTransaction;

  /// Phase two accounting interface: relatedType.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get relatedType;

  /// Phase two accounting interface: feeRelation.
  ///
  /// In en, this message translates to:
  /// **'Fee link'**
  String get feeRelation;

  /// Phase two accounting interface: refundRelation.
  ///
  /// In en, this message translates to:
  /// **'Refund for'**
  String get refundRelation;

  /// Phase two accounting interface: removeLink.
  ///
  /// In en, this message translates to:
  /// **'Remove association'**
  String get removeLink;

  /// Phase two accounting interface: addRefund.
  ///
  /// In en, this message translates to:
  /// **'Record refund'**
  String get addRefund;

  /// Phase two accounting interface: refundRemaining.
  ///
  /// In en, this message translates to:
  /// **'Refundable amount'**
  String get refundRemaining;

  /// Phase two accounting interface: historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// Phase two accounting interface: voidedLabel.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get voidedLabel;

  /// Phase two accounting interface: revisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get revisionLabel;

  /// Phase two accounting interface: exchangeRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Actual exchange rate'**
  String get exchangeRateLabel;

  /// Phase two accounting interface: includeFeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Include related fees'**
  String get includeFeesTitle;

  /// Phase two accounting interface: includeFeesHint.
  ///
  /// In en, this message translates to:
  /// **'Only selected fees change with this transaction. Unselected fees remain recorded.'**
  String get includeFeesHint;

  /// Phase two accounting interface: deleteHint.
  ///
  /// In en, this message translates to:
  /// **'This records a reversal and keeps the original history. Review the fees below.'**
  String get deleteHint;

  /// Phase two accounting interface: filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter transactions'**
  String get filtersTitle;

  /// Phase two accounting interface: applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// Phase two accounting interface: clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// Phase two accounting interface: fromDate.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get fromDate;

  /// Phase two accounting interface: toDate.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get toDate;

  /// Phase two accounting interface: allOption.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allOption;

  /// Phase two accounting interface: noneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOption;

  /// Phase two accounting interface: loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// Phase two accounting interface: bookManagement.
  ///
  /// In en, this message translates to:
  /// **'Book management'**
  String get bookManagement;

  /// Phase two accounting interface: selectBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get selectBook;

  /// Phase two accounting interface: addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// Phase two accounting interface: editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// Phase two accounting interface: categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// Phase two accounting interface: parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get parentCategory;

  /// Phase two accounting interface: rootCategory.
  ///
  /// In en, this message translates to:
  /// **'Root category'**
  String get rootCategory;

  /// Phase two accounting interface: addCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Add counterparty'**
  String get addCounterparty;

  /// Phase two accounting interface: editCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Edit counterparty'**
  String get editCounterparty;

  /// Phase two accounting interface: counterpartyName.
  ///
  /// In en, this message translates to:
  /// **'Counterparty name'**
  String get counterpartyName;

  /// Phase two accounting interface: fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete this field.'**
  String get fieldRequired;

  /// Phase two accounting interface: invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Use a valid amount within this currency’s precision.'**
  String get invalidAmount;

  /// Phase two accounting interface: invalidDate.
  ///
  /// In en, this message translates to:
  /// **'Use a valid YYYY-MM-DD date.'**
  String get invalidDate;

  /// Phase two accounting interface: selectRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an account and category where required.'**
  String get selectRequired;

  /// Phase two accounting interface: accountingConflict.
  ///
  /// In en, this message translates to:
  /// **'This record changed, or the operation conflicts with its related transactions. Refresh and review before retrying.'**
  String get accountingConflict;

  /// Phase two accounting interface: pendingWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Save result not confirmed'**
  String get pendingWriteTitle;

  /// Phase two accounting interface: pendingWriteBody.
  ///
  /// In en, this message translates to:
  /// **'Retry the original request to confirm whether it was saved. Its contents and retry key are preserved.'**
  String get pendingWriteBody;

  /// Phase two accounting interface: resolveWrite.
  ///
  /// In en, this message translates to:
  /// **'Confirm saved result'**
  String get resolveWrite;

  /// Phase two accounting interface: noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions'**
  String get noMatches;

  /// Phase two accounting interface: reloadDetail.
  ///
  /// In en, this message translates to:
  /// **'Reload current record'**
  String get reloadDetail;

  /// Phase two accounting interface: includeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Include deleted transactions'**
  String get includeDeleted;

  /// Phase two accounting interface: sameAccountError.
  ///
  /// In en, this message translates to:
  /// **'Choose two different accounts.'**
  String get sameAccountError;

  /// Phase two accounting interface: categoryArchiveHint.
  ///
  /// In en, this message translates to:
  /// **'Archiving a root also archives its children.'**
  String get categoryArchiveHint;

  /// Phase two accounting interface: feeSelectExisting.
  ///
  /// In en, this message translates to:
  /// **'Link existing expense as fee'**
  String get feeSelectExisting;

  /// Phase two accounting interface: chooseTransaction.
  ///
  /// In en, this message translates to:
  /// **'Choose transaction'**
  String get chooseTransaction;

  /// Phase two accounting interface: unselectedFeesRemain.
  ///
  /// In en, this message translates to:
  /// **'Unselected fees remain unchanged.'**
  String get unselectedFeesRemain;

  /// Phase two accounting interface: viewAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'View transactions'**
  String get viewAllTransactions;

  /// Phase two accounting interface: byCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get byCategoryTitle;

  /// Phase two accounting interface: currentBookLabel.
  ///
  /// In en, this message translates to:
  /// **'Current book'**
  String get currentBookLabel;

  /// Phase two accounting interface: principalLabel.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get principalLabel;

  /// Phase two accounting interface: resultSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get resultSaved;

  /// Phase two accounting interface: returnToEntry.
  ///
  /// In en, this message translates to:
  /// **'Back to entry'**
  String get returnToEntry;

  /// Label for an immutable reversing journal.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get reversalLabel;

  /// Label for an immutable posted journal.
  ///
  /// In en, this message translates to:
  /// **'Posting'**
  String get postingLabel;

  /// Shared page refinement: detailStatusPosted.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get detailStatusPosted;

  /// Shared page refinement: detailRelatedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Related transaction unavailable'**
  String get detailRelatedUnavailable;

  /// Shared page refinement: detailRelatedRetryBody.
  ///
  /// In en, this message translates to:
  /// **'Your transaction is available. Retry loading this related record.'**
  String get detailRelatedRetryBody;

  /// Shared page refinement: detailFeesIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Load all linked fees before reviewing a reversal.'**
  String get detailFeesIncomplete;

  /// Shared page refinement: detailNoRelations.
  ///
  /// In en, this message translates to:
  /// **'No related transactions yet.'**
  String get detailNoRelations;

  /// Shared page refinement: detailReversalChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes after reversal'**
  String get detailReversalChanges;

  /// Shared page refinement: detailRecordedAt.
  ///
  /// In en, this message translates to:
  /// **'Recorded at'**
  String get detailRecordedAt;

  /// Shared page refinement: detailLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Use Link on a transaction to add this relationship. Linking does not change balances.'**
  String get detailLinkHint;

  /// Shared page refinement: detailLinkFeeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a recorded expense to link as a fee. Its existing amount stays unchanged.'**
  String get detailLinkFeeHint;

  /// Shared page refinement: detailLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get detailLinkAction;

  /// Shared page refinement: detailLinkSource.
  ///
  /// In en, this message translates to:
  /// **'Linking from'**
  String get detailLinkSource;

  /// Shared page refinement: detailLinkEmpty.
  ///
  /// In en, this message translates to:
  /// **'No eligible transactions are available. Return to the transaction to continue.'**
  String get detailLinkEmpty;

  /// Shared page refinement: detailSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get detailSaving;

  /// Shared page refinement: preferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Preference not saved'**
  String get preferencesSaveFailed;

  /// Shared page refinement: preferencesRetrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry saving'**
  String get preferencesRetrySave;

  /// Shared page refinement: preferencesPreviousKept.
  ///
  /// In en, this message translates to:
  /// **'Your previous setting is still active. Retry to apply this selection.'**
  String get preferencesPreviousKept;

  /// Shared page refinement: preferencesPendingValue.
  ///
  /// In en, this message translates to:
  /// **'Selected value'**
  String get preferencesPendingValue;

  /// Shared page refinement: signingOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get signingOutLabel;

  /// Shared page refinement: setupReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Review before continuing'**
  String get setupReviewNotice;

  /// Shared page refinement: setupFallbackNotice.
  ///
  /// In en, this message translates to:
  /// **'Review device defaults'**
  String get setupFallbackNotice;

  /// Shared page refinement: backAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backAction;

  /// Shared page refinement: noActiveAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'No active accounts'**
  String get noActiveAccountsTitle;

  /// Shared page refinement: noActiveAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'All accounts in this book are archived. Review your accounts or add an account to record a transaction.'**
  String get noActiveAccountsBody;

  /// Shared page refinement: viewAccountsAction.
  ///
  /// In en, this message translates to:
  /// **'View accounts'**
  String get viewAccountsAction;

  /// Shared page refinement: archivedAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This account is archived. Its balance and transaction history remain available. Edit the account to restore it.'**
  String get archivedAccountBody;

  /// Shared page refinement: accountTransactionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Transactions for this account will appear here.'**
  String get accountTransactionsEmptyBody;

  /// Shared page refinement: accountUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Account unavailable'**
  String get accountUnavailableTitle;

  /// Shared page refinement: accountUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This account is not available in the selected book. Return to your accounts to continue.'**
  String get accountUnavailableBody;

  /// Shared page refinement: noMatchingTransactionsBody.
  ///
  /// In en, this message translates to:
  /// **'No transactions match these filters. Adjust or clear the filters to see more results.'**
  String get noMatchingTransactionsBody;

  /// Shared page refinement: dateRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRangeTitle;

  /// Shared page refinement: transactionConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction filters'**
  String get transactionConditionsTitle;

  /// Shared page refinement: displayOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Display options'**
  String get displayOptionsTitle;

  /// Shared page refinement: filterDateFormatHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD. Leave blank for any date.'**
  String get filterDateFormatHint;

  /// Shared page refinement: invalidDateRange.
  ///
  /// In en, this message translates to:
  /// **'The end date must be on or after the start date.'**
  String get invalidDateRange;

  /// Shared page refinement: appliedFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Applied filters'**
  String get appliedFiltersTitle;

  /// Shared page refinement: loadMoreErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'More transactions could not be loaded'**
  String get loadMoreErrorTitle;

  /// Shared page refinement: loadMoreErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your current results are still available. Try loading the next page again.'**
  String get loadMoreErrorBody;

  /// Shared page refinement: retryLoadMoreAction.
  ///
  /// In en, this message translates to:
  /// **'Retry loading'**
  String get retryLoadMoreAction;

  /// Shared page refinement: filterApplyErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters could not be applied'**
  String get filterApplyErrorTitle;

  /// Shared page refinement: filterApplyErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your filter choices and previous results are still available. Try applying the filters again.'**
  String get filterApplyErrorBody;

  /// Shared page refinement: selectFieldPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get selectFieldPlaceholder;

  /// Shared page refinement: selectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Selection unavailable'**
  String get selectionUnavailable;

  /// Page refinement: formReviewField.
  ///
  /// In en, this message translates to:
  /// **'Review this value and try again.'**
  String get formReviewField;

  /// Page refinement: formReviewFields.
  ///
  /// In en, this message translates to:
  /// **'Review your entries'**
  String get formReviewFields;

  /// Page refinement: formSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get formSaving;

  /// Page refinement: formResolveSave.
  ///
  /// In en, this message translates to:
  /// **'Check save result'**
  String get formResolveSave;

  /// Page refinement: formPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The save result is not confirmed. Your entries are temporarily locked. Check the result using the original request.'**
  String get formPendingBody;

  /// Page refinement: formChooseCurrencyAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account to set the currency first.'**
  String get formChooseCurrencyAccount;

  /// Page refinement: formPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get formPositiveAmount;

  /// Page refinement: formRefundLimitError.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds the refundable amount shown above.'**
  String get formRefundLimitError;

  /// Page refinement: formChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get formChooseDate;

  /// Page refinement: formDateHint.
  ///
  /// In en, this message translates to:
  /// **'Use YYYY-MM-DD, or choose a date.'**
  String get formDateHint;

  /// Page refinement: formAmountExample.
  ///
  /// In en, this message translates to:
  /// **'Example:'**
  String get formAmountExample;

  /// Page refinement: formSignedAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Use a positive or negative amount.'**
  String get formSignedAmountHint;

  /// Page refinement: formAccountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Account currency'**
  String get formAccountCurrency;

  /// Page refinement: formAccountCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'The account currency cannot change after creation.'**
  String get formAccountCurrencyHint;

  /// Page refinement: formOpeningHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Leave blank or enter zero if there is no opening balance. Use a negative amount for a negative opening balance.'**
  String get formOpeningHint;

  /// Page refinement: formCategoryTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'This category uses the transaction type of your entry.'**
  String get formCategoryTypeFixed;

  /// Page refinement: formOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get formOptional;

  /// Page refinement: formActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get formActive;

  /// Page refinement: formConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Review the latest record'**
  String get formConflictTitle;

  /// Page refinement: formConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Your entries are kept. Load the latest record and review the differences before saving again.'**
  String get formConflictBody;

  /// Page refinement: formConflictReview.
  ///
  /// In en, this message translates to:
  /// **'Loading the latest record does not replace your entries. Choose which values to keep, then review and save again.'**
  String get formConflictReview;

  /// Page refinement: formLatestValues.
  ///
  /// In en, this message translates to:
  /// **'Latest saved values'**
  String get formLatestValues;

  /// Page refinement: formYourDraft.
  ///
  /// In en, this message translates to:
  /// **'Your entries'**
  String get formYourDraft;

  /// Page refinement: formUseLatest.
  ///
  /// In en, this message translates to:
  /// **'Use latest values'**
  String get formUseLatest;

  /// Page refinement: formKeepDraft.
  ///
  /// In en, this message translates to:
  /// **'Keep my entries'**
  String get formKeepDraft;

  /// Page refinement: formReviewLatest.
  ///
  /// In en, this message translates to:
  /// **'Load and compare'**
  String get formReviewLatest;

  /// Page refinement: formSelectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This choice is no longer available. Choose another value.'**
  String get formSelectionUnavailable;

  /// Page refinement: formCategoryMismatch.
  ///
  /// In en, this message translates to:
  /// **'The new category does not match this transaction type. Choose a matching category.'**
  String get formCategoryMismatch;

  /// Page refinement: formLatestFee.
  ///
  /// In en, this message translates to:
  /// **'Latest saved fee'**
  String get formLatestFee;

  /// Page refinement: formDraftFee.
  ///
  /// In en, this message translates to:
  /// **'Your fee entries'**
  String get formDraftFee;

  /// Page refinement: formUnavailableFees.
  ///
  /// In en, this message translates to:
  /// **'Some fees can no longer be corrected with this transaction. Their entries are kept for reference and will not be submitted.'**
  String get formUnavailableFees;

  /// Page refinement: formPreviousEntry.
  ///
  /// In en, this message translates to:
  /// **'Previous transaction'**
  String get formPreviousEntry;

  /// Page refinement: formUpdatedEntry.
  ///
  /// In en, this message translates to:
  /// **'Updated transaction'**
  String get formUpdatedEntry;

  /// Page refinement: formPreviousFee.
  ///
  /// In en, this message translates to:
  /// **'Previous fee'**
  String get formPreviousFee;

  /// Page refinement: formUpdatedFee.
  ///
  /// In en, this message translates to:
  /// **'Updated fee'**
  String get formUpdatedFee;

  /// Page refinement: formCorrectTransaction.
  ///
  /// In en, this message translates to:
  /// **'Correct transaction'**
  String get formCorrectTransaction;

  /// Page refinement: formSaveCorrection.
  ///
  /// In en, this message translates to:
  /// **'Review correction'**
  String get formSaveCorrection;

  /// Page refinement: formOriginalExpense.
  ///
  /// In en, this message translates to:
  /// **'Original expense'**
  String get formOriginalExpense;

  /// Page refinement: formLinkedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Linked transaction'**
  String get formLinkedTransaction;

  /// Page refinement: formCorrectionHint.
  ///
  /// In en, this message translates to:
  /// **'Corrections keep the transaction history. Only fees you select will change.'**
  String get formCorrectionHint;

  /// Page refinement: formNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'An account is needed'**
  String get formNoAccounts;

  /// Page refinement: formCreateAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Create an account before recording this transaction.'**
  String get formCreateAccountHint;

  /// Page refinement: formTransactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get formTransactionDetails;

  /// Page refinement: formAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get formAdditionalDetails;

  /// Page refinement: formOpeningAccountFixed.
  ///
  /// In en, this message translates to:
  /// **'An opening balance stays with its original account.'**
  String get formOpeningAccountFixed;

  /// Page refinement: formRefundCategoryFixed.
  ///
  /// In en, this message translates to:
  /// **'Refunds keep the original expense category.'**
  String get formRefundCategoryFixed;

  /// Page refinement: formSameCurrencyPrincipal.
  ///
  /// In en, this message translates to:
  /// **'For the same currency, both principal amounts must match. Record fees separately.'**
  String get formSameCurrencyPrincipal;

  /// Page refinement: formRecordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This transaction was deleted and cannot be changed. Your entries are kept here for reference. Return to the transaction list to continue.'**
  String get formRecordUnavailable;

  /// Transaction detail action menu: More actions
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get detailMoreActions;

  /// Transaction detail action menu: New records
  ///
  /// In en, this message translates to:
  /// **'New records'**
  String get detailNewRecords;

  /// Transaction detail action menu: Link existing records
  ///
  /// In en, this message translates to:
  /// **'Link existing records'**
  String get detailLinkExisting;

  /// Transaction detail action menu: Add fee
  ///
  /// In en, this message translates to:
  /// **'Add fee'**
  String get detailAddFee;

  /// Transaction detail action menu: Record a new fee linked to this transaction
  ///
  /// In en, this message translates to:
  /// **'Record a new fee linked to this transaction'**
  String get detailAddFeeHint;

  /// Transaction detail action menu: Link transaction
  ///
  /// In en, this message translates to:
  /// **'Link transaction'**
  String get detailLinkTransaction;

  /// Transaction detail action menu: Link fee
  ///
  /// In en, this message translates to:
  /// **'Link fee'**
  String get detailLinkFee;

  /// Explains linking an existing fee in the transaction action menu.
  ///
  /// In en, this message translates to:
  /// **'Select a fee from existing transactions'**
  String get detailMenuLinkFeeHint;

  /// Transaction detail action menu: Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get detailCloseActions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
