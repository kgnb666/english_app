// l10n/zh_CN.dart - 简体中文本地化文案
// 所有面向用户的 UI 文案集中管理于此

class AppStrings {
  static const String appName = "英语教练";
  static const String appSubtitle = "你的 AI 英语学习助手";

  // 底部导航
  static const String tabHome = "首页";
  static const String tabChat = "对话";
  static const String tabWords = "单词";
  static const String tabRead = "阅读";
  static const String tabWrite = "写作";
  static const String tabProfile = "我的";

  // 登录注册
  static const String login = "登录";
  static const String register = "注册";
  static const String username = "用户名";
  static const String password = "密码";
  static const String email = "邮箱";
  static const String confirmPassword = "确认密码";
  static const String passwordHint = "至少6个字符";
  static const String noAccount = "还没有账号？去注册";
  static const String hasAccount = "已有账号？去登录";
  static const String createAccount = "创建账号";
  static const String passwordsMismatch = "两次密码不一致";
  static const String loginFailed = "登录失败";
  static const String registerFailed = "注册失败";

  // 首页
  static const String todayProgress = "今日进度";
  static const String learningStats = "学习统计";
  static const String todayTasks = "今日任务";
  static const String dayStreak = "连续天数";
  static const String wordsMastered = "已掌握";
  static const String totalTime = "累计时长";
  static const String yourLevel = "当前等级";
  static const String speakingLabel = "口语";
  static const String wordsLabel = "单词";
  static const String reviewsLabel = "复习";
  static const String chatsLabel = "对话";
  static const String taskSpeaking = "AI 口语练习";
  static const String taskSpeakingSub = "练习 10 分钟对话";
  static const String taskWords = "学习新单词";
  static const String taskWordsSub = "个单词待复习";
  static const String taskReading = "阅读一篇文章";
  static const String taskReadingSub = "使用 AI 阅读助手";
  static String taskWordsDynamic(int target) => "背 $target 个单词";
  static String taskAiDynamic(int target) => "AI 口语 $target 分钟";
  static String taskReadingDynamic(int target) => "阅读 $target 篇文章";
  static String taskWritingDynamic(int target) => "作文 $target 篇";
  static String taskProgress(int done, int target) => "$done / $target";

  // AI 对话
  static const String aiTeacher = "AI 英语老师";
  static const String newChat = "新建对话";
  static const String noConversations = "暂无对话";
  static const String startChat = "和 AI 英语老师开始对话吧";
  static const String loadingTopics = "正在加载推荐话题...";
  static const String typeMessage = "输入消息...";
  static const String typeOrSpeak = "输入或语音...";
  static const String listening = "正在听...";
  static const String startConversation = "开始对话";
  static const String aiTeacherReady = "AI 英语老师已就绪，输入或语音开始练习";
  static const String messages = "条消息";
  static const String justNow = "刚刚";
  static const String minAgo = "分钟前";
  static const String hourAgo = "小时前";
  static const String correction = "纠错";
  static const String retry = "重试";
  static const String sendFailed = "发送失败，请重试";
  static const String aiUnavailable = "AI 老师暂时开小差了，点击重试";
  static const String createSessionFailed = "新建会话失败，请重试";
  static const String expand = "展开全文";
  static const String collapse = "收起";
  static const String sessionSummary = "会话总结";
  static const String summaryLoading = "AI 正在总结本次对话...";
  static const String summaryFailed = "总结失败，请重试";
  static const String summaryKeyPoints = "学习要点";
  static const String summaryToImprove = "下次改进";
  static const String operationFailed = "操作失败，请重试";
  static const String aiGeneratingSlow = "AI 生成较慢，请稍候...";
  static const String searchNoResult = "未找到相关单词";
  static String searchResultCount(int n) => "共 $n 个结果";
  static const String startListening = "开始语音输入";
  static const String stopListening = "停止录音";
  static const String speechNoResult = "未识别到语音，请靠近麦克风再试一次";
  static const String speechFailed = "语音识别失败，请重试";
  static const String enableMicrophonePermission = "请开启麦克风权限后再使用语音功能";
  static const String cetTitle = "四六级专项训练";
  static const String cetSetGoal = "设置考试目标";
  static const String cetCancelGoal = "取消目标";
  static const String cetCancelHint = "取消后将恢复默认学习计划，确定取消吗？";
  static const String cetTargetScore = "目标分数";
  static const String cetScoreInvalid = "分数需在 425-710 之间";
  static const String cetDailyMinutes = "每日学习时间";
  static const String cetMinutesInvalid = "每日时间需在 10-240 分钟之间";
  static const String cetExamDate = "考试日期";
  static const String cetDaysLeftLabel = "剩余天数";
  static const String cetProgress = "学习进度";
  static const String cetPlan = "阶段计划";
  static const String cetTodayTasks = "今日任务";
  static const String cetNoGoal = "还没有四六级目标";
  static const String cetNoGoalHint = "设置考试目标后，AI 会为你生成词汇、阅读、听力、作文四阶段备考计划";
  static String cetPhaseProgress(int done, int total) => "已完成 $done / $total 阶段";
  static String cetDayProgress(int elapsed, int total) => "备考进度 $elapsed / $total 天";
  static const String cetHomeHint = "四六级备考计划与每日任务";
  static const String cetVocabularyTitle = "四六级词汇";
  static const String cetVocabularyEntry = "词汇学习";
  static const String cetVocabularyHint = "核心词 / 高频词 / 熟词僻义 / 易错词，附真题例句";
  static const String cetRealExamples = "真题例句";
  static const String cetReadingTitle = "四六级阅读";
  static const String cetReadingEntry = "阅读训练";
  static const String cetReadingHint = "真题风格阅读 + AI 逐题解析，生词一键收藏";
  static const String cetReadingQuestions = "道题";
  static const String cetReadingSubmit = "提交答案";
  static const String cetReadingAnswerAll = "请完成全部题目";
  static const String cetReadingAccuracy = "正确率";
  static const String cetReadingAnalysis = "AI 解析";
  static const String cetReadingYourAnswer = "你的答案";
  static const String cetReadingCorrectReason = "正确答案原因";
  static const String cetReadingTrap = "选项陷阱";
  static const String cetReadingSentences = "长难句分析";
  static const String cetReadingVocab = "生词提取";
  static const String cetReadingRetry = "再练一次";
  static const String cetWritingTitle = "四六级写作";
  static const String cetWritingEntry = "写作训练";
  static const String cetWritingHint = "AI 按四六级标准批改，满分 15 分，附个人模板库";
  static const String cetWritingEssay = "你的作文";
  static const String cetWritingReview = "AI 批改";
  static const String cetWritingScore = "满分 15 分";
  static const String cetWritingStructure = "结构";
  static const String cetWritingVocabulary = "词汇";
  static const String cetWritingGrammar = "语法";
  static const String cetWritingLogic = "逻辑";
  static const String cetWritingErrors = "错误修改";
  static const String cetWritingSuggestions = "改进建议";
  static const String cetWritingOptimized = "优化版本";
  static const String cetWritingTemplates = "我的模板库";
  static const String cetWritingSaveTemplate = "保存为模板";
  static const String cetTemplateTitle = "模板标题";
  static const String cetTemplateAi = "AI 推荐模板";
  static const String cetTemplateRecommended = "AI 模板已生成";
  static const String cetTemplateUse = "使用此模板";
  static const String cetTemplatesEmpty = "还没有模板，可保存自己的作文或让 AI 推荐";
  static const String cetTranslationTitle = "四六级翻译";
  static const String cetTranslationEntry = "翻译训练";
  static const String cetTranslationHint = "汉译英 + AI 词汇/语序/自然度评分";
  static const String cetTranslationInput = "你的翻译";
  static const String cetTranslationSubmit = "提交评分";
  static const String cetTranslationHistory = "翻译记录";
  static const String cetTranslationVocab = "词汇";
  static const String cetTranslationOrder = "语序";
  static const String cetTranslationNatural = "自然度";
  static const String cetTranslationReference = "参考译文";
  static const String loggingIn = "正在登录...";
  static const String registering = "正在注册...";
  static const String cetTranslationScoring = "正在评分...";
  static const String cetTranslationDone = "评分完成";
  static const String cetReadingScoring = "正在判分...";
  static const String cetReadingSubmitted = "提交成功";
  static const String cetWritingScoring = "正在批改...";
  static const String cetWritingDone = "批改完成";
  static const String learningStarted = "开始学习";
  static const String reviewRecorded = "已记录";
  static const String memoryAidGenerated = "记忆方法已生成";
  static const String cetListeningTitle = "四六级听力";
  static const String cetListeningEntry = "听力训练";
  static const String cetListeningHint = "精听模式 + AI 逐句解析与生词解释";
  static const String cetListeningPlay = "播放听力音频";
  static const String cetListeningPlaying = "停止播放";
  static const String cetListeningSubmit = "提交答案";
  static const String cetListeningDone = "听力完成";
  static const String cetListeningHistory = "听力记录";
  static const String cetListeningSentenceAnalysis = "逐句解析";
  static const String cetListeningVocab = "生词解释";
  static const String cetSpeakingTitle = "AI 口语模拟";
  static const String cetSpeakingEntry = "口语模拟";
  static const String cetSpeakingHint = "AI 提问 + 语音作答，四维评分";
  static const String cetSpeakingQuestion = "口语问题";
  static const String cetSpeakingRecord = "开始录音作答";
  static const String cetSpeakingYourAnswer = "你的回答（语音转写）";
  static const String cetSpeakingSubmit = "提交评分";
  static const String cetSpeakingScoring = "正在评分...";
  static const String cetSpeakingDone = "评分完成";
  static const String cetSpeakingHistory = "口语记录";
  static const String cetSpeakingFluency = "流利度";
  static const String cetSpeakingGrammar = "语法";
  static const String cetSpeakingVocabulary = "词汇";
  static const String cetSpeakingPronunciation = "发音";
  static const String aiTips = "提升建议";
  static const String cetTranslationScore = "满分 10 分";
  static const String cetTranslationAnalysis = "翻译解析";
  static const String cetListeningSentences = "句子解析";
  static const String cetSpeakingScore = "口语评分";
  static const String cetCoachTitle = "AI 私人教练";
  static const String cetCoachEntry = "AI 私人教练";
  static const String cetCoachHint = "AI 根据你的弱项与成绩，每天主动给出学习建议";
  static const String cetCoachToday = "今日学习建议";
  static const String cetCoachProfile = "我的学习画像";
  static const String cetCoachWeak = "薄弱模块";
  static const String cetCoachErrors = "常犯错误";
  static const String cetCoachHistory = "各模块成绩";
  static const String cetCoachVocab = "词汇掌握";

  // 单词
  static const String vocabulary = "单词学习";
  static const String allWords = "全部";
  static const String newWords = "新词";
  static const String learning = "学习中";
  static const String toReview = "待复习";
  static const String mastered = "已掌握";
  static const String wordNotfound = "未找到单词";
  static const String startLearning = "开始学习";
  static const String gotIt = "记住了";
  static const String again = "再练一次";
  static const String aiMemoryAid = "AI 记忆方法";
  static const String exampleSentences = "例句";
  static const String reviewCount = "复习次数";
  static const String status = "状态";
  static const String nextReview = "下次复习";
  static const String noWords = "暂无单词";
  static const String browseAll = "前往(全部)查看完整词库";
  static const String loadWords = "加载词库";
  static const String loadingWords = "加载词库中...";
  static const String todayReview = "今日待复习";
  static const String memoryAid = "记忆方法";
  static const String searchWords = "搜索单词...";
  static const String searchWordsCn = "搜索单词或中文释义...";
  static const String quizTitle = "单词测验";

  // 阅读
  static const String readingAssistant = "阅读助手";
  static const String pasteArticle = "在此粘贴英文文章...";
  static const String article = "文章";
  static const String analyzeAI = "AI 分析";
  static const String analyzing = "分析中...";
  static const String summary = "摘要";
  static const String mainIdea = "中心思想";
  static const String keyVocabulary = "重点词汇";
  static const String complexSentences = "长难句分析";
  static const String analysisFailed = "分析失败，请重试";
  static const String articleTooShort = "请输入至少 10 个字符";
  static const String readingHistory = "阅读历史";
  static const String readingHistoryDetail = "阅读历史详情";
  static const String originalArticle = "原文";
  static const String noReadingHistory = "暂无阅读历史";
  static const String noReadingHistoryHint = "去阅读助手分析一篇文章，记录会保存在这里";
  static const String backToReading = "去阅读分析";
  static const String noSummary = "（无摘要）";
  static const String loadHistoryFailed = "加载历史失败";
  static const String loadFailed = "加载失败";
  static const String confirmDelete = "确认删除？";
  static const String confirmDeleteHint = "删除后不可恢复，确定删除这条记录吗？";
  static const String deleted = "已删除";
  static const String deleteFailed = "删除失败";

  // 作文
  static const String essayReview = "作文批改";
  static const String pasteEssay = "在此粘贴英文作文...";
  static const String yourEssay = "你的作文";
  static const String aiReview = "AI 批改";
  static const String reviewing = "批改中...";
  static const String overallScore = "综合评分";
  static const String suggestions = "修改建议";
  static const String grammarErrors = "语法错误";
  static const String optimizedVersion = "优化版本";
  static const String reviewFailed = "批改失败，请重试";
  static const String writingHistory = "作文历史";
  static const String writingHistoryDetail = "作文批改详情";
  static const String originalEssay = "原作文";
  static const String noWritingHistory = "暂无作文历史";
  static const String noWritingHistoryHint = "去作文批改提交一篇作文，记录会保存在这里";
  static const String backToWriting = "去作文批改";

  // 学习统计
  static const String statsTitle = "学习统计";
  static const String weeklyTime = "本周学习时长";
  static const String weeklyWords = "本周学习单词";
  static const String wordsTrend = "单词学习趋势";
  static const String dailyMinutes = "分钟";
  static const String aiTime = "AI 学习";
  static const String readingCount = "阅读次数";
  static const String writingCount = "作文次数";
  static const String monthlyStats = "月度统计";
  static const String calendarTitle = "学习日历";
  static const String monthTotal = "当月合计";
  static const String studiedDays = "学习天数";
  static const String noStudyThisMonth = "本月还没有学习记录，去学起来吧";
  static const String noStatsData = "暂无学习数据";
  static const String noStatsHint = "开始学习后，这里会展示你的学习趋势";
  static const String goStudy = "去学习";

  // 学习计划
  static const String planTitle = "学习计划";
  static const String planHint = "每日任务会自动生成，并按真实学习进度跟踪完成情况";
  static const String planWords = "背单词";
  static const String planAi = "AI 口语";
  static const String planReading = "阅读";
  static const String planWriting = "作文";
  static const String planTarget = "每日目标";
  static const String planUnitWords = "个";
  static const String planUnitMinutes = "分钟";
  static const String planUnitReading = "篇";
  static const String planUnitWriting = "篇";
  static const String planSaved = "学习计划已保存";
  static const String planSaveFailed = "保存失败，请重试";

  // 学习画像
  static const String learningProfile = "学习画像";
  static const String profileBasic = "基本信息";
  static const String profileGoal = "学习目标";
  static const String profileGoalHint = "例如：通过大学英语四级考试";
  static const String profileVocabulary = "预估词汇量";
  static const String profileWeakSkills = "薄弱技能";
  static const String profileWeakSkillsHint = "选择你认为需要加强的技能（AI 会自动加入你的常犯错误）";
  static const String profilePreferences = "学习偏好";
  static const String profileFocusHint = "选择你最想提升的方向";
  static const String profileTopics = "感兴趣的话题";
  static const String profileTopicsHint = "多个话题用逗号分隔，如：科技，旅行";
  static const String profileErrors = "常犯错误";
  static const String profileErrorsHint = "AI 纠错自动记录";
  static const String profileNoErrors = "暂无错误记录，多和 AI 对话会自动收集";
  static const String profileSaved = "学习画像已保存";
  static const String profileSaveFailed = "保存失败，请重试";
  static const String moreNatural = "更地道表达";
  static const String bookmark = "收藏";
  static const String unbookmark = "取消收藏";
  static const String bookmarkWord = "收藏生词";
  static const String bookmarkWordHint = "输入英文单词，加入生词本";
  static const String addedToWordBook = "已加入生词本";
  static const String addToWordBookFailed = "收藏失败，请重试";
  static const String bookmarkFromReading = "收藏到生词本";
  static const String inWordBook = "已在生词本";
  static const String wordBook = "生词本";
  static const String learnedCount = "学习数量";
  static const String masteredCount = "掌握数量";
  static const String reviewCountLabel = "复习次数";
  static const String errorCountLabel = "错误次数";
  static const String noBookmarks = "生词本还是空的，阅读或聊天时收藏的单词会出现在这里";

  // 发音练习
  static const String pronunciationTitle = "发音练习";
  static const String pronunciationPractice = "跟着朗读，训练发音";
  static const String pronunciationCustomHint = "或输入想练习的句子";
  static const String pronunciationListen = "播放标准发音";
  static const String pronunciationRecord = "开始录音";
  static const String pronunciationSttInit = "正在初始化语音识别...";
  static const String pronunciationYouSaid = "你说的是";
  static const String pronunciationResult = "发音评测";
  static const String pronunciationScore = "评分";
  static const String pronunciationWrongWords = "错误单词";
  static const String pronunciationGreat = "发音很标准，继续保持！";
  static const String pronunciationSuggestions = "改进建议";
  static const String pronunciationAdvice = "整体建议";
  static const String pronunciationListenAgain = "再听一遍标准发音";
  static const String pronunciationHistory = "练习记录";
  static const String pronunciationNoHistory = "还没有练习记录，开始第一次发音训练吧";
  static const String pronunciationNoSpeech = "没有识别到语音，请靠近麦克风再试一次";
  static const String pronunciationFailed = "评测失败，请重试";
  static const String pronunciationHomeHint = "跟读句子，AI 评测你的发音";

  // 单词测验
  static const String quizModeTitle = "选择测验模式";
  static const String quizChoice = "选择题";
  static const String quizChoiceSub = "看英文单词，选正确释义";
  static const String quizSpelling = "拼写题";
  static const String quizSpellingSub = "看中文释义，拼写英文单词";
  static const String quizListening = "听音辨义";
  static const String quizListeningSub = "听发音，选正确释义";
  static const String quizHistory = "测验记录";
  static const String noQuizHistory = "暂无测验记录，选一个模式开始吧";
  static const String quizGenerateFailed = "生成题目失败，请重试";
  static const String quizSubmitFailed = "提交测验失败，请重试";
  static const String quizSubmitting = "提交中...";
  static const String noQuestions = "没有可用的题目";
  static const String quizScore = "当前分数";
  static const String quizQuestion = "第";
  static const String quizCorrect = "回答正确！";
  static const String quizWrong = "回答错误";
  static const String quizCorrectAnswer = "正确答案";
  static const String quizYourAnswer = "你的答案";
  static const String quizInputWord = "输入英文单词";
  static const String quizInputWordHint = "请输入单词拼写";
  static const String quizConfirm = "确认答案";
  static const String quizReplay = "重新播放";
  static const String quizChoiceHint = "选择正确的中文释义";
  static const String quizListeningHint = "点击播放按钮听发音，选择正确释义";
  static const String quizSpellingPrompt = "根据释义拼写英文单词：";
  static const String quizResultTitle = "测验结果";
  static const String quizAccuracy = "正确率";
  static const String quizCorrectCount = "答对";
  static const String quizWrongCount = "答错";
  static const String quizWrongList = "错题记录";
  static const String quizAllCorrect = "全部答对，太棒了！";
  static const String quizRetry = "再测一次";
  static const String backToWords = "返回词库";

  // 我的
  static const String profile = "个人中心";
  static const String darkMode = "深色模式";
  static const String englishLevel = "英语等级";
  static const String dailyGoals = "每日目标";
  static const String minutesPerDay = "每日学习分钟";
  static const String wordsPerDay = "每日单词量";
  static const String selectLevel = "选择等级";
  static const String learningSummary = "学习总览";
  static const String total = "累计";
  static const String logout = "退出登录";
  static const String confirmLogout = "确定退出登录吗？";
  static const String save = "保存";
  static const String cancel = "取消";
  static const String back = "返回";

  // 修改密码
  static const String changePassword = "修改密码";
  static const String oldPassword = "旧密码";
  static const String newPassword = "新密码";
  static const String passwordRequired = "请填写完整密码";
  static const String passwordTooShort = "新密码至少 6 个字符";
  static const String changePasswordSuccess = "密码修改成功";
  static const String changePasswordFailed = "密码修改失败";

  // 统一错误提示
  static const String sessionExpired = "登录已过期，请重新登录";
  static const String permissionDenied = "没有权限执行此操作";
  static const String serverError = "服务器开小差了，请稍后重试";
  static const String networkError = "无法连接服务器，请检查网络";
  static const String requestTimeout = "请求超时，请检查网络后重试";

  // 学习提醒
  static const String reminderSettings = "学习提醒";
  static const String enableReminder = "开启每日提醒";
  static const String enableReminderSub = "每天定时提醒你完成英语学习任务";
  static const String reminderTime = "提醒时间";
  static const String reminderScheduled = "提醒已开启";
  static const String reminderCancelled = "提醒已关闭";
  static const String reminderFailed = "提醒设置失败";
  static const String reminderTip = "提醒为本地通知，修改后立即生效；手机关机或重启后会在首次启动时自动恢复。";
  static const String nextReminder = "下次提醒";
  static const String dailyReminderText = "今天还有英语学习任务，快来打卡吧！";
  static const String notificationPermissionDenied = "通知权限被拒绝，请在系统设置中开启通知权限";

  // 数据备份
  static const String dataBackup = "数据备份";
  static const String backupIncludes = "备份内容";
  static const String backupIncludesDetail = "包含单词记录、聊天记录、阅读记录、作文记录和每日学习统计";
  static const String exportData = "导出学习数据";
  static const String exporting = "导出中...";
  static const String exportSuccess = "导出成功，文件已保存到本机";
  static const String exportFailed = "导出失败";
  static const String exportStatus = "导出状态";
  static const String filesLabel = "个文件";
  static const String noBackupFiles = "暂无备份文件，点击上方按钮导出";
  static const String noExportYet = "尚未导出数据";
  static const String confirmRestore = "确认恢复数据？";
  static const String confirmRestoreHint = "恢复会用备份文件覆盖当前账号的单词进度与每日统计，聊天/阅读/作文记录会追加导入。确定继续吗？";
  static const String restoreFailed = "恢复失败";
  static const String backupTip = "备份文件保存在应用文档目录 backups/ 下，可点击文件恢复数据。";

  // 服务器设置
  static const String serverSettings = "服务器设置";
  static const String serverSettingsHint = "修改 API 服务器地址，App 会持久化保存并立即生效";
  static const String currentEnv = "当前环境";
  static const String apiAddress = "API 地址";
  static const String testConnection = "测试连接";
  static const String serverSaved = "已保存并生效";
  static const String serverConnected = "连接成功";
  static const String serverFailed = "连接失败";
  static const String resetToDefault = "恢复默认";
  static const String usingDefault = "已恢复为环境默认地址";
  static const String configDocs = "配置说明";
  static const String configDocsBody = "1. 默认地址读取 assets/config/app_config.json；\n"
      "2. 编译期指定环境：flutter run --dart-define=API_ENV=test；\n"
      "3. 编译期直接覆盖地址：flutter run --dart-define=API_BASE_URL=http://host:port/api/v1；\n"
      "4. 本页修改的地址优先级最高（保存在本机）。";

  // 通用
  static const String loading = "加载中...";
  static const String error = "出错了";
  static const String noData = "暂无内容";
  static const String refresh = "刷新";
  static const String delete = "删除";
  static const String confirm = "确认";
  static const String retryHint = "网络可能开小差了，请检查后重试";

  // 等级
  static const String levelBeginner = "入门";
  static const String levelElementary = "初级";
  static const String levelIntermediate = "中级";
  static const String levelUpperIntermediate = "中高级";
  static const String levelAdvanced = "高级";

  static String levelLabel(String key) {
    switch (key) {
      case "beginner": return levelBeginner;
      case "elementary": return levelElementary;
      case "intermediate": return levelIntermediate;
      case "upper_intermediate": return levelUpperIntermediate;
      case "advanced": return levelAdvanced;
      default: return key;
    }
  }

  static String wordStatusLabel(String key) {
    switch (key) {
      case "new": return newWords;
      case "learning": return learning;
      case "review": return toReview;
      case "mastered": return mastered;
      default: return key;
    }
  }
}
