// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Ledger';

  @override
  String get homeTab => '首页';

  @override
  String get settingsTitle => '设置';

  @override
  String get homeEmptyTitle => '从这里开始记录';

  @override
  String get homeEmptyBody => '暂无账本';

  @override
  String get appearanceTitle => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get languageTitle => '语言';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get pageNotFoundTitle => '页面不存在';

  @override
  String get pageNotFoundBody => '此页面暂不可用。';

  @override
  String get backToHome => '返回首页';

  @override
  String get endpointLabel => 'API 地址';

  @override
  String get serverTitle => '服务器';

  @override
  String get endpointUnavailable => '未配置';

  @override
  String get configurationNeeded => '客户端配置缺失或无效，请检查部署配置。';

  @override
  String get loadingLabel => '加载中…';

  @override
  String get retryAction => '重试';

  @override
  String get signOutAction => '退出登录';

  @override
  String get createSpace => '创建个人空间';

  @override
  String get currencyLabel => '本位币';

  @override
  String get timezoneLabel => '时区';

  @override
  String get currencyWarning => '创建后无法修改本位币，请核对设置后继续。';

  @override
  String get defaultsWarning => '部分设备设置无法识别，请核对回退使用的 USD 币种或 UTC 时区。';

  @override
  String get createAction => '创建个人空间';

  @override
  String get requiredValue => '请输入有效值。';

  @override
  String get currencyValidation => '请输入三位大写 ISO 币种代码。';

  @override
  String get booksTitle => '账本';

  @override
  String get refreshAction => '刷新';

  @override
  String get bookDetailsTitle => '账本详情';

  @override
  String get personalSpaceLabel => '个人空间';

  @override
  String get identityLabel => '用户';

  @override
  String get defaultBookLabel => '默认账本';

  @override
  String get saveAction => '保存';

  @override
  String get cancelAction => '取消';

  @override
  String get editTimezone => '修改时区';

  @override
  String get networkError => '连接失败，请检查网络后重试。';

  @override
  String get authenticationError => '认证暂不可用，请重试或重新登录。';

  @override
  String get sessionExpired => 'Ledger 无法验证你的登录状态，请重试。如果重新登录后仍然出现此问题，请联系支持。';

  @override
  String get userDisabled => '账号已被停用，请联系实例管理员。';

  @override
  String get accessDenied => '你无权访问此资源。';

  @override
  String get unsupportedVersion => '客户端版本与服务器不兼容，请更新应用或联系管理员。';

  @override
  String get invalidRequest => '服务器未接受这些设置，请核对币种代码及 IANA 时区。';

  @override
  String get notFoundError => '该账本不存在或已无法访问。';

  @override
  String get serviceUnavailable => '服务暂不可用，请稍后重试。';

  @override
  String get genericError => '操作失败，请重试。';

  @override
  String get invalidResponse => '服务器返回了无法识别的响应。';

  @override
  String get signoutError => '退出失败，已清除本地页面数据，请重试退出。';

  @override
  String get correlationLabel => '问题参考编号';

  @override
  String get initializationTitle => '个人空间设置';

  @override
  String get loginTitle => '登录 Ledger';

  @override
  String get invalidFieldsLabel => '请检查这些字段';

  @override
  String get welcomeTitle => '让每一笔，都清晰。';

  @override
  String get welcomeBody => '从一本属于你的账本开始，轻松整理收支与生活。';

  @override
  String get browserSignIn => '登录 / 注册';

  @override
  String get browserSignInHint => '在浏览器中安全登录，完成后自动返回。';

  @override
  String get browserSigningIn => '等待登录完成…';

  @override
  String get browserSignInError => '未能完成登录，请重试。';

  @override
  String get setupCurrencyTitle => '设置你的账本';

  @override
  String get setupCurrencyBody => '选择主币种，用熟悉的方式查看账本。';

  @override
  String get setupPreferencesTitle => '让账本更懂你';

  @override
  String get setupPreferencesBody => '选择语言和当地时区，之后可在设置中修改。';

  @override
  String get nextAction => '下一步';

  @override
  String get previousAction => '上一步';

  @override
  String get startLedgerAction => '开始记账';

  @override
  String get setupStepOne => '第 1 步，共 2 步';

  @override
  String get setupStepTwo => '第 2 步，共 2 步';

  @override
  String get searchOptions => '搜索';

  @override
  String get noOptionsFound => '没有匹配的选项';

  @override
  String get currencySummary => '账本主币种';

  @override
  String get catalogError => '无法加载选项，请重试。';

  @override
  String get preferencesTitle => '偏好设置';

  @override
  String get appInformationTitle => '应用信息';

  @override
  String get personalAccountLabel => '个人账户';

  @override
  String get defaultBadge => '默认';

  @override
  String get currentSelectionLabel => '当前选择';

  @override
  String get suggestedSelectionLabel => '推荐';

  @override
  String get supportDetailsLabel => '支持信息';

  @override
  String get refreshingLabel => '正在刷新…';

  @override
  String get savingPreferencesLabel => '正在保存偏好…';

  @override
  String get booksEmptyExplanation => '可用账本会显示在这里。';

  @override
  String get loadErrorTitle => '暂时无法加载内容';

  @override
  String get configurationTitle => '连接不可用';

  @override
  String get reviewTitle => '确认你的选择';

  @override
  String get sessionErrorTitle => '登录验证失败';

  @override
  String get requestErrorTitle => '暂时无法完成请求';

  @override
  String get accountsTab => '账户';

  @override
  String get transactionsTab => '流水';

  @override
  String get addTransaction => '记一笔';

  @override
  String get addAccount => '添加账户';

  @override
  String get editAccount => '编辑账户';

  @override
  String get accountName => '账户名称';

  @override
  String get accountKind => '账户类型';

  @override
  String get accountCash => '现金';

  @override
  String get accountBank => '银行账户';

  @override
  String get accountWallet => '电子钱包';

  @override
  String get accountOther => '其他资产';

  @override
  String get openingBalance => '期初余额';

  @override
  String get openingDate => '期初日期';

  @override
  String get openingType => '期初余额';

  @override
  String get incomeType => '收入';

  @override
  String get expenseType => '支出';

  @override
  String get transferType => '转账';

  @override
  String get refundType => '退款';

  @override
  String get transactionType => '流水类型';

  @override
  String get amountLabel => '金额';

  @override
  String get accountLabel => '账户';

  @override
  String get sourceAccount => '转出账户';

  @override
  String get destinationAccount => '转入账户';

  @override
  String get sourcePrincipal => '转出本金';

  @override
  String get destinationPrincipal => '转入本金';

  @override
  String get categoryLabel => '分类';

  @override
  String get categoriesTitle => '收支分类';

  @override
  String get counterpartyLabel => '交易对方';

  @override
  String get counterpartiesTitle => '交易对方';

  @override
  String get dateLabel => '日期';

  @override
  String get noteLabel => '备注';

  @override
  String get feeLabel => '手续费';

  @override
  String get addFee => '添加独立手续费';

  @override
  String get feeAccount => '手续费付款账户';

  @override
  String get feeAmount => '手续费金额';

  @override
  String get feeCategory => '手续费分类';

  @override
  String get saveEntry => '保存流水';

  @override
  String get saveChanges => '保存更改';

  @override
  String get saveAccount => '保存账户';

  @override
  String get editAction => '编辑';

  @override
  String get deleteTransaction => '删除流水';

  @override
  String get confirmAction => '确认';

  @override
  String get reviewTransaction => '核对流水';

  @override
  String get netAccountChanges => '含手续费的账户变动';

  @override
  String get feeSeparateHint => '手续费单独记为支出流水，本金不含手续费。';

  @override
  String get monthlySummary => '本月收支';

  @override
  String get recentTransactions => '最近流水';

  @override
  String get emptyAccountsTitle => '添加第一个账户';

  @override
  String get emptyAccountsBody => '创建账户并核对期初余额，即可开始记账。';

  @override
  String get emptyTransactionsTitle => '还没有流水';

  @override
  String get emptyTransactionsBody => '在当前账本记录收入、支出或转账。';

  @override
  String get emptySummary => '本期间暂无收支。';

  @override
  String get balanceLabel => '余额';

  @override
  String get archivedLabel => '已归档';

  @override
  String get archiveLabel => '归档';

  @override
  String get restoreLabel => '恢复';

  @override
  String get archiveHint => '归档后仍可查看历史记录。';

  @override
  String get transactionDetail => '流水详情';

  @override
  String get relatedTransactions => '关联流水';

  @override
  String get linkTransaction => '关联流水';

  @override
  String get relatedType => '普通关联';

  @override
  String get feeRelation => '手续费关联';

  @override
  String get refundRelation => '退款关联';

  @override
  String get removeLink => '解除关联';

  @override
  String get addRefund => '记录退款';

  @override
  String get refundRemaining => '剩余可退金额';

  @override
  String get historyTitle => '更正历史';

  @override
  String get voidedLabel => '已删除';

  @override
  String get revisionLabel => '修订版本';

  @override
  String get exchangeRateLabel => '实际成交汇率';

  @override
  String get includeFeesTitle => '同时处理关联手续费';

  @override
  String get includeFeesHint => '仅处理勾选的手续费，未勾选的手续费仍保留。';

  @override
  String get deleteHint => '删除会生成冲销记录并保留历史，请核对关联手续费。';

  @override
  String get filtersTitle => '筛选流水';

  @override
  String get applyFilters => '应用筛选';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get fromDate => '开始日期';

  @override
  String get toDate => '结束日期';

  @override
  String get allOption => '全部';

  @override
  String get noneOption => '无';

  @override
  String get loadMore => '加载更多';

  @override
  String get bookManagement => '账本管理';

  @override
  String get selectBook => '账本';

  @override
  String get addCategory => '添加分类';

  @override
  String get editCategory => '编辑分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get parentCategory => '上级分类';

  @override
  String get rootCategory => '一级分类';

  @override
  String get addCounterparty => '添加交易对方';

  @override
  String get editCounterparty => '编辑交易对方';

  @override
  String get counterpartyName => '交易对方名称';

  @override
  String get fieldRequired => '请填写此项。';

  @override
  String get invalidAmount => '请输入符合币种精度的有效金额。';

  @override
  String get invalidDate => '请输入有效的 YYYY-MM-DD 日期。';

  @override
  String get selectRequired => '请选择所需的账户和分类。';

  @override
  String get accountingConflict => '记录已变更，或操作与关联流水冲突。请刷新并核对后重试。';

  @override
  String get pendingWriteTitle => '保存结果尚未确认';

  @override
  String get pendingWriteBody => '请重试原请求确认保存结果，系统已保留原始内容和重试标识。';

  @override
  String get resolveWrite => '确认保存结果';

  @override
  String get noMatches => '没有匹配的流水';

  @override
  String get reloadDetail => '重新载入记录';

  @override
  String get includeDeleted => '包含已删除流水';

  @override
  String get sameAccountError => '请选择两个不同账户。';

  @override
  String get categoryArchiveHint => '归档一级分类时，其子分类也会归档。';

  @override
  String get feeSelectExisting => '关联已有支出为手续费';

  @override
  String get chooseTransaction => '选择流水';

  @override
  String get unselectedFeesRemain => '未勾选的手续费保持不变。';

  @override
  String get viewAllTransactions => '查看流水';

  @override
  String get byCategoryTitle => '分类汇总';

  @override
  String get currentBookLabel => '当前账本';

  @override
  String get principalLabel => '本金';

  @override
  String get resultSaved => '已保存';

  @override
  String get returnToEntry => '返回填写';

  @override
  String get reversalLabel => '冲销';

  @override
  String get postingLabel => '入账';
}
