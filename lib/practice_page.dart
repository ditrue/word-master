import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:math';

/// 单词意思组，包含词性和翻译
class Meaning {
  Meaning({required this.partOfSpeech, required this.translation});

  final String partOfSpeech; // 词性，如 'n.', 'v.', 'adj.'
  final List<String> translation; // 中文释义数组，每个元素是一个可拖拽的选项
}

class PracticeQuestion {
  PracticeQuestion({
    required this.word,
    required this.meanings,
    List<int>? hiddenIndices,
    List<String>? options,
    this.syllableBreakpoints,
  }) : hiddenIndices = hiddenIndices ?? _generateDefaultHiddenIndices(word),
       options = options ?? List<String>.of(word.split(''), growable: false);

  // 生成默认的隐藏索引：隐藏所有字母
  static List<int> _generateDefaultHiddenIndices(String word) {
    // 隐藏所有字母，让用户完全通过拖拽来填补
    return List<int>.generate(word.length, (int index) => index);
  }

  final String word; // 完整单词，如 dictionary
  final List<Meaning> meanings; // 意思组数组，每个组包含词性和翻译
  final List<int> hiddenIndices; // 需要被遮挡的字母索引（升序）
  final List<String> options; // 候选字母
  final List<int>? syllableBreakpoints; // 音节切分点（索引位置，在索引后切分）

  // 为了向后兼容，提供单个意思的快捷访问器
  String? get partOfSpeech =>
      meanings.isNotEmpty ? meanings.first.partOfSpeech : null;
  String get translation =>
      meanings.isNotEmpty && meanings.first.translation.isNotEmpty
      ? meanings.first.translation.first
      : '';

  List<String> get answerLetters {
    return hiddenIndices.map((int i) => word[i]).toList(growable: false);
  }

  /// 获取音节拆分后的单词，使用连字符分隔
  String getSyllableString() {
    if (syllableBreakpoints == null || syllableBreakpoints!.isEmpty) {
      return word;
    }
    final List<int> breakpoints = List<int>.from(syllableBreakpoints!)..sort();
    final StringBuffer sb = StringBuffer();
    int start = 0;
    for (int bp in breakpoints) {
      if (bp > start && bp <= word.length) {
        sb.write(word.substring(start, bp));
        sb.write('·');
        start = bp;
      }
    }
    if (start < word.length) {
      sb.write(word.substring(start));
    }
    return sb.toString();
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

enum _AnswerState { none, correct, incorrect, success }

enum _PracticeStage { spelling, translation, completed }

class _DragLetterPayload {
  _DragLetterPayload({required this.optionIndex, required this.letter});

  final int optionIndex;
  final String letter;
}

class _PracticePageState extends State<PracticePage>
    with SingleTickerProviderStateMixin {
  static const List<Color> _optionColorPalette = <Color>[
    Color(0xFF4C6EF5),
    Color(0xFF4263EB),
    Color(0xFF7950F2),
    Color(0xFF339AF0),
    Color(0xFF38D9A9),
    Color(0xFF12B886),
    Color(0xFFFF922B),
    Color(0xFFFF6B6B),
    Color(0xFFFA5252),
  ];
  // 简单内置两道题以演示
  final List<PracticeQuestion> questions = <PracticeQuestion>[
    PracticeQuestion(
      word: 'dict',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['字典', '词典', '辞典']),
        Meaning(partOfSpeech: 'v.', translation: <String>['字典1', '词典2', '辞典3']),
      ],
      syllableBreakpoints: <int>[2],
    ),
    PracticeQuestion(
      word: 'apple',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['苹果']),
      ],
      syllableBreakpoints: <int>[2],
    ),
    PracticeQuestion(
      word: 'soup',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['汤']),
      ],
      syllableBreakpoints: <int>[2],
    ),
    PracticeQuestion(
      word: 'beautiful',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'adj.', translation: <String>['美丽', '的']),
      ],
      syllableBreakpoints: <int>[3, 6],
    ),
    PracticeQuestion(
      word: 'computer',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['电脑']),
      ],
      syllableBreakpoints: <int>[2, 5],
    ),
    PracticeQuestion(
      word: 'running',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'v.', translation: <String>['跑步']),
      ],
      syllableBreakpoints: <int>[2],
    ),
    PracticeQuestion(
      word: 'elephant',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['大象']),
      ],
      syllableBreakpoints: <int>[2, 4],
    ),
  ];

  int currentIndex = 0;
  final List<String> selectedLetters = <String>[]; // 已填入的字母（与隐藏位次序对应）
  final List<int> usedOptionIndices = <int>[]; // 已使用的候选下标（用于禁用按钮）
  _AnswerState answerState = _AnswerState.none;
  List<String> activeOptions = <String>[]; // 当前阶段的候选选项
  List<int> activeOptionIndices = <int>[]; // 候选选项对应原始答案列表的索引
  final Random _rnd = Random();
  bool isDropLocked = false; // 防止错误动画期间继续拖拽
  _PracticeStage _stage = _PracticeStage.spelling;
  final List<String> _translationTokens = <String>[];
  final List<String> _selectedMeaningTokens = <String>[];
  final List<int> _translationUsedOptionIndices = <int>[];
  _PracticeStage? _lastOptionsStage;
  bool _isInitialized = false; // 添加初始化标志
  int _currentMeaningIndex = 0; // 当前正在练习的含义索引（如果有多个含义，分成多次练习）
  final List<Meaning> _completedMeanings = <Meaning>[]; // 已完成的词意组列表
  bool _isWaitingBetweenMeanings = false; // 是否正在等待期间（完成一组后等待3秒）
  bool _showColoredWordGroup = false; // 控制拼写完成后中间显示彩色单词
  bool _showZipperOverlay = false; // 拼写完成后是否显示拉链特效
  double _zipProgress = 0.0; // 拉链开启进度 0-1
  bool _zipSkipArmed = false; // 是否触发上拉跳过下一词
  double _zipDragOffset = 0.0; // 临时的手柄拖拽偏移（用于在 progress == 0 时上拉）
  bool _zipShouldComplete = false; // 在拖拽过程中达到阈值，但等待手势结束再完成
  double? _lastZipperHalfHeight;
  AnimationController? _middleWordController;
  Animation<Offset>? _middleWordOffset;

  // 为翻译阶段创建占位符字符串，每个意思组用一个占位符表示
  String _buildTranslationPlaceholder(List<String> tokens) {
    if (tokens.isEmpty) return '';
    // 使用不同的占位符来区分不同token
    final List<String> placeholders = <String>[];
    for (int i = 0; i < tokens.length; i++) {
      placeholders.add('■'); // 使用方块作为占位符
    }
    return placeholders.join();
  }

  void _initializeTranslationStage() {
    _translationTokens.clear();
    // 每次只练习一组：一个词性和对应的翻译选项
    if (_currentMeaningIndex < current.meanings.length) {
      final Meaning meaning = current.meanings[_currentMeaningIndex];
      // 词性作为一个单独的项
      _translationTokens.add(meaning.partOfSpeech);
      // 将所有翻译选项作为可拖拽项
      _translationTokens.addAll(meaning.translation);
    }
    _selectedMeaningTokens.clear();
    _translationUsedOptionIndices.clear();
    _lastOptionsStage = null;
  }

  List<String> get _currentSelectedItems => _stage == _PracticeStage.spelling
      ? selectedLetters
      : _selectedMeaningTokens;

  List<int> get _currentUsedIndices =>
      _stage == _PracticeStage.spelling ? usedOptionIndices : const <int>[];

  List<String> get _currentExpectedItems => _stage == _PracticeStage.spelling
      ? current.answerLetters
      : _translationTokens;

  bool get _isTranslationStage => _stage == _PracticeStage.translation;

  Timer? _autoAdvanceTimer;
  final ValueNotifier<bool> _isSnapping = ValueNotifier<bool>(false);
  final ValueNotifier<double> _snapProgress = ValueNotifier<double>(0.0);
  List<double> _optionWeightsFull =
      <double>[]; // randomized weights for size variation
  List<Color> _optionColorsFull = <Color>[];
  double _optionRowTopPadding = 12.0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nextBlankKey = GlobalKey();
  bool _hasScrolledToBlank = false; // 标记是否已滚动到第一个空格（用于防止频繁触发）
  final Set<int> _tempWrongSlots = <int>{};

  PracticeQuestion get current => questions[currentIndex];

  @override
  void initState() {
    super.initState();
    _middleWordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _middleWordOffset =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.35)).animate(
          CurvedAnimation(
            parent: _middleWordController!,
            curve: Curves.easeInOut,
          ),
        );
    // 延迟初始化，确保在首帧渲染后再初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _stage = _PracticeStage.spelling;
          _initializeTranslationStage();
          _isInitialized = true;
        });
        _prepareOptions();
      }
    });

    _middleWordController?.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showColoredWordGroup = false;
          });
        }
        _middleWordController?.reset();
      }
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _scrollController.dispose();
    _middleWordController?.dispose();
    super.dispose();
  }

  void _prepareOptions() {
    final List<String> answersList = _stage == _PracticeStage.spelling
        ? current.answerLetters
        : _translationTokens;
    final List<String> selectedList = _stage == _PracticeStage.spelling
        ? selectedLetters
        : _selectedMeaningTokens;

    final int totalCount = answersList.length;
    final int filledCount = selectedList.length.clamp(0, totalCount);

    if (_lastOptionsStage != _stage) {
      _optionColorsFull.clear();
      _optionWeightsFull.clear();
      _lastOptionsStage = _stage;
    }

    final bool shouldResetLayout =
        _optionColorsFull.length != totalCount || filledCount == 0;

    if (shouldResetLayout) {
      _optionRowTopPadding = totalCount == 0 ? 0 : 6 + _rnd.nextDouble() * 14;
      _optionWeightsFull = List<double>.generate(totalCount, (_) {
        final double baseRatio = 1.0; // 基准比例
        // 根据选择项数量调整随机范围，超过4个时增大差异
        final double randomizationRange = totalCount > 4 ? 0.8 : 0.5;
        final double randomization =
            _rnd.nextDouble() * randomizationRange * 2 - randomizationRange;
        final double minRatio = totalCount > 4 ? 0.2 : 0.3; // 超过4个时允许更小的尺寸
        final double maxRatio = totalCount > 4 ? 2.5 : 2.2; // 超过4个时允许更大的尺寸
        final double variedRatio = baseRatio + randomization;
        return variedRatio.clamp(minRatio, maxRatio);
      });
      // Generate non-repeating colors for options
      if (totalCount <= _optionColorPalette.length) {
        final List<Color> shuffled = List<Color>.from(_optionColorPalette)
          ..shuffle(_rnd);
        _optionColorsFull = shuffled.take(totalCount).toList(growable: true);
      } else {
        // If more items than palette, generate distinct HSL colors evenly spaced
        _optionColorsFull = List<Color>.generate(totalCount, (int i) {
          final double hue = (360.0 * i / totalCount) % 360.0;
          final HSLColor hsl = HSLColor.fromAHSL(1.0, hue, 0.65, 0.55);
          return hsl.toColor();
        }, growable: true);
      }
    }

    // 对于翻译阶段，只显示尚未使用的选项（词性 + 翻译项）
    // 对于拼写阶段，只显示剩余的答案
    final List<String> remainingAnswers;
    final List<int> remainingIndices;
    if (_stage == _PracticeStage.translation) {
      remainingAnswers = <String>[];
      remainingIndices = <int>[];
      for (int i = 0; i < answersList.length; i += 1) {
        if (_translationUsedOptionIndices.contains(i)) continue;
        remainingAnswers.add(answersList[i]);
        remainingIndices.add(i);
      }
    } else {
      remainingAnswers = answersList.sublist(filledCount);
      remainingIndices = List<int>.generate(
        remainingAnswers.length,
        (int index) => filledCount + index,
      );
    }

    setState(() {
      activeOptions = remainingAnswers;
      activeOptionIndices = remainingIndices;
      if (_stage == _PracticeStage.spelling) {
        usedOptionIndices.clear();
      }
      // 翻译阶段不清空 _translationUsedOptionIndices，以保持已选中项的标记
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('PracticePage build called');

    // 如果还未初始化，显示加载状态
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '${currentIndex + 1}/${questions.length}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final int totalHiddenCount = current.hiddenIndices.length;
    final double fillProgress = totalHiddenCount == 0
        ? 1.0
        : min(1.0, max(0.0, selectedLetters.length / totalHiddenCount));
    final double autoTranslationOpacity = min(
      1.0,
      max(0.0, 1 - pow(fillProgress, 1.4).toDouble()),
    );
    // 成功后译义始终可见（由刮刮乐灰层遮挡）
    final double translationOpacity = answerState == _AnswerState.success
        ? 1.0
        : autoTranslationOpacity;
    final bool translationVisible = translationOpacity > 0.05;
    // auto-advance pending state no longer displayed

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '${currentIndex + 1}/${questions.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            color: Colors.black54,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
                ),
              ),
              child: Column(
                children: <Widget>[
                  // Progress indicator at top
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: LinearProgressIndicator(
                      value: (currentIndex + 1) / questions.length,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        answerState == _AnswerState.correct
                            ? Colors.green.shade400
                            : answerState == _AnswerState.incorrect
                            ? Colors.red.shade400
                            : Colors.blue.shade400,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final double maxHeight =
                                constraints.maxHeight.isFinite
                                ? constraints.maxHeight
                                : MediaQuery.of(context).size.height;
                            const double bottomSpacing = 12;

                            final Widget content = Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                bottomSpacing,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  // 将答案区与选项区平均分配高度
                                  Expanded(
                                    flex: 1,
                                    child: _buildAnswerSection(
                                      translationOpacity: translationOpacity,
                                      translationVisible: translationVisible,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    flex: 1,
                                    child: _buildOptionsSection(),
                                  ),
                                ],
                              ),
                            );

                            return SizedBox(height: maxHeight, child: content);
                          },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection({
    required double translationOpacity,
    required bool translationVisible,
  }) {
    final bool isTranslationStage = _stage == _PracticeStage.translation;
    final bool isCompletedStage = _stage == _PracticeStage.completed;
    final bool isInteractiveStage = !isCompletedStage;

    final List<String> stageFilledLetters = isTranslationStage
        ? _selectedMeaningTokens
        : selectedLetters;
    final List<int> stageHiddenIndices =
        (isTranslationStage || isCompletedStage)
        ? List<int>.generate(_translationTokens.length, (int index) => index)
        : current.hiddenIndices;

    final List<String> maskedFilledLetters = isCompletedStage
        ? List<String>.from(_translationTokens)
        : (_selectedMeaningTokens.length == _translationTokens.length &&
                  isTranslationStage
              ? <String>[] // 词义拖拽成功后，下划线区域也不显示文本
              : stageFilledLetters);

    final int totalSlots = stageHiddenIndices.length;

    // 计算已完成的翻译列表（包含 _completedMeanings）
    final List<String> completedTranslations = <String>[];
    for (final Meaning meaning in _completedMeanings) {
      completedTranslations.add(
        '${meaning.partOfSpeech} ${meaning.translation.join(', ')}',
      );
    }

    // 如果当前组也已完成，临时加入当前组的翻译用于下方展示
    final bool currentGroupCompleted =
        isTranslationStage &&
        _translationTokens.isNotEmpty &&
        _selectedMeaningTokens.length == _translationTokens.length &&
        _currentMeaningIndex < current.meanings.length;
    if (currentGroupCompleted) {
      final Meaning meaning = current.meanings[_currentMeaningIndex];
      completedTranslations.add(
        '${meaning.partOfSpeech} ${meaning.translation.join(', ')}',
      );
    }

    // 下方展示只用 completedTranslations，顶部单词直接使用 current.word
    final bool hasCompletedTranslations = completedTranslations.isNotEmpty;
    // completedTranslationsString removed; using completedTranslations list directly
    // 选择用于显示翻译时的颜色：优先使用最后一次拖拽使用的选项颜色
    final int? lastUsedOriginalIndex = _translationUsedOptionIndices.isNotEmpty
        ? _translationUsedOptionIndices.last
        : null;
    final Color completedDisplayColor =
        (lastUsedOriginalIndex != null &&
            lastUsedOriginalIndex >= 0 &&
            lastUsedOriginalIndex < _optionColorsFull.length)
        ? _optionColorsFull[lastUsedOriginalIndex]
        : (_optionColorsFull.isNotEmpty
              ? _optionColorsFull[0]
              : Colors.black87);
    final bool useTranslationTokens =
        (isTranslationStage || isCompletedStage) &&
        _translationTokens.isNotEmpty;
    final String displayWord = useTranslationTokens
        ? (_selectedMeaningTokens.length == _translationTokens.length
              ? '' // 完成时不显示文本，只保留下划线区域
              : _buildTranslationPlaceholder(_translationTokens))
        : current.word;
    final List<String>? expectedLetters =
        (isTranslationStage || isCompletedStage)
        ? (_selectedMeaningTokens.length == _translationTokens.length
              ? null // 拖拽成功后不再显示expectedLetters
              : _translationTokens)
        : null;

    Widget buildContent() {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _MaskedWord(
                          word: displayWord,
                          hiddenIndices: stageHiddenIndices,
                          filledLetters: maskedFilledLetters,
                          userFilledCount: maskedFilledLetters.length,
                          state: isCompletedStage
                              ? _AnswerState.success
                              : answerState,
                          onLetterDropped: isTranslationStage
                              ? _onDropTranslationToken
                              : _onDropLetter,
                          dropLocked: isDropLocked || !isInteractiveStage,
                          syllableBreakpoints:
                              (isTranslationStage || isCompletedStage)
                              ? null
                              : current.syllableBreakpoints,
                          isSnapping: _isSnapping,
                          snapProgress: _snapProgress,
                          nextBlankKey: isInteractiveStage
                              ? _nextBlankKey
                              : null,
                          tempWrongIndices:
                              (isTranslationStage || isCompletedStage)
                              ? null
                              : _tempWrongSlots,
                          expectedLetters: expectedLetters,
                          isTranslationStage: isTranslationStage,
                        ),
                        if (!isTranslationStage &&
                            !isCompletedStage &&
                            current.syllableBreakpoints != null &&
                            current.syllableBreakpoints!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              current.getSyllableString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // 成功后在答案区下方显示词义信息：
                        // - 如果刚完成当前组（currentGroupCompleted），优先显示该组的中文释义（居中放大）
                        // - 否则显示已有的已完成翻译汇总（较小字号）
                        // 彩色单词展示：根据是否已有完成的词义动态分段
                        if (_showColoredWordGroup)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Center(
                              child: SlideTransition(
                                position:
                                    _middleWordOffset ??
                                    AlwaysStoppedAnimation<Offset>(Offset.zero),
                                child: Builder(
                                  builder: (BuildContext context) {
                                    final String cleanedWord = current.word
                                        .replaceAll(RegExp(r'[-\s]'), '');
                                    if (cleanedWord.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final bool useCompleted =
                                        hasCompletedTranslations;
                                    final int segmentCount = useCompleted
                                        ? completedTranslations.length.clamp(
                                            1,
                                            cleanedWord.length,
                                          )
                                        : 1;
                                    final int base =
                                        (cleanedWord.length / segmentCount)
                                            .floor();
                                    final int remainder =
                                        cleanedWord.length % segmentCount;
                                    final List<Color> colors =
                                        List<Color>.generate(
                                          segmentCount,
                                          (int i) =>
                                              i < _optionColorsFull.length &&
                                                  _optionColorsFull.isNotEmpty
                                              ? _optionColorsFull[i]
                                              : _optionColorPalette[i %
                                                    _optionColorPalette.length],
                                          growable: false,
                                        );

                                    final List<Widget> parts = <Widget>[];
                                    if (segmentCount == 1) {
                                      parts.add(
                                        Text(
                                          cleanedWord,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: colors.first,
                                            letterSpacing: 0.0,
                                          ),
                                        ),
                                      );
                                    } else {
                                      int cursor = 0;
                                      for (int i = 0; i < segmentCount; i++) {
                                        final int len =
                                            base + (i < remainder ? 1 : 0);
                                        final String part = cleanedWord
                                            .substring(cursor, cursor + len);
                                        cursor += len;
                                        parts.add(
                                          Text(
                                            part,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: colors[i],
                                              letterSpacing: 0.0,
                                            ),
                                          ),
                                        );
                                      }
                                    }

                                    return Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 2,
                                      children: parts,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        if (currentGroupCompleted)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              height: 88,
                              child: Center(
                                child: Text(
                                  current
                                      .meanings[_currentMeaningIndex]
                                      .translation
                                      .join('、'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: completedDisplayColor,
                                    letterSpacing: 0.0,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (hasCompletedTranslations)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: completedTranslations
                                    .map((String t) {
                                      // 根据字数动态计算字号，短词更大
                                      final int len = t
                                          .replaceAll(RegExp(r"\s+"), '')
                                          .length;
                                      final double dynamicSize = len <= 2
                                          ? 40.0
                                          : len == 3
                                          ? 34.0
                                          : len == 4
                                          ? 28.0
                                          : 22.0;
                                      return Text(
                                        t,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: dynamicSize,
                                          fontWeight: FontWeight.w700,
                                          color: completedDisplayColor,
                                          letterSpacing: 0.0,
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 左上角单词仅在翻译阶段显示，拼写阶段隐藏
                if (isTranslationStage)
                  Positioned(
                    top: 1,
                    left: 0,
                    child: Transform.scale(
                      scale: 0.6,
                      alignment: Alignment.topLeft,
                      child: _buildSyllableGroupedWord(current.word),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    if (!isInteractiveStage) {
      return buildContent();
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        DragTarget<_DragLetterPayload>(
          onWillAccept: (data) {
            return data != null &&
                !isDropLocked &&
                maskedFilledLetters.length < totalSlots;
          },
          onAccept: (data) {
            if (!isTranslationStage) {
              _scrollToFirstBlank();
            }
            _onDropLetter(data);
          },
          onMove: (details) {
            if (!isTranslationStage) {
              _scrollToFirstBlank();
            }
          },
          onLeave: (data) {
            _resetScrollFlag();
          },
          builder:
              (
                BuildContext context,
                List<_DragLetterPayload?> candidateData,
                List<dynamic> rejectedData,
              ) {
                return buildContent();
              },
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    // 如果还未初始化，返回空容器
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final List<String> selections = _currentSelectedItems;
            final List<String> expectedSequence = _currentExpectedItems;
            final int optionOffset = selections.length.clamp(
              0,
              _optionWeightsFull.length,
            );
            final bool hasEnoughWeights =
                optionOffset + activeOptions.length <=
                _optionWeightsFull.length;
            final bool hasEnoughColors =
                optionOffset + activeOptions.length <= _optionColorsFull.length;
            final List<double> optionWeights = hasEnoughWeights
                ? _optionWeightsFull
                      .skip(optionOffset)
                      .take(activeOptions.length)
                      .toList(growable: false)
                : List<double>.filled(activeOptions.length, 1.0);
            final List<Color> optionColors = hasEnoughColors
                ? _optionColorsFull
                      .skip(optionOffset)
                      .take(activeOptions.length)
                      .toList(growable: false)
                : List<Color>.filled(
                    activeOptions.length,
                    Colors.blueGrey.shade400,
                  );
            final String? expectedItem =
                selections.length < expectedSequence.length
                ? expectedSequence[selections.length]
                : null;
            // 计算 correctIndex，跳过已使用的选项（对于翻译阶段很重要，因为两个选项都在选择区）
            final int correctIndex = expectedItem == null
                ? -1
                : activeOptions
                          .asMap()
                          .entries
                          .where((MapEntry<int, String> entry) {
                            // 跳过已使用的选项
                            if (_currentUsedIndices.contains(entry.key)) {
                              return false;
                            }
                            final String option = entry.value;
                            if (_stage == _PracticeStage.spelling) {
                              return option.toLowerCase() ==
                                  expectedItem.toLowerCase();
                            }
                            return option == expectedItem;
                          })
                          .map((MapEntry<int, String> entry) => entry.key)
                          .firstOrNull ??
                      -1;
            final bool showZipper =
                _showZipperOverlay && _stage == _PracticeStage.spelling;

            final Widget keyboard = Padding(
              padding: const EdgeInsets.all(16),
              child: _OptionsKeyboard(
                options: activeOptions,
                weights: optionWeights,
                colors: optionColors,
                topPadding: _optionRowTopPadding,
                usedOptionIndices: _currentUsedIndices,
                onTapLetter: _onTapLetter,
                dragOnly: true,
                canDrag: !isDropLocked && !_isWaitingBetweenMeanings,
                correctIndex: correctIndex,
                isSnapping: _isSnapping,
                snapProgress: _snapProgress,
              ),
            );

            return Stack(
              children: <Widget>[
                keyboard,
                if (showZipper)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildZipperOverlay(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildZipperOverlay() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double fullHeight = constraints.maxHeight.clamp(
          1.0,
          double.infinity,
        );
        final double halfHeight = fullHeight / 2;
        _lastZipperHalfHeight = halfHeight;
        final double progress = _zipProgress.clamp(0.0, 1.0);
        // 如果当前 progress 为 0 且存在上拉偏移，使用临时进度以驱动面板联动
        final bool isPullingUp = progress <= 0.001 && _zipDragOffset < 0;
        final double signedProgress = isPullingUp
            ? -(_zipDragOffset.abs() / halfHeight).clamp(0.0, 1.0)
            : progress;
        final double visualProgress = signedProgress.abs();
        final double gap = fullHeight * visualProgress;
        final double panelHeight = visualProgress < 0.1
            ? fullHeight
            : max(0.0, halfHeight - gap / 2); // 初始状态完全遮盖
        final double handleTravel = halfHeight - 28.0;
        final double handleOffset = (signedProgress * handleTravel).clamp(
          -handleTravel,
          handleTravel,
        );

        Widget buildPanel(bool isTop) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12B886), // 首页绿色背景
              borderRadius: isTop
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                      // 底部直角，方便合并
                    )
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                      // 顶部直角，方便合并
                    ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          );
        }

        Widget buildTeeth() {
          final double teethHeight = fullHeight * 0.55;
          return SizedBox(height: teethHeight); // 删除拉链上的点
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (DragUpdateDetails details) {
            if (!_showZipperOverlay) return;
            final double delta = details.primaryDelta ?? 0.0;
            if (halfHeight <= 0) return;
            final double next = (_zipProgress + delta / (halfHeight * 1.1))
                .clamp(0.0, 1.0);
            if (next >= 0.95) {
              // 达到下拉完成阈值：标记为应完成（但不立即完成，以免中断手势或引起重排）
              setState(() {
                _zipShouldComplete = true;
              });
              return;
            } else {
              // 如果向上拖拽且 next 接近或小于 0，切换到上拉模式
              // 或者在 progress 已经在 0 时继续上拉，直接累积偏移让手柄跟手移动
              if (delta < 0 && (next <= 0.001 || _zipProgress <= 0.001)) {
                setState(() {
                  // 如果正在从正常 progress 切换到上拉模式，需要计算初始偏移
                  if (_zipProgress > 0.001) {
                    // 将当前的 progress 转换为对应的 dragOffset，保持视觉连续性
                    final double currentVisualOffset =
                        _zipProgress * halfHeight * 1.1;
                    _zipDragOffset = (-currentVisualOffset + delta).clamp(
                      -halfHeight,
                      0.0,
                    );
                    _zipProgress = 0.0;
                  } else {
                    // 已经在上拉模式，直接累积 delta
                    _zipDragOffset = (_zipDragOffset + delta).clamp(
                      -halfHeight,
                      0.0,
                    );
                  }
                  // 当偏移超过阈值时，标记为可跳过下一词
                  _zipSkipArmed =
                      _zipDragOffset <= -max(40.0, halfHeight * 0.25);
                });

                // 如果在上拉过程中已经拉到顶部阈值，将状态标记为应完成（但不立即完成，避免中断手势）
                if (_zipDragOffset.abs() >= max(halfHeight * 0.9, 40.0)) {
                  // 标记为应完成，但不要修改进度值或移除 overlay，避免中断手势
                  setState(() {
                    _zipShouldComplete = true;
                  });
                  return;
                }
              } else {
                // 正常下拉或拖拽，更新 progress
                setState(() {
                  _zipProgress = next;
                  // 只有在下拉时才重置 dragOffset，避免上拉时回退
                  if (delta > 0) {
                    _zipDragOffset = 0.0;
                    _zipSkipArmed = false;
                  }
                });
              }
            }
          },
          onVerticalDragEnd: (_) => _handleZipperRelease(),
          onTap: () {
            // 轻点手柄也尝试推进动画
            final double next = (_zipProgress + 0.2).clamp(0.0, 1.0);
            if (next >= 0.95) {
              _completeZipperReveal();
            } else {
              setState(() {
                _zipProgress = next;
                _zipSkipArmed = false;
                _zipDragOffset = 0.0;
              });
            }
          },
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: visualProgress < 0.1
                    ? 0
                    : (fullHeight - panelHeight), // 初始状态完全遮盖
                child: buildPanel(true),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                top: visualProgress < 0.1
                    ? 0
                    : (fullHeight - panelHeight), // 初始状态完全遮盖
                child: buildPanel(false),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    buildTeeth(),
                    const SizedBox(height: 12),
                    Transform.translate(
                      offset: Offset(
                        0,
                        handleOffset - handleTravel / 1.6,
                      ), // 往上一点点
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 12,
                              offset: const Offset(0, 0), // 居中阴影
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.unfold_more,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyllableGroupedWord(String word) {
    final List<int> breakpoints = current.syllableBreakpoints ?? <int>[];

    if (breakpoints.isEmpty) {
      return Text(
        word,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 27, // 增大50%: 18 * 1.5 = 27
          fontWeight: FontWeight.w600,
          color: Colors.green, // 改为绿色
          letterSpacing: 2,
        ),
      );
    }

    // 按照单词拼写阶段的逻辑，在指定位置插入空格
    String result = '';
    for (int i = 0; i < word.length; i++) {
      result += word[i];
      if (breakpoints.contains(i)) {
        result += ' ';
      }
    }

    return Center(
      child: Text(
        result,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 27, // 增大50%: 18 * 1.5 = 27
          fontWeight: FontWeight.w600,
          color: Colors.green, // 改为绿色
          letterSpacing: 1,
        ),
      ),
    );
  }

  void _onTapLetter(int optionIndex, String letter) {
    if (_isTranslationStage) {
      _handleTranslationSelection(optionIndex, letter);
      return;
    }
    if (selectedLetters.length >= current.hiddenIndices.length) return;
    _cancelAutoAdvance();
    setState(() {
      selectedLetters.add(letter);
      usedOptionIndices.add(optionIndex);
    });

    // 更新候选显示（即使最后一个字母也要清空）
    _prepareOptions();

    if (selectedLetters.length == current.hiddenIndices.length) {
      final bool isRight = _isAnswerCorrect();
      setState(
        () => answerState = isRight
            ? _AnswerState.correct
            : _AnswerState.incorrect,
      );
      Future<void>.delayed(Duration(milliseconds: isRight ? 500 : 900), () {
        if (!mounted) return;
        if (isRight) {
          // 显示成功，并弹出拉链特效，等待用户开启词义练习
          setState(() {
            answerState = _AnswerState.success;
            _resetScrollFlag(); // 成功时重置滚动标志
            _showZipperOverlay = true;
            _zipProgress = 0.0;
            _showColoredWordGroup = true;
            _zipSkipArmed = false;
          });
          // 不自动切换，等待用户操作：知道 -> 跳到下一个单词；再看看 -> 进入翻译练习
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            _middleWordController?.forward();
          });
        } else {
          _cancelAutoAdvance();
          setState(() {
            selectedLetters.clear();
            usedOptionIndices.clear();
            answerState = _AnswerState.none;
            _resetScrollFlag(); // 失败时重置滚动标志
          });
          // 错误后重新随机候选字母
          _prepareOptions();
        }
      });
    }
  }

  void _transitionAfterWordSolved() {
    _cancelAutoAdvance();
    // 重置含义索引，从第一个含义开始
    _currentMeaningIndex = 0;
    _completedMeanings.clear(); // 清空已完成的词意组列表
    _isWaitingBetweenMeanings = false; // 重置等待标志
    _initializeTranslationStage();
    if (_translationTokens.isEmpty) {
      setState(() {
        _stage = _PracticeStage.completed;
        activeOptions = <String>[];
        activeOptionIndices = <int>[];
        answerState = _AnswerState.success;
        isDropLocked = false;
        _showColoredWordGroup = false;
        _showZipperOverlay = false;
        _zipProgress = 0.0;
        _zipSkipArmed = false;
      });
      _scheduleAutoAdvanceIfReady(restartTimer: true);
      return;
    }
    setState(() {
      _stage = _PracticeStage.translation;
      _selectedMeaningTokens.clear();
      _translationUsedOptionIndices.clear();
      _lastOptionsStage = null;
      answerState = _AnswerState.none;
      isDropLocked = false;
      activeOptionIndices = <int>[];
      _showColoredWordGroup = false;
      _showZipperOverlay = false;
      _zipProgress = 0.0;
      _zipSkipArmed = false;
      // 开始新组时显示instruction
    });
    _prepareOptions();
  }

  void _handleZipperRelease() {
    if (!_showZipperOverlay) return;
    // 如果在拖拽过程中已达阈值，拖起时完成（优先处理 shouldComplete）
    if (_zipShouldComplete) {
      _zipShouldComplete = false;
      _completeZipperReveal();
      return;
    }
    // Determine halfHeight for pull-up threshold.
    final double halfHeight =
        _lastZipperHalfHeight ?? (MediaQuery.of(context).size.height / 4.0);

    // If progress fully opened by downward pull, complete reveal.
    if (_zipProgress >= 0.9) {
      _completeZipperReveal();
      return;
    }

    // If user pulled up far enough (visual top), treat as complete as well.
    if (_zipDragOffset < 0) {
      final double pullUpAbs = _zipDragOffset.abs();
      // Require near-full pull (90% of halfHeight) to complete, matching down behavior.
      if (pullUpAbs >= max(halfHeight * 0.9, 40.0)) {
        _completeZipperReveal();
        return;
      }
    }

    // If armed for skip (short upward pull) and not actually opening, skip to next word.
    if (_zipSkipArmed && _zipProgress <= 0.05) {
      _skipToNextWord();
      return;
    }

    // Otherwise revert to initial state.
    setState(() {
      _zipProgress = 0.0;
      _zipSkipArmed = false;
      _zipDragOffset = 0.0;
    });
  }

  void _completeZipperReveal() {
    if (!_showZipperOverlay) return;
    setState(() {
      _zipProgress = 1.0;
      _showZipperOverlay = false;
      _zipSkipArmed = false;
      _zipShouldComplete = false;
    });
    _transitionAfterWordSolved();
  }

  void _skipToNextWord() {
    if (!_showZipperOverlay) return;
    _cancelAutoAdvance();
    setState(() {
      _zipProgress = 0.0;
      _showZipperOverlay = false;
      _zipSkipArmed = false;
    });
    _next();
  }

  void _handleTranslationSelection(int optionIndex, String token) {
    if (!_isTranslationStage) return;
    if (_selectedMeaningTokens.length >= _translationTokens.length) return;
    final int nextIndex = _selectedMeaningTokens.length;
    if (nextIndex >= _translationTokens.length) return;
    final String expected = _translationTokens[nextIndex];
    if (token != expected) return;

    _cancelAutoAdvance();
    final int originalIndex =
        (optionIndex >= 0 && optionIndex < activeOptionIndices.length)
        ? activeOptionIndices[optionIndex]
        : optionIndex;

    setState(() {
      _selectedMeaningTokens.add(token);
      _translationUsedOptionIndices.add(originalIndex);
    });

    _prepareOptions();

    if (_selectedMeaningTokens.length == _translationTokens.length) {
      _completeTranslationStage();
    }
  }

  void _onDropTranslationToken(_DragLetterPayload payload) {
    if (!_isTranslationStage) return;
    int optionIndex = payload.optionIndex;
    final String token = payload.letter;

    if (optionIndex < 0 || optionIndex >= activeOptions.length) {
      optionIndex = activeOptions.indexOf(token);
      if (optionIndex == -1) return;
    }

    _handleTranslationSelection(optionIndex, token);
  }

  void _completeTranslationStage() {
    if (_stage != _PracticeStage.translation) return;

    // 将当前完成的词意组添加到已完成列表
    if (_currentMeaningIndex < current.meanings.length) {
      _completedMeanings.add(current.meanings[_currentMeaningIndex]);
    }

    // 如果当前还不是最后一个含义组，等待3秒后切换到下一组
    if (_currentMeaningIndex < current.meanings.length - 1) {
      setState(() {
        _isWaitingBetweenMeanings = true;
        isDropLocked = true; // 等待期间禁用拖拽
      });

      // 等待3秒后继续下一组
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        // 移动到下一个含义组
        _currentMeaningIndex++;
        _initializeTranslationStage(); // 初始化下一组的项（词性 + 拆分的中文字符）
        setState(() {
          _selectedMeaningTokens.clear();
          _translationUsedOptionIndices.clear();
          _lastOptionsStage = null;
          answerState = _AnswerState.none;
          isDropLocked = false;
          _isWaitingBetweenMeanings = false;
          activeOptionIndices = <int>[];
          // 切换到下一组时显示instruction
        });
        _prepareOptions(); // 更新选项区，显示下一组的选项
      });
      return;
    }

    // 所有含义组都完成了，进入完成阶段
    setState(() {
      _stage = _PracticeStage.completed;
      activeOptions = <String>[];
      activeOptionIndices = <int>[];
      answerState = _AnswerState.success;
      _isWaitingBetweenMeanings = false;
    });
    _scheduleAutoAdvanceIfReady(restartTimer: true);
  }

  void _onDropLetter(_DragLetterPayload payload) {
    if (_isTranslationStage) {
      _onDropTranslationToken(payload);
      return;
    }
    // 计算当前应填的目标字母
    final int nextOrder = selectedLetters.length;
    if (nextOrder >= current.hiddenIndices.length) return;

    // 使用拖拽项自身携带的索引，但当当前选项列表已变化或索引不匹配时，
    // 回退为在当前 activeOptions 中寻找合适的索引（优先未被使用的同字母项）
    int currentIndex = payload.optionIndex;
    final String payloadLetterLower = payload.letter.toLowerCase();
    final bool indexStillValid =
        currentIndex >= 0 &&
        currentIndex < activeOptions.length &&
        activeOptions[currentIndex].toLowerCase() == payloadLetterLower;
    if (!indexStillValid) {
      // 尝试找到一个同字母、且尚未被使用的索引
      int foundIndex = -1;
      for (int i = 0; i < activeOptions.length; i += 1) {
        if (activeOptions[i].toLowerCase() == payloadLetterLower &&
            !usedOptionIndices.contains(i)) {
          foundIndex = i;
          break;
        }
      }
      // 若无未使用的匹配项，再尝试找到任意匹配项（即使已被标记为使用）
      if (foundIndex == -1) {
        for (int i = 0; i < activeOptions.length; i += 1) {
          if (activeOptions[i].toLowerCase() == payloadLetterLower) {
            foundIndex = i;
            break;
          }
        }
      }
      if (foundIndex != -1) currentIndex = foundIndex;
    }

    if (currentIndex < 0) {
      // 找不到对应字母，放弃此次拖拽
      return;
    }

    final int nextIndex = current.hiddenIndices[nextOrder];
    final String expected = current.word[nextIndex];
    final bool isCorrect =
        payload.letter.toLowerCase() == expected.toLowerCase();

    // 先判断是否正确，再决定是否允许拖拽
    if (isCorrect) {
      // 只要拖拽进来就判断正确性，不在此处以已用索引拦截。
      // 成功拖拽后重置滚动标志并交由点击逻辑处理（会加入 usedOptionIndices）
      _resetScrollFlag();
      _onTapLetter(currentIndex, payload.letter);
      return;
    }

    // 错误答案：先检查是否正在处理错误（isDropLocked），如果是，则不允许新的拖拽
    if (isDropLocked) return;

    // 错误：先填入 -> 抖动 -> 500ms 后删除并解锁拖拽
    // 保存当前状态，用于延迟清理
    final int savedNextOrder = nextOrder;

    // 标记该空格为临时错误，以便显示红色与抖动
    _tempWrongSlots.add(nextOrder);
    _cancelAutoAdvance();
    setState(() {
      selectedLetters.add(payload.letter);
      isDropLocked = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        // 确保删除最后添加的错误字母（恢复到拖拽前的状态）
        if (selectedLetters.length > savedNextOrder &&
            selectedLetters.isNotEmpty) {
          selectedLetters.removeLast();
        }
        // 清除临时错误标记，解锁并重置滚动标志
        _tempWrongSlots.remove(nextOrder);
        isDropLocked = false;
        _resetScrollFlag();
      });
    });
  }

  // Peek and speak functionality removed

  void _scrollToFirstBlank() {
    // 防止频繁触发滚动
    if (_hasScrolledToBlank) return;

    if (!_scrollController.hasClients) return;

    if (_nextBlankKey.currentContext != null) {
      // 获取第一个空格的位置
      final RenderBox? renderBox =
          _nextBlankKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        _hasScrolledToBlank = true; // 标记已触发滚动

        final position = renderBox.localToGlobal(Offset.zero);
        final screenHeight = MediaQuery.of(context).size.height;

        // 计算滚动位置，使第一个空格显示在屏幕中央偏上位置
        final currentScroll = _scrollController.offset;
        final targetScrollPosition =
            currentScroll + position.dy - screenHeight * 0.35;

        _scrollController.animateTo(
          targetScrollPosition.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _resetScrollFlag() {
    _hasScrolledToBlank = false;
  }

  bool _cancelAutoAdvance() {
    final bool hadTimer = _autoAdvanceTimer != null;
    if (hadTimer) {
      _autoAdvanceTimer!.cancel();
      _autoAdvanceTimer = null;
    }
    return hadTimer;
  }

  bool _scheduleAutoAdvanceIfReady({bool restartTimer = false}) {
    if (answerState != _AnswerState.success) return false;
    if (_autoAdvanceTimer != null) {
      if (!restartTimer) return false;
      _autoAdvanceTimer!.cancel();
    }
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _autoAdvanceTimer = null;
      _next();
    });
    return true;
  }

  bool _isAnswerCorrect() {
    if (selectedLetters.length != current.hiddenIndices.length) return false;
    final List<String> answer = current.answerLetters;
    for (int i = 0; i < answer.length; i += 1) {
      if (answer[i] != selectedLetters[i]) return false;
    }
    return true;
  }

  void _next() {
    _cancelAutoAdvance();
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex += 1;
        selectedLetters.clear();
        usedOptionIndices.clear();
        activeOptionIndices.clear();
        answerState = _AnswerState.none;
        isDropLocked = false; // 重置拖拽锁定状态，确保下一个单词可以拖拽
        _isSnapping.value = false; // 重置吸附动画状态
        _snapProgress.value = 0.0; // 重置吸附进度
        _resetScrollFlag(); // 重置滚动标志
        _optionWeightsFull.clear();
        _optionColorsFull.clear();
        _optionRowTopPadding = 12.0;
        _stage = _PracticeStage.spelling;
        _currentMeaningIndex = 0; // 重置含义索引，从第一个含义开始
        _completedMeanings.clear(); // 清空已完成的词意组列表
        _isWaitingBetweenMeanings = false; // 重置等待标志
        _initializeTranslationStage();
        _showColoredWordGroup = false;
        _showZipperOverlay = false;
        _zipProgress = 0.0;
        _zipSkipArmed = false;
      });
      _prepareOptions();
    } else {
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: <Widget>[
                Icon(
                  Icons.celebration,
                  color: Colors.orange.shade500,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  '🎉 太棒了！',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            content: const Text(
              '今日新学练习已全部完成！\n继续保持，学习从未停止！',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade600,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('继续练习'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context)
                  ..pop()
                  ..pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('返回首页'),
              ),
            ],
          );
        },
      );
    }
  }
}

class _MaskedWord extends StatelessWidget {
  const _MaskedWord({
    required this.word,
    required this.hiddenIndices,
    required this.filledLetters,
    required this.userFilledCount,
    required this.state,
    required this.onLetterDropped,
    required this.dropLocked,
    this.syllableBreakpoints,
    required this.isSnapping,
    required this.snapProgress,
    this.nextBlankKey,
    this.tempWrongIndices,
    this.expectedLetters,
    this.isTranslationStage = false,
  });

  final String word;
  final List<int> hiddenIndices;
  final List<String> filledLetters; // 按隐藏位序填充
  final int userFilledCount;
  final ValueNotifier<bool> isSnapping;
  final ValueNotifier<double> snapProgress;
  final _AnswerState state;
  final void Function(_DragLetterPayload payload) onLetterDropped;
  final bool dropLocked;
  final List<int>? syllableBreakpoints;
  final Key? nextBlankKey;
  final Set<int>? tempWrongIndices;
  final List<String>? expectedLetters;
  final bool isTranslationStage;

  @override
  Widget build(BuildContext context) {
    // Dynamic base font size by word length (optimized for better visibility)
    final int wordLen = word.length;
    double baseFontSize;
    if (isTranslationStage) {
      // 翻译阶段使用合适的字体，确保中文字符完整显示但不覆盖
      baseFontSize = 32; // 进一步降低字体大小，避免遮盖
    } else if (wordLen <= 4) {
      baseFontSize = 52; // 进一步增大单词字体
    } else if (wordLen <= 6) {
      baseFontSize = 58; // 进一步增大单词字体
    } else if (wordLen <= 8) {
      baseFontSize = 54; // 进一步增大单词字体
    } else if (wordLen <= 10) {
      baseFontSize = 50; // 进一步增大单词字体
    } else {
      baseFontSize = 56; // 进一步增大单词字体
    }

    final TextStyle visibleStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.black87,
      letterSpacing: isTranslationStage ? 0.0 : 0.1, // 中文不需要字母间距，英文间距进一步缩小
      height: 1.0,
    );

    // compute the user's actual first-unfilled index (pre-peek),
    // exclude any temporarily-wrong-filled blanks so that wrong drops
    // do not count as "filled" for showing syllable separators
    final Set<int> _wrongSet = tempWrongIndices ?? <int>{};
    final int wrongBefore = _wrongSet
        .where((int idx) => idx < userFilledCount)
        .length;
    final int effectiveFilledCount = (userFilledCount - wrongBefore).clamp(
      0,
      hiddenIndices.length,
    );
    final int firstUnfilledHiddenUser =
        (effectiveFilledCount < hiddenIndices.length)
        ? hiddenIndices[effectiveFilledCount]
        : word.length;

    // highlight color for visible letters (always green)
    final Color highlightColor = Colors.green.shade500;

    final List<Widget> children = <Widget>[];
    int fillCursor = 0; // 当前应显示的填充值游标

    for (int i = 0; i < word.length; i += 1) {
      final bool isHidden = hiddenIndices.contains(i);
      if (isHidden) {
        final int blankOrder = fillCursor;
        final String expectedValue =
            (expectedLetters != null && blankOrder < expectedLetters!.length)
            ? expectedLetters![blankOrder]
            : word[i];
        final String? letter = (fillCursor < filledLetters.length)
            ? filledLetters[fillCursor]
            : null;
        fillCursor += 1;
        final bool isNextBlank =
            letter == null && blankOrder == filledLetters.length && !dropLocked;
        final bool matchesExpected =
            letter != null &&
            (expectedLetters != null
                ? letter == expectedValue
                : letter.toLowerCase() == expectedValue.toLowerCase());
        // 翻译阶段根据意思组长度动态调整宽度，否则使用固定宽度
        final double cellWidth = isTranslationStage
            ? (expectedLetters != null && blankOrder < expectedLetters!.length
                  ? (expectedLetters![blankOrder].length * 25.0 + 50.0).clamp(
                      100.0,
                      250.0,
                    )
                  : 100.0)
            : 80.0; // 固定的中等宽度

        final Widget blankCell = _AnimatedBlankCell(
          key: ValueKey<String>('blank_${i}_${letter ?? "empty"}_${state}'),
          letter: letter,
          state: state,
          delay: fillCursor * 100, // 错开动画时间
          onLetterDropped: onLetterDropped,
          expectedLetter: expectedValue,
          isNextBlank: isNextBlank,
          dropLocked: dropLocked,
          showError: tempWrongIndices?.contains(blankOrder) ?? false,
          baseFontSize: baseFontSize,
          width: cellWidth,
          isTranslationStage: isTranslationStage,
        );

        // 为下一个空格添加拖拽目标
        if (isNextBlank) {
          children.add(
            _BlankCellDragTarget(
              key: ValueKey('blank_$i'),
              isNextBlank: isNextBlank,
              dropLocked: dropLocked,
              onLetterDropped: onLetterDropped,
              expectedLetter: word[i],
              child: blankCell,
            ),
          );
        } else {
          children.add(blankCell);
        }

        // 如果当前字母已填且与正确字母相同，且下一个位置是音节边界，则添加分隔符
        if (matchesExpected &&
            blankOrder < userFilledCount &&
            syllableBreakpoints != null &&
            syllableBreakpoints!.contains(i)) {
          children.add(
            Text(
              ' -',
              style: visibleStyle.copyWith(color: Colors.grey.shade400),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
        }
      } else {
        // if this visible letter is to the left of the user's first-unfilled index,
        // keep it green; otherwise keep original color
        if (i < firstUnfilledHiddenUser) {
          children.add(
            Text(
              word[i],
              style: visibleStyle.copyWith(color: highlightColor),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
        } else {
          children.add(
            Text(
              word[i],
              style: visibleStyle,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
        }

        // 如果是已完成的字母，且在音节边界位置，添加分隔符
        if (i < firstUnfilledHiddenUser &&
            syllableBreakpoints != null &&
            syllableBreakpoints!.contains(i)) {
          children.add(
            Text(
              ' ',
              style: visibleStyle.copyWith(color: Colors.grey.shade400),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
        }
      }
      // 翻译阶段使用更大的间距来分隔意思组
      if (i != word.length - 1) {
        children.add(SizedBox(width: isTranslationStage ? 16.0 : 4.0));
      }
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: children,
        ),
      ),
    );
  }
}

// 单个空格的拖拽目标
class _BlankCellDragTarget extends StatefulWidget {
  const _BlankCellDragTarget({
    super.key,
    required this.isNextBlank,
    required this.dropLocked,
    required this.onLetterDropped,
    required this.expectedLetter,
    required this.child,
  });

  final bool isNextBlank;
  final bool dropLocked;
  final void Function(_DragLetterPayload payload) onLetterDropped;
  final String expectedLetter;
  final Widget child;

  @override
  State<_BlankCellDragTarget> createState() => _BlankCellDragTargetState();
}

class _BlankCellDragTargetState extends State<_BlankCellDragTarget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragLetterPayload>(
      onWillAccept: (data) {
        // 只接受下一个空格，且没有被锁定
        return widget.isNextBlank && !widget.dropLocked && data != null;
      },
      onAccept: (data) {
        widget.onLetterDropped(data);
      },
      onLeave: (data) {
        setState(() => _isHovered = false);
      },
      onMove: (details) {
        if (!_isHovered) {
          setState(() => _isHovered = true);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: _isHovered && candidateData.isNotEmpty
                ? Border.all(color: Colors.blue.shade400, width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _AnimatedBlankCell extends StatefulWidget {
  const _AnimatedBlankCell({
    super.key,
    required this.letter,
    required this.state,
    required this.delay,
    required this.onLetterDropped,
    required this.expectedLetter,
    required this.isNextBlank,
    required this.dropLocked,
    this.showError = false,
    required this.baseFontSize,
    this.width,
    this.isTranslationStage = false,
  });

  final String? letter;
  final _AnswerState state;
  final int delay;
  final void Function(_DragLetterPayload payload) onLetterDropped;
  final String expectedLetter;
  final bool isNextBlank;
  final bool dropLocked;
  final bool showError;
  final double baseFontSize;
  final double? width;
  final bool isTranslationStage;

  @override
  State<_AnimatedBlankCell> createState() => _AnimatedBlankCellState();
}

class _AnimatedBlankCellState extends State<_AnimatedBlankCell>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _frameController;
  late Animation<double> _frameOpacity;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.blue.shade400,
      end:
          (widget.state == _AnswerState.correct ||
              widget.state == _AnswerState.success)
          ? Colors.green.shade500
          : widget.state == _AnswerState.incorrect
          ? Colors.red.shade500
          : Colors.blue.shade400,
    ).animate(_colorController);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>(
      <TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0, end: -12),
          weight: 1,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -12, end: 12),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 12, end: -10),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -10, end: 10),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 10, end: -6),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -6, end: 6),
          weight: 2,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 6, end: 0),
          weight: 1,
        ),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    _frameController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _frameOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _frameController, curve: Curves.easeOutCubic),
    );

    if (widget.letter != null) {
      Future<void>.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          _bounceController.forward();
          _colorController.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedBlankCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部显式要求高亮错误（showError），也触发抖动与变红
    if (!oldWidget.showError && widget.showError && widget.letter != null) {
      _shakeController
        ..reset()
        ..forward();
      _colorAnimation = ColorTween(
        begin: _colorAnimation.value,
        end: const Color(0xFFFF0000),
      ).animate(_colorController);
      _colorController.reset();
      _colorController.forward();
    }
    if (oldWidget.letter != widget.letter) {
      if (widget.letter != null) {
        _bounceController.reset();
        _bounceController.forward();
        final bool isWrong =
            widget.letter!.toLowerCase() != widget.expectedLetter.toLowerCase();
        if (isWrong) {
          _shakeController
            ..reset()
            ..forward();
          // 错误时字体变红色
          _colorAnimation = ColorTween(
            begin: _colorAnimation.value,
            end: const Color(0xFFFF0000),
          ).animate(_colorController);
          _colorController.reset();
          _colorController.forward();
        } else {
          // 正确字母：变为绿色并渐隐边框和背景
          _colorAnimation = ColorTween(
            begin: _colorAnimation.value,
            end: Colors.green.shade500,
          ).animate(_colorController);
          _colorController.reset();
          _colorController.forward();
          _frameController
            ..reset()
            ..forward();
        }
      } else {
        // 字母被移除，恢复蓝色
        _colorAnimation = ColorTween(
          begin: _colorAnimation.value,
          end: Colors.blue.shade400,
        ).animate(_colorController);
        _colorController.reset();
        _colorController.forward();
        // 恢复边框/背景可见
        _frameController.reset();
      }
    }
    if (oldWidget.state != widget.state) {
      _colorAnimation = ColorTween(
        begin: _colorAnimation.value,
        end:
            (widget.state == _AnswerState.correct ||
                widget.state == _AnswerState.success)
            ? Colors.green.shade500
            : widget.state == _AnswerState.incorrect
            ? Colors.red.shade500
            : Colors.blue.shade400,
      ).animate(_colorController);
      _colorController.reset();
      _colorController.forward();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _colorController.dispose();
    _shakeController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Animation<dynamic>>[
        _bounceAnimation,
        _colorAnimation,
        _shakeController,
        _frameOpacity,
      ]),
      builder: (BuildContext context, Widget? child) {
        // background colors are not used in underline style
        final bool isCorrectLetter =
            widget.letter != null &&
            widget.letter!.toLowerCase() == widget.expectedLetter.toLowerCase();
        // final double frameOpacity = isCorrectLetter ? _frameOpacity.value : 1.0; // not used

        // single-letter finalized rendering
        final bool isEmpty = widget.letter == null;
        final bool isWrongLetter =
            widget.letter != null &&
            widget.letter!.toLowerCase() != widget.expectedLetter.toLowerCase();

        final bool isWordFinalized =
            widget.state == _AnswerState.correct ||
            widget.state == _AnswerState.success;

        // 如果格子已经有字，禁止位移动画与缩放动画（字落位后不动）
        final bool shouldAnimate = widget.letter == null;

        final Color baseBorderColor =
            _colorAnimation.value ?? const Color.fromARGB(255, 245, 66, 66);
        // no longer using effectiveBorderColor directly; underline color decided per-slot below

        if (!isEmpty && isWordFinalized) {
          return Transform.scale(
            scale: shouldAnimate ? _bounceAnimation.value : 1.0,
            child: _buildAnimatedLetter(
              isWrongLetter: isWrongLetter,
              isCorrectLetter: isCorrectLetter,
              letter: widget.letter!,
              isFinalized: true,
              isTranslationStage: widget.isTranslationStage,
            ),
          );
        }

        // 所有单词使用统一的容器高度，确保下划线对齐
        final double uniformHeight = widget.isTranslationStage
            ? 120.0 // 翻译阶段增加高度以容纳下划线和下方答案
            : 110.0; // 拼写阶段保持原高度
        // 根据字体大小（间接反映单词长度）微调字母底部偏移，
        // 短词（字体大）需要更大的偏移以保证下划线与其他词对齐
        double factor;
        if (widget.baseFontSize >= 50) {
          factor = 0.75;
        } else if (widget.baseFontSize >= 40) {
          factor = 0.65;
        } else if (widget.baseFontSize >= 35) {
          factor = 0.55;
        } else {
          factor = 0.45;
        }
        final double letterOffset = widget.isTranslationStage
            ? ((uniformHeight / 2 - widget.baseFontSize) * factor).clamp(
                6.0,
                36.0,
              ) // 翻译阶段下划线在中间
            : ((uniformHeight - widget.baseFontSize) * factor).clamp(
                6.0,
                36.0,
              ); // 拼写阶段保持底部

        // 使用固定的宽度保持一致性
        final double cellWidth = widget.width ?? 80.0;

        return Transform.scale(
          scale: shouldAnimate ? _bounceAnimation.value : 1.0,
          child: Container(
            width: cellWidth,
            height: uniformHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: widget.isTranslationStage
                ? Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: (isEmpty || isWrongLetter)
                          ? Border(
                              bottom: BorderSide(
                                color: isEmpty
                                    ? (widget.isNextBlank
                                          ? baseBorderColor
                                          : Colors.grey.shade300)
                                    : baseBorderColor,
                                width: isEmpty
                                    ? (widget.isNextBlank ? 1.5 : 1.0)
                                    : 1.5,
                              ),
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: letterOffset),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: isEmpty
                            ? const SizedBox.shrink()
                            : _buildAnimatedLetter(
                                isWrongLetter: isWrongLetter,
                                isCorrectLetter: isCorrectLetter,
                                letter: widget.letter!,
                                isFinalized: false,
                                isTranslationStage: widget.isTranslationStage,
                              ),
                      ),
                    ),
                  )
                : Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      // 当前空格（下一个可填）使用加粗的主色；未开始的空格改为灰色；错误时保持加粗主色
                      border: (isEmpty || isWrongLetter)
                          ? Border(
                              bottom: BorderSide(
                                color: isEmpty
                                    ? (widget.isNextBlank
                                          ? baseBorderColor
                                          : Colors.grey.shade300)
                                    : baseBorderColor,
                                width: isEmpty
                                    ? (widget.isNextBlank ? 2.5 : 1.5)
                                    : 2.5,
                              ),
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: letterOffset),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: isEmpty
                            ? const SizedBox.shrink()
                            : _buildAnimatedLetter(
                                isWrongLetter: isWrongLetter,
                                isCorrectLetter: isCorrectLetter,
                                letter: widget.letter!,
                                isFinalized: false,
                                isTranslationStage: widget.isTranslationStage,
                              ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLetter({
    required bool isWrongLetter,
    required bool isCorrectLetter,
    required String letter,
    required bool isFinalized,
    required bool isTranslationStage,
  }) {
    double fontSize;
    if (isTranslationStage) {
      final double availableWidth =
          (widget.width ?? (widget.baseFontSize * 3.0)) * 0.92;
      final int charCount = max(1, letter.runes.length);
      final double baseSize = isFinalized
          ? widget.baseFontSize * 1.05
          : widget.baseFontSize * (isWrongLetter ? 0.7 : 1.4);
      final double fitSize = availableWidth / (charCount * 1.2);
      fontSize = min(baseSize, fitSize);
      final double maxSize = isFinalized ? 48.0 : 42.0;
      fontSize = fontSize.clamp(18.0, maxSize).toDouble();
    } else {
      fontSize = isFinalized
          ? widget.baseFontSize * 1.2
          : (isWrongLetter
                ? (widget.baseFontSize - 10).clamp(24.0, 200.0)
                : (widget.baseFontSize + 12));
    }

    final Color textColor = (isCorrectLetter
        ? Colors.green.shade600
        : (isWrongLetter
              ? Colors.red
              : (_colorAnimation.value ?? Colors.black87)));

    Widget content = Text(
      letter.toLowerCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: 0.1, // 进一步缩小字母间距，成功状态更紧凑
        height: 1.0,
      ),
      textAlign: TextAlign.center,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );

    if (!isFinalized) {
      content = Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: content,
      );
    }

    if (isWrongLetter) {
      content = AnimatedBuilder(
        animation: _shakeController,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0.0),
            child: child,
          );
        },
        child: content,
      );
    }

    return content;
  }
}

class _OptionsKeyboard extends StatefulWidget {
  const _OptionsKeyboard({
    required this.options,
    required this.weights,
    required this.colors,
    required this.topPadding,
    required this.usedOptionIndices,
    required this.onTapLetter,
    this.dragOnly = false,
    required this.canDrag,
    required this.correctIndex,
    required this.isSnapping,
    required this.snapProgress,
  });

  final List<String> options;
  final List<double> weights;
  final List<Color> colors;
  final double topPadding;
  final List<int> usedOptionIndices;
  final void Function(int index, String letter) onTapLetter;
  final bool dragOnly;
  final bool canDrag;
  final int correctIndex;
  final ValueNotifier<bool> isSnapping;
  final ValueNotifier<double> snapProgress;

  @override
  State<_OptionsKeyboard> createState() => _OptionsKeyboardState();
}

class _OptionsKeyboardState extends State<_OptionsKeyboard>
    with TickerProviderStateMixin {
  static const double _collisionPadding = 3.0;
  static const double _minItemSize = 76.0;
  static const double _maxItemSize = 168.0;
  static const double _minSpeed = 22.0;
  static const double _maxSpeed = 95.0;

  Ticker? _ticker;
  final Random _random = Random();
  Duration? _lastTickTime;
  Size _movementBounds = Size.zero;
  double _itemSize = 110.0;
  List<Offset> _positions = <Offset>[];
  List<Offset> _velocities = <Offset>[];
  Set<int> _draggedIndices = <int>{};
  int _lastCorrectIndex = -1; // 跟踪上一次的正确索引
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  double _speedMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    try {
      _scaleController = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
      );
      // 延迟启动 ticker，确保 widget 树完全构建后再开始动画
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ticker = createTicker(_handleTick)..start();
        }
      });
    } catch (e) {
      debugPrint('Error initializing animations: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OptionsKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.length != oldWidget.options.length) {
      _adjustPositionsForNewCount(widget.options.length);
      _lastCorrectIndex = widget.correctIndex;
    } else if (widget.correctIndex != _lastCorrectIndex &&
        widget.correctIndex >= 0) {
      // 有新的字母变为可拖拽状态，触发动画
      _scaleController.reset();
      _scaleController.forward();
    }
    _lastCorrectIndex = widget.correctIndex;
  }

  void _resetSimulation() {
    _positions = <Offset>[];
    _velocities = <Offset>[];
    _lastTickTime = null;
  }

  void _adjustPositionsForNewCount(int newCount) {
    final int oldCount = _positions.length;
    if (oldCount == newCount) return;
    // If bounds not initialized yet, fallback to full reset
    if (_movementBounds == Size.zero || _itemSize <= 0) {
      _resetSimulation();
      return;
    }

    if (newCount > oldCount) {
      final double maxX = max(0.0, _movementBounds.width);
      final double maxY = max(0.0, _movementBounds.height);
      for (int i = oldCount; i < newCount; i += 1) {
        // 让新选项更倾向于放在上方区域，方便拖拽
        final double upperRegionHeight = maxY * 0.6; // 上方60%的区域
        final Offset candidate = Offset(
          _random.nextDouble() * maxX,
          _random.nextDouble() * upperRegionHeight, // 只在上方区域随机
        );
        _positions.add(_clampToBounds(candidate));
        // give reasonable initial velocity
        double speed = ((_minSpeed + _maxSpeed) / 2) * _speedMultiplier;
        // 非可拖拽项（无法拖动或非正确索引）使用更高速度以增加运动感
        final bool isDraggable = widget.canDrag && _isIndexCorrect(i);
        if (!isDraggable) speed *= 2.0;
        _velocities.add(_randomUnitVector() * speed);
      }
    } else {
      // remove extra positions/velocities while keeping earlier items stable
      _positions.removeRange(newCount, oldCount);
      _velocities.removeRange(newCount, oldCount);
    }
    _lastTickTime = null;
  }

  void _initializePositions(Size bounds, double itemSize) {
    _movementBounds = bounds;
    _itemSize = itemSize;
    _positions = <Offset>[];
    _velocities = <Offset>[];
    _lastTickTime = null;

    _setSpeedMultiplier(itemSize);

    final double maxX = max(0.0, bounds.width);
    final double maxY = max(0.0, bounds.height);

    final double minWeight = widget.weights.isEmpty
        ? 0.0
        : widget.weights.reduce(min);
    final double maxWeight = widget.weights.isEmpty
        ? 1.0
        : widget.weights.reduce(max);
    final double weightRange = (maxWeight - minWeight).abs() < 1e-3
        ? 1.0
        : (maxWeight - minWeight);

    final int count = widget.options.length;
    final double countFactor = 1.0 + (count.clamp(1, 12) - 1) * 0.12;

    for (int i = 0; i < count; i += 1) {
      Offset candidate = Offset.zero;
      bool placed = false;
      for (int attempt = 0; attempt < 160 && !placed; attempt += 1) {
        // 让初始位置也更倾向于放在上方区域，方便拖拽
        final double upperRegionHeight = maxY * 0.6; // 上方60%的区域
        candidate = Offset(
          _random.nextDouble() * maxX,
          _random.nextDouble() * upperRegionHeight, // 只在上方区域随机
        );
        placed = true;
        for (final Offset existing in _positions) {
          if ((existing - candidate).distance <
              (_itemSize + _collisionPadding * 2)) {
            placed = false;
            break;
          }
        }
      }
      if (!placed) {
        final double angle = (i / max(1, count)) * 2 * pi;
        // 备用位置也放在上方区域
        final double upperCenterY = maxY * 0.3; // 上方区域的中心
        candidate = Offset(
          (maxX / 2) + cos(angle) * maxX * 0.3,
          upperCenterY + sin(angle) * (maxY * 0.3), // 在上方区域内圆形排列
        );
      }
      _positions.add(_clampToBounds(candidate));

      final double normalizedWeight = widget.weights.isEmpty
          ? 0.5
          : ((widget.weights[i] - minWeight) / weightRange).clamp(0.0, 1.0);
      double speed =
          (_minSpeed + (_maxSpeed - _minSpeed) * normalizedWeight) *
          countFactor *
          _speedMultiplier;
      // 如果当前项不可拖拽，则加速显示（速度翻倍）
      final bool isDraggable = widget.canDrag && _isIndexCorrect(i);
      if (!isDraggable) speed *= 2.0;
      final Offset direction = _randomUnitVector();
      final Offset velocity = direction * speed;
      const double maxVelocity = 220.0;
      _velocities.add(
        Offset(
          velocity.dx.clamp(-maxVelocity, maxVelocity),
          velocity.dy.clamp(-maxVelocity, maxVelocity),
        ),
      );
    }
  }

  void _handleTick(Duration elapsed) {
    if (!mounted || _positions.isEmpty) {
      _lastTickTime = elapsed;
      return;
    }
    if (_lastTickTime == null) {
      _lastTickTime = elapsed;
      return;
    }
    final double dt = (elapsed - _lastTickTime!).inMicroseconds / 1e6;
    _lastTickTime = elapsed;
    if (dt <= 0 || dt > 1.0) return; // Prevent large time jumps
    try {
      _applyPhysics(dt);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error in physics simulation: $e');
    }
  }

  void _applyPhysics(double dt) {
    final double maxX = max(0.0, _movementBounds.width);
    final double maxY = max(0.0, _movementBounds.height);

    for (int i = 0; i < _positions.length; i += 1) {
      // 跳过正在被拖拽的选项
      if (_draggedIndices.contains(i)) continue;

      Offset pos = _positions[i] + _velocities[i] * dt;
      Offset vel = _velocities[i];

      if (pos.dx <= 0) {
        pos = Offset(0, pos.dy);
        vel = Offset(vel.dx.abs(), vel.dy);
      } else if (pos.dx >= maxX) {
        pos = Offset(maxX, pos.dy);
        vel = Offset(-vel.dx.abs(), vel.dy);
      }

      if (pos.dy <= 0) {
        pos = Offset(pos.dx, 0);
        vel = Offset(vel.dx, vel.dy.abs());
      } else if (pos.dy >= maxY) {
        pos = Offset(pos.dx, maxY);
        vel = Offset(vel.dx, -vel.dy.abs());
      }

      _positions[i] = pos;
      _velocities[i] = vel;
    }

    for (int i = 0; i < _positions.length; i += 1) {
      for (int j = i + 1; j < _positions.length; j += 1) {
        final double baseSizeI = _baseItemSizeForIndex(i);
        final double baseSizeJ = _baseItemSizeForIndex(j);
        Offset centerI = _centerFromTopLeft(_positions[i], baseSizeI);
        Offset centerJ = _centerFromTopLeft(_positions[j], baseSizeJ);

        Offset delta = centerJ - centerI;
        double distance = delta.distance;
        if (distance <= 1e-6) {
          delta = _randomUnitVector();
          distance = 1e-6;
        }
        final Offset direction = delta / distance;

        final double collisionDistance =
            _touchRadiusForIndex(i) +
            _touchRadiusForIndex(j) +
            _collisionPadding;

        if (distance >= collisionDistance) {
          // update stored positions to ensure consistency with any previous adjustments
          _positions[i] = _topLeftFromCenter(centerI, baseSizeI);
          _positions[j] = _topLeftFromCenter(centerJ, baseSizeJ);
          continue;
        }

        final bool iDragged = _draggedIndices.contains(i);
        final bool jDragged = _draggedIndices.contains(j);
        final double overlap = collisionDistance - distance;

        double moveI;
        double moveJ;
        if (iDragged && !jDragged) {
          moveI = 0;
          moveJ = overlap;
        } else if (jDragged && !iDragged) {
          moveI = overlap;
          moveJ = 0;
        } else {
          moveI = overlap / 2;
          moveJ = overlap / 2;
        }

        centerI = _clampCenterWithinBounds(
          centerI - direction * moveI,
          baseSizeI,
        );
        centerJ = _clampCenterWithinBounds(
          centerJ + direction * moveJ,
          baseSizeJ,
        );

        if (!iDragged && !jDragged) {
          final Offset temp = _velocities[i];
          _velocities[i] = _velocities[j];
          _velocities[j] = temp;
        }

        _positions[i] = _topLeftFromCenter(centerI, baseSizeI);
        _positions[j] = _topLeftFromCenter(centerJ, baseSizeJ);

        // Secondary check in case clamping caused residual overlap
        final Offset updatedDelta = centerJ - centerI;
        final double updatedDistance = updatedDelta.distance;
        if (updatedDistance < collisionDistance && (iDragged || jDragged)) {
          final Offset dir = updatedDistance <= 1e-6
              ? _randomUnitVector()
              : updatedDelta / updatedDistance;
          final double extra = collisionDistance - updatedDistance;
          if (iDragged && !jDragged) {
            centerJ = _clampCenterWithinBounds(
              centerJ + dir * extra,
              baseSizeJ,
            );
            _positions[j] = _topLeftFromCenter(centerJ, baseSizeJ);
          } else if (jDragged && !iDragged) {
            centerI = _clampCenterWithinBounds(
              centerI - dir * extra,
              baseSizeI,
            );
            _positions[i] = _topLeftFromCenter(centerI, baseSizeI);
          }
        }
      }
    }
  }

  Offset _clampToBounds(Offset value) {
    final double maxX = max(0.0, _movementBounds.width);
    final double maxY = max(0.0, _movementBounds.height);
    return Offset(value.dx.clamp(0.0, maxX), value.dy.clamp(0.0, maxY));
  }

  Offset _randomUnitVector() {
    final double angle = _random.nextDouble() * pi * 2;
    return Offset(cos(angle), sin(angle));
  }

  void _ensureInitialized(Size bounds, double itemSize) {
    final int count = widget.options.length;
    if (count == 0) return;
    if (_movementBounds == Size.zero || _positions.isEmpty) {
      _initializePositions(bounds, itemSize);
      return;
    }

    if (_positions.length != count) {
      _adjustPositionsForNewCount(count);
    }

    if (_positions.length != count) {
      _initializePositions(bounds, itemSize);
      return;
    }

    final double oldMaxX = max(0.0, _movementBounds.width);
    final double oldMaxY = max(0.0, _movementBounds.height);
    final double newMaxX = max(0.0, bounds.width);
    final double newMaxY = max(0.0, bounds.height);

    if ((oldMaxX - newMaxX).abs() > 0.5 || (oldMaxY - newMaxY).abs() > 0.5) {
      for (int i = 0; i < _positions.length; i += 1) {
        if (_draggedIndices.contains(i)) continue;
        final Offset pos = _positions[i];
        final double ratioX = oldMaxX <= 1e-3 ? 0.5 : (pos.dx / oldMaxX);
        final double ratioY = oldMaxY <= 1e-3 ? 0.5 : (pos.dy / oldMaxY);
        _positions[i] = Offset(ratioX * newMaxX, ratioY * newMaxY);
      }
      _lastTickTime = null;
    }

    _movementBounds = bounds;
    _itemSize = itemSize;
    _setSpeedMultiplier(itemSize);
  }

  double _computeItemSize(double width, double height) {
    final int count = max(1, widget.options.length);
    final double densityFactor = sqrt(count) + 0.9;
    final double widthBased = width / (densityFactor + 0.6);
    final double heightBased = height / (densityFactor + 1.2);
    final double baseSize = min(widthBased, heightBased);
    final double sizeMultiplier = count <= 3
        ? 1.05
        : count <= 6
        ? 0.95
        : 0.85;
    return (baseSize * sizeMultiplier).clamp(_minItemSize, _maxItemSize);
  }

  void _setDragging(int index, bool isDragging) {
    setState(() {
      if (isDragging) {
        _draggedIndices.add(index);
      } else {
        _draggedIndices.remove(index);
      }
    });
  }

  bool _isIndexCorrect(int index) {
    return index == widget.correctIndex && widget.correctIndex >= 0;
  }

  bool _isChineseText(String text) {
    // 检查字符串是否包含中文字符
    for (final int codeUnit in text.codeUnits) {
      // 中文字符的Unicode范围：\u4e00-\u9fff
      if (codeUnit >= 0x4e00 && codeUnit <= 0x9fff) {
        return true;
      }
    }
    return false;
  }

  double _baseItemSizeForIndex(int index) {
    if (_isIndexCorrect(index)) {
      return _itemSize * 1.2;
    }
    if (widget.usedOptionIndices.contains(index)) {
      return _itemSize;
    }
    return _itemSize * 0.7;
  }

  double _visualScaleForIndex(int index) {
    return _isIndexCorrect(index) ? _scaleAnimation.value : 1.0;
  }

  double _bubbleRadiusForIndex(int index) {
    return (_baseItemSizeForIndex(index) * _visualScaleForIndex(index)) / 2;
  }

  double _touchRadiusForIndex(int index) {
    final double radius = _bubbleRadiusForIndex(index);
    return radius + (_isIndexCorrect(index) ? 18.0 : 0.0);
  }

  Offset _centerFromTopLeft(Offset topLeft, double baseSize) {
    return Offset(topLeft.dx + baseSize / 2, topLeft.dy + baseSize / 2);
  }

  Offset _topLeftFromCenter(Offset center, double baseSize) {
    return Offset(center.dx - baseSize / 2, center.dy - baseSize / 2);
  }

  Offset _clampCenterWithinBounds(Offset center, double baseSize) {
    final Offset topLeft = _topLeftFromCenter(center, baseSize);
    final Offset clampedTopLeft = _clampToBounds(topLeft);
    return _centerFromTopLeft(clampedTopLeft, baseSize);
  }

  double _computeSpeedMultiplier(double itemSize) {
    if (itemSize <= 1e-3) return 1.0;
    final double ratio = _maxItemSize / itemSize;
    return (ratio.clamp(1.0, 2.6)) * 0.25; // 大幅度降低整体速度到原来的1/4
  }

  void _setSpeedMultiplier(double itemSize) {
    final double newMultiplier = _computeSpeedMultiplier(itemSize);
    if ((_speedMultiplier - newMultiplier).abs() <= 1e-3) {
      _speedMultiplier = newMultiplier;
      return;
    }
    final double ratio =
        newMultiplier / (_speedMultiplier <= 1e-6 ? 1.0 : _speedMultiplier);
    for (int i = 0; i < _velocities.length; i += 1) {
      final Offset vel = _velocities[i];
      _velocities[i] = Offset(vel.dx * ratio, vel.dy * ratio);
    }
    _speedMultiplier = newMultiplier;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final int optionCount = widget.options.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (media.size.width - 24);
          // 使用父级提供的所有可用高度
          final double availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : media.size.height * 0.5; // 后备值

          if (optionCount == 0) {
            return SizedBox(height: availableHeight);
          }

          final double itemSize = _computeItemSize(
            width,
            availableHeight - widget.topPadding,
          );
          // 让运动区域占满可用空间
          final double movementHeight = availableHeight - widget.topPadding;
          final Size bounds = Size(
            max(0.0, width - itemSize),
            max(0.0, movementHeight - itemSize),
          );

          _ensureInitialized(bounds, itemSize);

          if (_positions.length != optionCount) {
            return SizedBox(height: availableHeight);
          }

          return SizedBox(
            height: availableHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: widget.topPadding),
                child: SizedBox(
                  width: width,
                  height: movementHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List<Widget>.generate(optionCount, (int index) {
                      final Offset pos = _positions[index];
                      return Positioned(
                        left: pos.dx,
                        top: pos.dy,
                        child: _buildFloatingOption(index),
                      );
                    }),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingOption(int index) {
    final bool isCorrect = _isIndexCorrect(index);
    final bool dragEnabled = widget.canDrag && isCorrect;
    final Color activeColor = index < widget.colors.length
        ? widget.colors[index]
        : Colors.blue.shade500;
    final Color inactiveColor = Colors.grey.shade500;
    final double baseItemSize = _baseItemSizeForIndex(index);

    // 检查是否为中文字符，根据字符长度调整字体倍数
    final String optionText = widget.options[index];
    final bool isChinese = _isChineseText(optionText);
    final int textLength = optionText.length;

    // 根据字符长度动态调整字体倍数
    double baseFontMultiplier = isChinese ? 0.35 : 0.45;
    if (textLength <= 1) {
      baseFontMultiplier = isChinese ? 0.45 : 0.55; // 单字可以使用更大的字体
    } else if (textLength == 2) {
      baseFontMultiplier = isChinese ? 0.40 : 0.50; // 两字适中
    } else if (textLength == 3) {
      baseFontMultiplier = isChinese ? 0.30 : 0.40; // 三字需要缩小
    } else {
      baseFontMultiplier = isChinese ? 0.25 : 0.35; // 四字及以上进一步缩小
    }

    final double fontMultiplier = baseFontMultiplier;
    final double textSize = (baseItemSize * fontMultiplier).clamp(16.0, 48.0);

    final Gradient gradient = isCorrect
        ? LinearGradient(
            colors: <Color>[
              activeColor.withOpacity(0.95),
              activeColor.withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: <Color>[
              inactiveColor.withOpacity(0.65),
              inactiveColor.withOpacity(0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final bool isNewlyCorrect = isCorrect && index == widget.correctIndex;

    final Widget bubble = AnimatedBuilder(
      animation: isNewlyCorrect
          ? _scaleAnimation
          : AlwaysStoppedAnimation<double>(1.0),
      builder: (BuildContext context, Widget? child) {
        final double scale = isNewlyCorrect ? _scaleAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: baseItemSize,
            height: baseItemSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (isCorrect ? activeColor : inactiveColor).withOpacity(
                    0.35,
                  ),
                  blurRadius: isCorrect ? 24 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
              border: isCorrect
                  ? null
                  : Border.all(color: Colors.transparent, width: 0),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.options[index].toLowerCase(),
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(isCorrect ? 0.95 : 0.65),
              ),
            ),
          ),
        );
      },
    );

    if (!dragEnabled) {
      return bubble;
    }

    final _DragLetterPayload payload = _DragLetterPayload(
      optionIndex: index,
      letter: widget.options[index],
    );

    return Draggable<_DragLetterPayload>(
      data: payload,
      dragAnchorStrategy: childDragAnchorStrategy,
      onDragStarted: () => _setDragging(index, true),
      onDragEnd: (_) => _setDragging(index, false),
      onDragCompleted: () => _setDragging(index, false),
      feedback: _buildDragFeedback(
        widget.options[index],
        activeColor,
        baseItemSize,
        _visualScaleForIndex(index),
        isCorrect,
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: bubble,
    );
  }

  Widget _buildDragFeedback(
    String label,
    Color baseColor,
    double baseItemSize,
    double visualScale,
    bool isCorrect,
  ) {
    final double displaySize = baseItemSize * visualScale;
    // 增大拖拽 feedback 的最小尺寸，使拖拽时文字更大更显眼
    final double feedbackSize = max(displaySize, 140.0);

    // 检查是否为中文字符，根据字符长度调整字体倍数
    final bool isChinese = _isChineseText(label);
    final int textLength = label.length;

    // 根据字符长度动态调整字体倍数
    double baseFontMultiplier = isChinese ? 0.30 : 0.38;
    if (textLength <= 1) {
      baseFontMultiplier = isChinese ? 0.38 : 0.46; // 单字可以使用更大的字体
    } else if (textLength == 2) {
      baseFontMultiplier = isChinese ? 0.34 : 0.42; // 两字适中
    } else if (textLength == 3) {
      baseFontMultiplier = isChinese ? 0.26 : 0.34; // 三字需要缩小
    } else {
      baseFontMultiplier = isChinese ? 0.22 : 0.30; // 四字及以上进一步缩小
    }

    // feedback 时适当放大字体倍数，且基于 feedbackSize 计算最终字体
    final double fontMultiplier = baseFontMultiplier * 1.15;
    final double fontSize = (feedbackSize * fontMultiplier).clamp(18.0, 64.0);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: feedbackSize,
        height: feedbackSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: <Color>[
              baseColor.withOpacity(0.95),
              baseColor.withOpacity(0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: baseColor.withOpacity(0.45),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toLowerCase(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: isChinese ? 0.0 : 1.4, // 中文不需要字母间距
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
