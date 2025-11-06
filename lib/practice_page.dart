import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
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

  List<String> get syllableSegments {
    if (word.isEmpty) return <String>[];
    if (syllableBreakpoints == null || syllableBreakpoints!.isEmpty) {
      return <String>[word];
    }

    final List<int> breakpoints = List<int>.from(syllableBreakpoints!)..sort();
    final List<String> segments = <String>[];
    int start = 0;
    for (final int bp in breakpoints) {
      final int clamped = bp.clamp(0, word.length);
      if (clamped <= start) continue;
      segments.add(word.substring(start, clamped));
      start = clamped;
    }
    if (start < word.length) {
      segments.add(word.substring(start));
    }
    return segments.isEmpty ? <String>[word] : segments;
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

class _DashedLine extends StatelessWidget {
  const _DashedLine({
    super.key,
    required this.color,
    this.thickness = 2.0,
    this.dashWidth = 6.0,
    this.gapWidth = 4.0,
  });

  final Color color;
  final double thickness;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxWidth;
        if (available.isInfinite || available <= 0) {
          return SizedBox.shrink();
        }
        final int count = (available / (dashWidth + gapWidth)).floor();
        if (count <= 0) return SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(count, (int i) {
            return Container(
              width: dashWidth,
              height: thickness,
              margin: EdgeInsets.only(right: i == count - 1 ? 0.0 : gapWidth),
              color: color,
            );
          }),
        );
      },
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

enum _AnswerState { none, correct, incorrect, success }

enum _PracticeStage { spelling, syllable, translation, completed }

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
      word: 'beautiful',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'adj.', translation: <String>['美丽', '的']),
      ],
      syllableBreakpoints: <int>[3, 6],
    ),
    PracticeQuestion(
      word: 'dict',
      meanings: <Meaning>[
        Meaning(partOfSpeech: 'n.', translation: <String>['字典', '词典', '辞典']),
        Meaning(partOfSpeech: 'v.', translation: <String>['字典1', '词典2', '辞典3']),
      ],
      syllableBreakpoints: <int>[3],
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
  bool _isSmearCompleted = false; // 当前字母拖拽是否完成
  _PracticeStage _stage = _PracticeStage.spelling;
  final List<String> _translationTokens = <String>[];
  List<String> _syllableSegments = <String>[];
  final List<String> _syllableSelectedSegments = <String>[];
  final List<int> _syllableUsedOptionIndices = <int>[];
  int _syllableProgress = 0;
  final Map<int, Color> _syllableColors = <int, Color>{}; // 每个音节的固定颜色
  final List<String> _selectedMeaningTokens = <String>[];
  final List<int> _translationUsedOptionIndices = <int>[];
  _PracticeStage? _lastOptionsStage;
  bool _isInitialized = false; // 添加初始化标志
  int _currentMeaningIndex = 0; // 当前正在练习的含义索引（如果有多个含义，分成多次练习）
  final List<Meaning> _completedMeanings = <Meaning>[]; // 已完成的词意组列表
  bool _isWaitingBetweenMeanings = false; // 是否正在等待期间（完成一组后等待3秒）
  bool _showColoredWordGroup = false; // 控制拼写完成后中间显示彩色单词
  bool _showZipperOverlay = false; // 拼写完成后是否显示拉链特效（已弃用）
  bool _showWordCompleteCountdown = false; // 控制单词完成后的倒计时显示
  int _countdownSeconds = 3; // 倒计时秒数
  bool _showContinueButton = false; // 控制继续按钮的显示
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
    // 处理当前词义组：第一组包含单词，后续组只包含词性+翻译
    if (_currentMeaningIndex == 0) {
      _translationTokens.add(current.word); // 第一组才添加单词
    }
    if (_currentMeaningIndex < current.meanings.length) {
      final Meaning meaning = current.meanings[_currentMeaningIndex];
      // 当前词义组添加：词性 + 翻译选项
      _translationTokens.add(meaning.partOfSpeech);
      _translationTokens.addAll(meaning.translation);
    }
    _selectedMeaningTokens.clear();
    _translationUsedOptionIndices.clear();
    _lastOptionsStage = null;
  }

  List<String> get _currentSelectedItems {
    if (_stage == _PracticeStage.spelling) return selectedLetters;
    if (_stage == _PracticeStage.syllable) return _syllableSelectedSegments;
    return _selectedMeaningTokens;
  }

  List<int> get _currentUsedIndices {
    if (_stage == _PracticeStage.spelling) return usedOptionIndices;
    if (_stage == _PracticeStage.syllable) return _syllableUsedOptionIndices;
    return _translationUsedOptionIndices;
  }

  List<String> get _currentExpectedItems {
    if (_stage == _PracticeStage.spelling) return current.answerLetters;
    if (_stage == _PracticeStage.syllable) return _syllableSegments;
    return _translationTokens;
  }

  bool get _isTranslationStage => _stage == _PracticeStage.translation;
  bool get _isSyllableStage => _stage == _PracticeStage.syllable;

  Timer? _autoAdvanceTimer;
  final ValueNotifier<bool> _isSnapping = ValueNotifier<bool>(false);
  final ValueNotifier<double> _snapProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isHoveringAnswerArea = ValueNotifier<bool>(false);
  Color _currentMeaningDisplayColor = Colors.grey.shade600; // 当前词义显示颜色
  Color? _previousMeaningDisplayColor;
  bool _wasJustAccepted = false; // 标记最近一次是否执行了 accept
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
          // 重置词义显示颜色为灰色
          _currentMeaningDisplayColor = Colors.grey.shade600;
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
    final List<String> answersList;
    final List<String> selectedList;
    if (_stage == _PracticeStage.spelling) {
      answersList = current.answerLetters;
      selectedList = selectedLetters;
    } else if (_stage == _PracticeStage.syllable) {
      answersList = _syllableSegments;
      selectedList = _syllableSelectedSegments;
    } else {
      answersList = _translationTokens;
      selectedList = _selectedMeaningTokens;
    }

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

    // 对于翻译阶段，最多显示6个选项，陆续添加
    // 对于拼写阶段，只显示剩余的答案
    final List<String> remainingAnswers;
    final List<int> remainingIndices;
    if (_stage == _PracticeStage.translation) {
      remainingAnswers = <String>[];
      remainingIndices = <int>[];
      // 计算当前应该显示的最大选项数量（初始4个，随着拖拽成功逐渐增加，最多6个）
      final int baseDisplayCount = 4; // 初始显示4个选项
      final int additionalCount =
          _selectedMeaningTokens.length ~/ 3; // 每3个成功拖拽增加1个显示选项
      final int maxDisplayCount = (baseDisplayCount + additionalCount).clamp(
        4,
        6,
      ); // 最多6个
      int currentDisplayCount = 0;

      // 添加未使用的选项，最多显示计算出的数量
      for (
        int i = 0;
        i < answersList.length && currentDisplayCount < maxDisplayCount;
        i += 1
      ) {
        // 如果该项已被标记为使用则跳过
        if (_translationUsedOptionIndices.contains(i)) continue;
        // NOTE: 保持已选中的单词在选项区位置不变（不再隐藏已选单词），以满足"成功的单词位置保持不变"的需求
        remainingAnswers.add(answersList[i]);
        remainingIndices.add(i);
        currentDisplayCount++;
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
    if (_isSyllableStage) {
      return _buildSyllableStageCard();
    }

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

    // 翻译阶段的特殊处理：第一行显示单词，第二行显示词性和翻译
    final bool isTranslationWithWordFirst =
        isTranslationStage && _translationTokens.length > 1;
    final List<String> restFilledLetters = isTranslationWithWordFirst
        ? (_selectedMeaningTokens.length > 1
              ? _selectedMeaningTokens.sublist(1)
              : <String>[])
        : <String>[];
    final List<int> restHiddenIndices = isTranslationWithWordFirst
        ? List<int>.generate(
            _translationTokens.length - 1,
            (int index) => index,
          )
        : <int>[];

    final List<String> maskedFilledLetters = isCompletedStage
        ? List<String>.from(_translationTokens)
        : (_selectedMeaningTokens.length == _translationTokens.length &&
                  isTranslationStage
              ? <String>[] // 词义拖拽成功后，下划线区域也不显示文本
              : stageFilledLetters);

    final int totalSlots = stageHiddenIndices.length;

    // 计算已完成的翻译列表（包含 _completedMeanings），每组词义换行显示
    final List<String> completedTranslations = <String>[];
    for (final Meaning meaning in _completedMeanings) {
      // 词性单独一行
      completedTranslations.add(meaning.partOfSpeech);
      // 翻译选项单独一行
      completedTranslations.add(meaning.translation.join(', '));
    }

    // 如果当前组也已完成，临时加入当前组的翻译用于下方展示
    final bool currentGroupCompleted =
        isTranslationStage &&
        _translationTokens.isNotEmpty &&
        _selectedMeaningTokens.length == _translationTokens.length &&
        _currentMeaningIndex < current.meanings.length;
    if (currentGroupCompleted) {
      final Meaning meaning = current.meanings[_currentMeaningIndex];
      // 词性单独一行
      completedTranslations.add(meaning.partOfSpeech);
      // 翻译选项单独一行
      completedTranslations.add(meaning.translation.join(', '));
    }

    // 下方展示只用 completedTranslations，顶部单词直接使用 current.word
    final bool hasCompletedTranslations = completedTranslations.isNotEmpty;
    // completedTranslationsString removed; using completedTranslations list directly
    // 选择用于显示翻译时的颜色：优先使用最后一次拖拽使用的选项颜色
    final int? lastUsedOriginalIndex = _translationUsedOptionIndices.isNotEmpty
        ? _translationUsedOptionIndices.last
        : null;
    // 统一使用默认颜色显示已完成的词义，去除基于拖拽来源的颜色动画/变色效果
    final Color completedDisplayColor = Colors.black87;
    final bool useTranslationTokens =
        (isTranslationStage || isCompletedStage) &&
        _translationTokens.isNotEmpty;
    final String displayWord = useTranslationTokens
        ? (_selectedMeaningTokens.length == _translationTokens.length
              ? '' // 完成时不显示文本，只保留下划线区域
              : _buildTranslationPlaceholder(_translationTokens))
        : current.word;
    // 不再使用 expectedLetters 进行显示，始终保持为 null
    final List<String>? expectedLetters = null;

    Widget buildContent(
      List<_DragLetterPayload?> candidateData,
      bool isHovering,
    ) {
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
                        // 翻译阶段：第一行显示单词，第二行显示词性和翻译
                        if (isTranslationWithWordFirst)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // 第一行：单词 - 直接显示完整单词文本
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedMeaningTokens.length > 0
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedMeaningTokens.length > 0
                                        ? Colors.blue.shade300
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: DragTarget<_DragLetterPayload>(
                                  onWillAccept: (data) =>
                                      data != null &&
                                      _selectedMeaningTokens.isEmpty &&
                                      data.letter == current.word,
                                  onAccept: (data) {
                                    if (_selectedMeaningTokens.isEmpty) {
                                      _cancelAutoAdvance();
                                      setState(() {
                                        _selectedMeaningTokens.add(data.letter);
                                        _translationUsedOptionIndices.add(
                                          activeOptionIndices[activeOptions
                                              .indexOf(data.letter)],
                                        );
                                      });
                                      _prepareOptions();
                                    }
                                  },
                                  builder:
                                      (
                                        BuildContext context,
                                        List<dynamic> candidateData,
                                        List<dynamic> rejectedData,
                                      ) {
                                        return Text(
                                          _selectedMeaningTokens.length > 0
                                              ? _selectedMeaningTokens[0]
                                              : '拖拽单词到这里',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                _selectedMeaningTokens.length >
                                                    0
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade500,
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                ),
                              ),
                              // 第二行：词性和翻译
                              _MaskedWord(
                                word: _buildTranslationPlaceholder(
                                  _translationTokens.sublist(1),
                                ),
                                hiddenIndices: restHiddenIndices,
                                filledLetters: restFilledLetters,
                                userFilledCount: restFilledLetters.length,
                                state: isCompletedStage
                                    ? _AnswerState.success
                                    : answerState,
                                onLetterDropped: _onDropTranslationToken,
                                dropLocked: isDropLocked || !isInteractiveStage,
                                syllableBreakpoints: null,
                                isSnapping: _isSnapping,
                                snapProgress: _snapProgress,
                                nextBlankKey: isInteractiveStage
                                    ? _nextBlankKey
                                    : null,
                                tempWrongIndices: null,
                                expectedLetters:
                                    _selectedMeaningTokens.length > 1
                                    ? _translationTokens.sublist(1)
                                    : null,
                                isTranslationStage: true,
                              ),
                            ],
                          )
                        else
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
                            _stage != _PracticeStage.spelling &&
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
                        if (_showColoredWordGroup &&
                            _stage != _PracticeStage.spelling)
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
                        // 在拼写阶段也在答案区下方显示词义（每组一行，便于复习）
                        if (_stage == _PracticeStage.spelling)
                          ValueListenableBuilder<bool>(
                            valueListenable: _isHoveringAnswerArea,
                            builder:
                                (
                                  BuildContext context,
                                  bool isHovering,
                                  Widget? child,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 20.0,
                                      bottom: 8.0,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: current.meanings.map((
                                          Meaning m,
                                        ) {
                                          // 根据hover状态确定颜色
                                          final Color displayColor = isHovering
                                              ? (_optionColorsFull.isNotEmpty
                                                    ? _optionColorsFull[candidateData
                                                              .first!
                                                              .optionIndex %
                                                          _optionColorsFull
                                                              .length]
                                                    : _optionColorPalette[0])
                                              : _currentMeaningDisplayColor;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2.0,
                                            ),
                                            child: Text(
                                              "${m.partOfSpeech} ${m.translation.join('、')}",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w600,
                                                color: displayColor,
                                                letterSpacing: 0.0,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                          ),
                        if (currentGroupCompleted &&
                            _stage != _PracticeStage.spelling)
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
                        else if (hasCompletedTranslations &&
                            _stage != _PracticeStage.spelling)
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
      return buildContent(<_DragLetterPayload>[], false);
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
            // 标记最近一次为 accept，以便 builder 在接受后不立刻还原颜色
            _wasJustAccepted = true;
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
                // 更新悬停状态并更新颜色（先计算颜色再通知监听器，确保 UI 使用最新颜色）
                final bool isHovering = candidateData.isNotEmpty;

                if (isHovering && candidateData.isNotEmpty) {
                  // 保存之前的颜色以便在未放手返回时还原
                  _previousMeaningDisplayColor = _currentMeaningDisplayColor;

                  final int payloadIndex = candidateData.last!.optionIndex;
                  int originalIndex;
                  if (activeOptionIndices.contains(payloadIndex)) {
                    originalIndex = payloadIndex;
                  } else if (payloadIndex >= 0 &&
                      payloadIndex < activeOptionIndices.length) {
                    originalIndex = activeOptionIndices[payloadIndex];
                  } else {
                    originalIndex = payloadIndex;
                  }

                  _currentMeaningDisplayColor =
                      _optionColorsFull.isNotEmpty &&
                          originalIndex >= 0 &&
                          originalIndex < _optionColorsFull.length
                      ? _optionColorsFull[originalIndex]
                      : _optionColorPalette[0];
                } else {
                  // 非悬停：如果刚刚是 accept，则保持当前颜色，否则恢复之前的颜色
                  if (_wasJustAccepted) {
                    // 重置标记，下次离开时按正常逻辑处理
                    _wasJustAccepted = false;
                  } else {
                    _currentMeaningDisplayColor =
                        _previousMeaningDisplayColor ?? Colors.grey.shade600;
                  }
                }

                // 最后通知监听器使 UI 重建并读取最新颜色
                _isHoveringAnswerArea.value = isHovering;

                return buildContent(candidateData, isHovering);
              },
        ),
      ],
    );
  }

  Widget _buildSyllableStageCard() {
    // 确保只显示非空字符串的音节段
    final List<String> segments = _syllableSegments.isNotEmpty
        ? _syllableSegments.where((String s) => s.trim().isNotEmpty).toList()
        : current.syllableSegments
              .where((String s) => s.trim().isNotEmpty)
              .toList();
    final String word = current.word;
    final int wordLen = word.length;
    final double baseFontSize = _computeBaseFontSizeForWord(word);

    return DragTarget<_DragLetterPayload>(
      // 整个音节答案区都可接收拖拽（与单词答案区行为一致）
      onWillAccept: (data) {
        // 仅在音节阶段、未锁定且仍有未填充分段时允许接收
        return data != null &&
            _isSyllableStage &&
            !isDropLocked &&
            _syllableProgress < segments.length;
      },
      onAccept: (data) {
        // 标记最近一次为 accept，以便 builder 在接受后不立刻还原颜色
        _wasJustAccepted = true;
        // 将接收到的拖拽项交由音节处理函数处理
        _onDropSyllableSegment(data);
      },
      onMove: (details) {
        // 保持与非音节区域一致的滚动行为，确保下一个空位可见
        _scrollToFirstBlank();
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
            // 更新悬停状态并更新颜色（先计算颜色再通知监听器，确保 UI 使用最新颜色）
            final bool isHovering = candidateData.isNotEmpty;

            if (isHovering && candidateData.isNotEmpty) {
              // 保存之前的颜色以便在未放手返回时还原
              _previousMeaningDisplayColor = _currentMeaningDisplayColor;

              final int payloadIndex = candidateData.last!.optionIndex;
              int originalIndex;
              if (activeOptionIndices.contains(payloadIndex)) {
                originalIndex = payloadIndex;
              } else if (payloadIndex >= 0 &&
                  payloadIndex < activeOptionIndices.length) {
                originalIndex = activeOptionIndices[payloadIndex];
              } else {
                originalIndex = payloadIndex;
              }

              _currentMeaningDisplayColor =
                  _optionColorsFull.isNotEmpty &&
                      originalIndex >= 0 &&
                      originalIndex < _optionColorsFull.length
                  ? _optionColorsFull[originalIndex]
                  : _optionColorPalette[0];
            } else {
              // 非悬停：如果刚刚是 accept，则保持当前颜色，否则恢复之前的颜色
              if (_wasJustAccepted) {
                // 重置标记，下次离开时按正常逻辑处理
                _wasJustAccepted = false;
              } else {
                _currentMeaningDisplayColor =
                    _previousMeaningDisplayColor ?? Colors.grey.shade600;
              }
            }

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 8,
                    children: <Widget>[
                      for (int i = 0; i < segments.length; i++) ...<Widget>[
                        _buildSyllableSegmentTile(
                          i,
                          segments[i],
                          baseFontSize,
                          isHovering,
                        ),
                        if (i < segments.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: baseFontSize * 0.9,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                  // 在音节阶段也在答案区下方显示词义（每组一行，与单词拖拽模块逻辑一致）
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: current.meanings.map((Meaning m) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              "${m.partOfSpeech} ${m.translation.join('、')}",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                                color: _currentMeaningDisplayColor,
                                letterSpacing: 0.0,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }

  // 计算用于音节显示与单词显示的基础字体大小，保持两处一致
  double _computeBaseFontSizeForWord(String word) {
    const double scale = 0.88; // 全局字体缩放（整体略微变小）
    final int wordLen = word.length;
    double base;
    if (wordLen <= 4) {
      base = 52;
    } else if (wordLen <= 6) {
      base = 58;
    } else if (wordLen <= 8) {
      base = 54;
    } else if (wordLen <= 10) {
      base = 50;
    } else {
      base = 56;
    }
    return (base * scale);
  }

  Widget _buildSyllableSegmentTile(
    int index,
    String segment,
    double baseFontSize,
    bool isHovering,
  ) {
    final bool isCompleted = index < _syllableProgress;
    final bool isActive = index == _syllableProgress;

    // 计算基础尺寸（与单词拖拽选项一致）
    final double baseItemSize = baseFontSize * 1.5;
    final double textSize = baseFontSize * 0.8;

    // 颜色方案：未完成的用灰色，已完成的用绿色
    final Color activeColor = isCompleted
        ? Colors.green.shade500
        : Colors.grey.shade400;
    final Color inactiveColor = Colors.grey.shade300;

    final Gradient gradient = isCompleted || (isActive && segment.isNotEmpty)
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

    return DragTarget<_DragLetterPayload>(
      onWillAccept: (payload) {
        if (!_isSyllableStage || !isActive) return false;
        if (payload == null) return false;
        return payload.letter.toLowerCase() == segment.toLowerCase();
      },
      onAccept: (payload) => _onDropSyllableSegment(payload),
      builder:
          (
            BuildContext context,
            List<_DragLetterPayload?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final bool isHovering = candidateData.isNotEmpty;
            final bool isCorrect =
                isCompleted || (isActive && segment.isNotEmpty);

            // 使用与答案区一致的下划线样式（不是圆形），与单词完成后的显示保持一致
            final Color textColor;
            if (isCompleted) {
              // 使用该音节的固定颜色，如果没有则使用默认绿色
              textColor = _syllableColors[index] ?? Colors.green.shade600;
            } else if (isHovering && isActive) {
              // 悬停时使用选项的颜色，与词义颜色保持一致
              textColor = _currentMeaningDisplayColor;
            } else {
              textColor = Colors.grey.shade500;
            }
            final Color borderColor = isCompleted
                ? Colors.green.shade400
                : Colors.grey.shade300;

            // 仅显示文本（无下划线），分组间用 '-' 连接，由父级负责插入分隔符
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              child: Text(
                segment.toLowerCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: baseFontSize,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.1,
                  height: 1.0,
                ),
              ),
            );
          },
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
            final int correctIndex;
            if (_stage == _PracticeStage.syllable && expectedItem != null) {
              // 对于音节阶段，activeOptions 只包含还未填写的音节，第一个就是当前应该填写的
              correctIndex = 0;
            } else {
              correctIndex = expectedItem == null
                  ? -1
                  : activeOptions
                            .asMap()
                            .entries
                            .where((MapEntry<int, String> entry) {
                              // 计算该候选在原始 answersList 中的绝对索引
                              final int originalIndex =
                                  (entry.key < activeOptionIndices.length)
                                  ? activeOptionIndices[entry.key]
                                  : entry.key;
                              // 跳过已使用的选项（使用绝对索引比较）
                              if (_currentUsedIndices.contains(originalIndex)) {
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
            }
            final bool showZipper =
                _showZipperOverlay && _stage == _PracticeStage.spelling;

            Widget stageContent;
            if (_stage == _PracticeStage.spelling) {
              final String currentLetter = (expectedItem ?? '').trim();
              Color letterColor;
              if (optionColors.isNotEmpty) {
                if (correctIndex >= 0 && correctIndex < optionColors.length) {
                  letterColor = optionColors[correctIndex];
                } else {
                  letterColor = optionColors.first;
                }
              } else {
                letterColor = Theme.of(context).colorScheme.primary;
              }
              stageContent = _LetterDragSelection(
                expectedLetter: currentLetter,
                isCompleted: _isSmearCompleted,
                activeColor: letterColor,
                onLetterMatched: _onLetterMatched,
              );
            } else {
              stageContent = Padding(
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
                  isTranslationStage: _isTranslationStage,
                  optionIndices: activeOptionIndices,
                  wordCompleted:
                      _currentMeaningIndex > 0 ||
                      _selectedMeaningTokens.contains(current.word),
                  baseFontSize: _computeBaseFontSizeForWord(current.word),
                ),
              );
            }

            return Stack(
              children: <Widget>[
                stageContent,
                if (showZipper)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildZipperOverlay(),
                    ),
                  ),
                if (_showWordCompleteCountdown || _showContinueButton)
                  Positioned.fill(
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // 固定高度容器：无论是倒计时数字还是圆形箭头，均占用相同高度，
                            // 以避免倒计时结束后提示文字上移
                            SizedBox(
                              height: 80.0,
                              child: Center(
                                child: _showWordCompleteCountdown
                                    ? Text(
                                        '$_countdownSeconds',
                                        style: const TextStyle(
                                          fontSize: 56,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : (_showContinueButton
                                          ? GestureDetector(
                                              onTap: _onContinueButtonPressed,
                                              child: Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  shape: BoxShape.circle,
                                                  boxShadow: <BoxShadow>[
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.08),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.arrow_forward,
                                                  size: 28,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink()),
                              ),
                            ),

                            // 提醒文字：让用户先思考单词含义后再继续
                            if (_showWordCompleteCountdown ||
                                _showContinueButton)
                              const Padding(
                                padding: EdgeInsets.only(top: 12.0),
                                child: Text(
                                  '先想想单词意思',
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
    // 拉链特效已移除，直接返回空容器
    return const SizedBox.shrink();
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
    if (_stage == _PracticeStage.syllable) {
      _handleSyllableSelection(optionIndex, letter);
      return;
    }
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
          setState(() {
            answerState = _AnswerState.success;
            _resetScrollFlag(); // 成功时重置滚动标志
            // 去除彩色单词动画效果，直接显示完成的单词
            // _showColoredWordGroup = true;
          });

          _beginPostSpellingFlow();
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
      _syllableSegments = <String>[];
      _syllableSelectedSegments.clear();
      _syllableUsedOptionIndices.clear();
      _syllableProgress = 0;
      _syllableColors.clear();
      activeOptionIndices = <int>[];
      _showColoredWordGroup = false;
      _showZipperOverlay = false;
      // 开始翻译阶段
    });
    _prepareOptions();
  }

  void _beginPostSpellingFlow() {
    final List<String> segments = current.syllableSegments;
    final bool hasMultipleSegments =
        segments.where((String s) => s.trim().isNotEmpty).length > 1;

    if (!hasMultipleSegments) {
      _syllableSegments = <String>[];
      _syllableSelectedSegments.clear();
      _syllableUsedOptionIndices.clear();
      _syllableProgress = 0;
      _syllableColors.clear();
      _beginTranslationCountdown();
      return;
    }

    setState(() {
      _stage = _PracticeStage.syllable;
      // 过滤掉空字符串的音节段，确保显示的音节块数量与进度跟踪一致
      _syllableSegments = segments
          .where((String s) => s.trim().isNotEmpty)
          .toList();
      _syllableSelectedSegments.clear();
      _syllableUsedOptionIndices.clear();
      _syllableProgress = 0;
      _syllableColors.clear(); // 清空音节颜色映射
      _showWordCompleteCountdown = false;
      _showContinueButton = false;
      isDropLocked = false;
    });
    _prepareOptions();
  }

  void _beginTranslationCountdown() {
    setState(() {
      _showWordCompleteCountdown = true;
      _countdownSeconds = 3;
      _showContinueButton = false;
      activeOptions = <String>[];
      activeOptionIndices = <int>[];
    });
    _startWordCompleteCountdown();
  }

  void _startWordCompleteCountdown() {
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        setState(() {
          _showWordCompleteCountdown = false;
          _showContinueButton = true;
        });
      }
    });
  }

  void _onSyllableStageCompleted() {
    if (_stage != _PracticeStage.syllable) return;
    if (_syllableProgress < _syllableSegments.length) return;

    setState(() {
      activeOptions = <String>[];
      activeOptionIndices = <int>[];
    });

    _beginTranslationCountdown();
  }

  void _onContinueButtonPressed() {
    setState(() {
      _showContinueButton = false;
    });
    _transitionAfterWordSolved();
  }

  void _onLetterMatched(String letter) {
    if (_stage == _PracticeStage.spelling &&
        selectedLetters.length < current.hiddenIndices.length) {
      // 获取当前应该填写的字母
      final int nextOrder = selectedLetters.length;
      final int nextIndex = current.hiddenIndices[nextOrder];
      final String expected = current.word[nextIndex];

      if (letter.toLowerCase() == expected.toLowerCase()) {
        // 匹配正确，添加到答案中
        _cancelAutoAdvance();
        setState(() {
          selectedLetters.add(letter);
          usedOptionIndices.add(0); // 模拟添加一个使用的索引
          _isSmearCompleted = true; // 标记拖拽完成
        });

        // 更新候选显示
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
              setState(() {
                answerState = _AnswerState.success;
                _resetScrollFlag();
                _isSmearCompleted = false; // 重置拖拽状态为下一题准备
              });
              _beginPostSpellingFlow();
            } else {
              _cancelAutoAdvance();
              setState(() {
                selectedLetters.clear();
                usedOptionIndices.clear();
                answerState = _AnswerState.none;
                _resetScrollFlag();
                _isSmearCompleted = false; // 重置拖拽状态
              });
              _prepareOptions();
            }
          });
        } else {
          // 如果还没完成整个单词，短暂延迟后重置拖拽状态，准备下一个字母
          Future<void>.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _isSmearCompleted = false; // 重置拖拽状态，准备下一个字母
              });
            }
          });
        }
      }
    }
  }

  void _handleSyllableSelection(int optionIndex, String segment) {
    if (_stage != _PracticeStage.syllable) return;
    if (_syllableSegments.isEmpty) return;

    final int expectedIndex = _syllableProgress;
    if (expectedIndex >= _syllableSegments.length) return;

    final String expectedSegment = _syllableSegments[expectedIndex];
    if (segment.toLowerCase() != expectedSegment.toLowerCase()) {
      return;
    }

    final int absoluteIndex =
        (optionIndex >= 0 && optionIndex < activeOptionIndices.length)
        ? activeOptionIndices[optionIndex]
        : expectedIndex;

    _cancelAutoAdvance();
    setState(() {
      _syllableSelectedSegments.add(expectedSegment);
      _syllableUsedOptionIndices.add(absoluteIndex);
      _syllableProgress = expectedIndex + 1;
      // 保存该音节的固定颜色
      _syllableColors[expectedIndex] = _currentMeaningDisplayColor;
    });
    _prepareOptions();

    if (_syllableProgress >= _syllableSegments.length) {
      _onSyllableStageCompleted();
    }
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

    // 如果拖拽的是单词（第一组的第一个token），我们希望：
    // - 在左侧显示已选单词（添加到 _selectedMeaningTokens）
    // - 保持该单词在选项区的位置不变（不要将其标记为已用并从选项中移除）
    // - 直接进入音节阶段（若有多音节），因此跳过常规的 _prepareOptions 调整
    final bool isWholeWordToken = (_currentMeaningIndex == 0 && nextIndex == 0);
    if (isWholeWordToken) {
      setState(() {
        _selectedMeaningTokens.add(token);
        // 注意：此处不将 originalIndex 添加到 _translationUsedOptionIndices，以保持选项位置不变
      });
      // 直接进入后续的音节流程（与拼写成功后的行为一致）
      _beginPostSpellingFlow();
      return;
    }

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

  void _onDropSyllableSegment(_DragLetterPayload payload) {
    if (!_isSyllableStage) return;
    int optionIndex = payload.optionIndex;
    final String segment = payload.letter;

    if (optionIndex < 0 || optionIndex >= activeOptions.length) {
      optionIndex = activeOptions.indexOf(segment);
      if (optionIndex == -1) return;
    }

    _handleSyllableSelection(optionIndex, segment);
  }

  void _completeTranslationStage() {
    if (_stage != _PracticeStage.translation) return;

    // 将当前完成的词意组添加到已完成列表
    if (_currentMeaningIndex < current.meanings.length) {
      _completedMeanings.add(current.meanings[_currentMeaningIndex]);
    }

    // 检查是否还有更多词义组需要处理
    if (_currentMeaningIndex < current.meanings.length - 1) {
      // 还有更多词义组，继续处理下一个
      setState(() {
        _currentMeaningIndex++;
        _selectedMeaningTokens.clear();
        _translationUsedOptionIndices.clear();
        _isWaitingBetweenMeanings = true;
        isDropLocked = true; // 短暂禁用拖拽，准备下一组
      });

      // 短暂延迟后开始下一组（0.5秒）
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _initializeTranslationStage(); // 初始化下一组
        setState(() {
          // 重置状态，准备下一组
          _selectedMeaningTokens.clear();
          _translationUsedOptionIndices.clear();
          _lastOptionsStage = null;
          answerState = _AnswerState.none;
          isDropLocked = false; // 确保拖拽被启用
          _isWaitingBetweenMeanings = false;
          activeOptionIndices = <int>[];
          activeOptions = <String>[]; // 清空选项，确保_prepareOptions能正确填充
        });
        _prepareOptions(); // 更新选项区
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
    if (_isSyllableStage) {
      _onDropSyllableSegment(payload);
      return;
    }
    if (_isTranslationStage) {
      _onDropTranslationToken(payload);
      return;
    }
    // 计算当前应填的目标字母
    final int nextOrder = selectedLetters.length;
    if (nextOrder >= current.hiddenIndices.length) return;

    // payload.optionIndex 现在为原始索引（originalIndex），需要映射到当前 activeOptions 的本地索引
    final int originalIndexFromPayload = payload.optionIndex;
    int currentIndex = -1;
    if (activeOptionIndices.isNotEmpty) {
      currentIndex = activeOptionIndices.indexOf(originalIndexFromPayload);
    }
    // 如果未能通过 mapping 找到本地索引，则尝试把 payload.optionIndex 当作本地索引使用（向下兼容）
    if (currentIndex == -1) currentIndex = originalIndexFromPayload;

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
        // 重置词义显示颜色为灰色
        _currentMeaningDisplayColor = Colors.grey.shade600;
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
        _showWordCompleteCountdown = false;
        _showContinueButton = false;
        _countdownSeconds = 3;
        _syllableSegments = <String>[];
        _syllableSelectedSegments.clear();
        _syllableUsedOptionIndices.clear();
        _syllableProgress = 0;
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

    final TextStyle visibleStyle = GoogleFonts.kalam(
      fontSize: baseFontSize,
      fontWeight: FontWeight.w900,
      color: Colors.black87,
      letterSpacing: isTranslationStage ? 0.0 : 0.8, // 中文不需要字母间距，英文间距调整
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
    bool? currentIsWordLetter; // 记录当前blank是否是单词字母（单个字符）

    for (int i = 0; i < word.length; i += 1) {
      final bool isHidden = hiddenIndices.contains(i);
      if (isHidden) {
        final int blankOrder = fillCursor;
        final String expectedValue =
            (expectedLetters != null && blankOrder < expectedLetters!.length)
            ? expectedLetters![blankOrder]
            : word[i];
        // 判断是否是单个字母（翻译阶段的单个字符使用更小的间距）
        currentIsWordLetter = isTranslationStage && expectedValue.length == 1;
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
        // 翻译阶段根据意思组长度动态调整宽度，否则根据基础字体计算宽度以避免被边框裁切
        final double cellWidth = isTranslationStage
            ? (expectedValue.length == 1
                  ? 50.0 // 单个字母宽度适中，与字体大小匹配
                  : (expectedLetters != null &&
                            blankOrder < expectedLetters!.length
                        ? (expectedLetters![blankOrder].length * 25.0 + 50.0)
                              .clamp(100.0, 250.0)
                        : 100.0))
            : max(30.0, baseFontSize * 1.2); // 基于字体计算宽度，避免被边框遮挡

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
          blankOrder: blankOrder,
          userFilledCount: userFilledCount,
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
            syllableBreakpoints!.contains(i + 1)) {
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
        // 非hidden位置重置标志
        currentIsWordLetter = null;
        // if this visible letter is to the left of the user's first-unfilled index,
        // keep it green; otherwise keep original color
        if (i < firstUnfilledHiddenUser) {
          children.add(
            Text(
              word[i],
              style: visibleStyle.copyWith(
                color: highlightColor,
                letterSpacing: 0.0, // reduce spacing for left-side letters
              ),
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
            syllableBreakpoints!.contains(i + 1)) {
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
      // 翻译阶段使用更大的间距来分隔意思组，单个字母间距适中
      if (i != word.length - 1) {
        children.add(
          SizedBox(
            width: isTranslationStage
                ? (currentIsWordLetter == true ? 6.0 : 16.0) // 单个字母间距适中，提高可读性
                : 4.0,
          ),
        );
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
    required this.blankOrder,
    required this.userFilledCount,
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
  final int blankOrder;
  final int userFilledCount;

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
          final double uniformHeight = widget.isTranslationStage
              ? 100.0 // 翻译阶段减少高度，让下划线更靠近单词
              : 90.0; // 拼写阶段减少高度，让下划线更靠近单词
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
          final double rawLetterOffset = widget.isTranslationStage
              ? ((uniformHeight / 2 - widget.baseFontSize) * factor).clamp(
                  6.0,
                  36.0,
                ) // 翻译阶段下划线在中间
              : ((uniformHeight - widget.baseFontSize) * factor).clamp(
                  6.0,
                  36.0,
                ); // 拼写阶段保持底部
          // 进一步缩小字母与下划线之间的间距，让字母更靠近下划线
          final double letterOffset = max(1.0, rawLetterOffset - 12.0);
          final double cellWidth = widget.width ?? 80.0;

          return Transform.scale(
            scale: shouldAnimate ? _bounceAnimation.value : 1.0,
            child: Container(
              width: cellWidth,
              height: uniformHeight,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: Colors.transparent,
                // 保留下划线占位但隐藏颜色，防止完成后布局抖动
                border: Border(
                  bottom: BorderSide(
                    color: Colors.transparent,
                    width: widget.isTranslationStage ? 1.5 : 2.5,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: letterOffset),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildAnimatedLetter(
                    isWrongLetter: isWrongLetter,
                    isCorrectLetter: isCorrectLetter,
                    letter: widget.letter!,
                    isFinalized: true,
                    isTranslationStage: widget.isTranslationStage,
                    useWordStyling: widget.isTranslationStage,
                    isFilledLeft:
                        widget.isTranslationStage &&
                        widget.blankOrder < widget.userFilledCount,
                  ),
                ),
              ),
            ),
          );
        }

        // 所有单词使用统一的容器高度，确保下划线对齐
        final double uniformHeight = widget.isTranslationStage
            ? 100.0 // 翻译阶段减少高度，让下划线更靠近单词
            : 90.0; // 拼写阶段减少高度，让下划线更靠近单词
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
        final double rawLetterOffset = widget.isTranslationStage
            ? ((uniformHeight / 2 - widget.baseFontSize) * factor).clamp(
                6.0,
                36.0,
              ) // 翻译阶段下划线在中间
            : ((uniformHeight - widget.baseFontSize) * factor).clamp(
                6.0,
                36.0,
              ); // 拼写阶段保持底部
        final double letterOffset = max(1.0, rawLetterOffset - 12.0);

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
                                useWordStyling: widget.isTranslationStage,
                                isFilledLeft:
                                    widget.isTranslationStage &&
                                    widget.blankOrder < widget.userFilledCount,
                              ),
                      ),
                    ),
                  )
                : Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      // 仅当格子为空时显示下划线边框，已显示字母时隐藏边框以避免遮挡
                      border: isEmpty
                          ? Border(
                              bottom: BorderSide(
                                color: widget.isNextBlank
                                    ? baseBorderColor
                                    : Colors.grey.shade300,
                                width: widget.isNextBlank ? 2.5 : 1.5,
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
                                useWordStyling: widget.isTranslationStage,
                                isFilledLeft:
                                    widget.isTranslationStage &&
                                    widget.blankOrder < widget.userFilledCount,
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
    bool useWordStyling = false,
    bool isFilledLeft = false,
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
      // 非翻译阶段：无论是否 finalized，都使用与 finalized 相同的字体大小，
      // 避免放置过程中字体过大被边框遮挡，且确保与放置后的字体一致
      fontSize = widget.baseFontSize * 1.2;
    }

    final Color textColor = useWordStyling
        ? Colors.blue.shade700
        : (isCorrectLetter
              ? Colors.green.shade600
              : (isWrongLetter
                    ? Colors.red
                    : (_colorAnimation.value ?? Colors.black87)));

    Widget content = Text(
      letter.toLowerCase(),
      style: TextStyle(
        fontSize: useWordStyling ? 22.0 : fontSize, // 增大字体大小以提高可读性
        fontWeight: useWordStyling ? FontWeight.w600 : FontWeight.w800,
        color: textColor,
        letterSpacing: useWordStyling
            ? (isFinalized
                  ? (isFilledLeft ? 0.05 : 0.18) // 拖拽完成后，左边字体字间距更小
                  : 0.02) // 拖拽未完成时几乎无间距，完成后保持较小间距
            : 0.1,
        height: 1.1, // 增加行高以提高可读性
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
    this.isTranslationStage = false,
    this.optionIndices = const <int>[],
    this.wordCompleted = false,
    this.baseFontSize,
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
  final bool isTranslationStage;
  final List<int> optionIndices;
  final bool wordCompleted;
  final double? baseFontSize;

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

        final double overlap = collisionDistance - distance;
        final double moveI = overlap / 2;
        final double moveJ = overlap / 2;

        centerI = _clampCenterWithinBounds(
          centerI - direction * moveI,
          baseSizeI,
        );
        centerJ = _clampCenterWithinBounds(
          centerJ + direction * moveJ,
          baseSizeJ,
        );

        // 交换速度向量
        final Offset temp = _velocities[i];
        _velocities[i] = _velocities[j];
        _velocities[j] = temp;

        _positions[i] = _topLeftFromCenter(centerI, baseSizeI);
        _positions[j] = _topLeftFromCenter(centerJ, baseSizeJ);

        // Secondary check in case clamping caused residual overlap
        final Offset updatedDelta = centerJ - centerI;
        final double updatedDistance = updatedDelta.distance;
        if (updatedDistance < collisionDistance) {
          final Offset dir = updatedDistance <= 1e-6
              ? _randomUnitVector()
              : updatedDelta / updatedDistance;
          final double extra = collisionDistance - updatedDistance;
          // 平均分开移动
          centerI = _clampCenterWithinBounds(
            centerI - dir * (extra / 2),
            baseSizeI,
          );
          centerJ = _clampCenterWithinBounds(
            centerJ + dir * (extra / 2),
            baseSizeJ,
          );
          _positions[i] = _topLeftFromCenter(centerI, baseSizeI);
          _positions[j] = _topLeftFromCenter(centerJ, baseSizeJ);
        }
      }
    }
  }

  Offset _clampToBounds(Offset value) {
    final double maxX = max(0.0, _movementBounds.width);
    final double maxY = max(0.0, _movementBounds.height);
    // 使用较小的碰撞内边距，避免与外部的 topPadding 重复导致上下不对称
    double inset = _collisionPadding;
    // 限制 inset 不超过边界的一半
    final double halfMaxX = maxX / 2.0;
    final double halfMaxY = maxY / 2.0;
    if (inset > halfMaxX) inset = halfMaxX;
    if (inset > halfMaxY) inset = halfMaxY;

    double minX = inset;
    double maxAllowedX = maxX - inset;
    double minY = inset;
    double maxAllowedY = maxY - inset;
    if (maxAllowedX < minX) {
      minX = 0.0;
      maxAllowedX = maxX;
    }
    if (maxAllowedY < minY) {
      minY = 0.0;
      maxAllowedY = maxY;
    }

    return Offset(
      value.dx.clamp(minX, maxAllowedX),
      value.dy.clamp(minY, maxAllowedY),
    );
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
    return (ratio.clamp(1.0, 2.6)) * 0.175; // 降低30%速度 (0.25 * 0.7)
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
          // 增加水平方向保留空间，避免长方形选项超出右边界；垂直方向保持与顶部一致
          const double horizontalSafetyFactor = 1.5; // 水平方向允许更宽的选项
          const double verticalSafetyFactor = 1.0; // 保持原始高度范围
          final Size bounds = Size(
            max(0.0, width - itemSize * horizontalSafetyFactor),
            max(0.0, movementHeight - itemSize * verticalSafetyFactor),
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

    // 检查是否为翻译阶段的第一个选项（单词）
    final bool isWordOption =
        widget.isTranslationStage &&
        widget.optionIndices.isNotEmpty &&
        index < widget.optionIndices.length &&
        widget.optionIndices[index] == 0;

    // 检查单词是否已经被拖拽成功（用于样式改变）
    final bool isWordCompleted = isWordOption && widget.wordCompleted;

    // 计算是否可拖拽：
    // - 如果 widget 不允许拖拽，均不可拖拽
    // - 翻译阶段：若该选项对应的原始索引尚未被使用则可拖拽（单词完成后仅禁止该单词自身继续被拖拽）
    // - 拼写阶段：只有正确项可拖拽
    bool dragEnabled;
    if (!widget.canDrag) {
      dragEnabled = false;
    } else if (widget.isTranslationStage) {
      final int originalIndex = (index < widget.optionIndices.length)
          ? widget.optionIndices[index]
          : index;
      dragEnabled = !widget.usedOptionIndices.contains(originalIndex);
      if (isWordOption && isWordCompleted) {
        // 仅禁止该单词项自身继续被拖拽，其他项仍可拖拽
        dragEnabled = false;
      }
    } else {
      dragEnabled = isCorrect;
    }
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

    // 对单词选项适当放大基础倍数以提高可读性
    double fontMultiplier = baseFontMultiplier;
    if (isWordOption) fontMultiplier *= 1.35; // 单词显示更大
    final double maxFontSize = isWordOption ? 72.0 : 48.0;
    final double textSize = (widget.baseFontSize != null && isWordOption)
        ? widget.baseFontSize!.clamp(14.0, maxFontSize)
        : (baseItemSize * fontMultiplier).clamp(14.0, maxFontSize);

    final Gradient gradient = isWordCompleted
        ? LinearGradient(
            colors: <Color>[
              Colors.green.shade600.withOpacity(0.95),
              Colors.green.shade400.withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isCorrect
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
          child: isWordOption
              ? IntrinsicWidth(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    constraints: BoxConstraints(
                      minWidth: baseItemSize * 0.8,
                      maxWidth: baseItemSize * 1.2, // 限制最大宽度，避免超出边框
                      minHeight: baseItemSize * 0.7,
                      maxHeight: baseItemSize * 0.7,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(12),
                      gradient: gradient,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (isCorrect ? activeColor : inactiveColor)
                              .withOpacity(0.35),
                          blurRadius: isCorrect ? 24 : 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: isCorrect
                          ? null
                          : Border.all(color: Colors.transparent, width: 0),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.options[index].toLowerCase(),
                        style: TextStyle(
                          fontSize: textSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withOpacity(
                            isCorrect ? 0.95 : 0.65,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: baseItemSize,
                  height: baseItemSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (isCorrect ? activeColor : inactiveColor)
                            .withOpacity(0.35),
                        blurRadius: isCorrect ? 24 : 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: isCorrect
                        ? null
                        : Border.all(color: Colors.transparent, width: 0),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.options[index].toLowerCase(),
                      style: TextStyle(
                        fontSize: textSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(
                          isCorrect ? 0.95 : 0.65,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        );
      },
    );

    // 移除拖拽功能，直接返回bubble
    return bubble;
  }
}

class _LetterDragSelection extends StatefulWidget {
  const _LetterDragSelection({
    required this.expectedLetter,
    required this.activeColor,
    required this.onLetterMatched,
    required this.isCompleted,
  });

  final String expectedLetter;
  final Color activeColor;
  final ValueChanged<String> onLetterMatched;
  final bool isCompleted;

  @override
  State<_LetterDragSelection> createState() => _LetterDragSelectionState();
}

class _LetterDragSelectionState extends State<_LetterDragSelection> {
  static const double _badgeSize = 180;
  static const Offset _defaultFeedbackOffset = Offset(0, -15);
  static const double _coverageThreshold = 0.9;

  bool _isDragging = false;
  bool _hasMatched = false;
  bool _isLetterCoveringTarget = false;

  Offset? _dragPointerOffset;
  Offset? _latestGlobalDragPosition;
  final GlobalKey _targetKey = GlobalKey();
  final GlobalKey _sourceKey = GlobalKey(); // 添加源位置的key
  bool _isAutoSnapped = false;
  Color? _currentDraggingColor; // 当前拖拽项颜色，用于目标处显示一致颜色
  OverlayEntry? _dragOverlayEntry;
  final ValueNotifier<Offset?> _overlayPositionNotifier =
      ValueNotifier<Offset?>(null);
  bool _overlayLockedToTarget = false;
  double? _fixedVerticalPosition; // 固定垂直位置

  @override
  void didUpdateWidget(covariant _LetterDragSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool letterChanged =
        widget.expectedLetter.toLowerCase() !=
        oldWidget.expectedLetter.toLowerCase();
    if (letterChanged || (!widget.isCompleted && oldWidget.isCompleted)) {
      _hasMatched = false;
      _isLetterCoveringTarget = false;
      _dragPointerOffset = null;
      _latestGlobalDragPosition = null;
      _isAutoSnapped = false;
      _removeOverlay();
      _currentDraggingColor = null;
      _fixedVerticalPosition = null; // 重置固定垂直位置
    }
    if (widget.expectedLetter.isEmpty) {
      _hasMatched = false;
      _isLetterCoveringTarget = false;
      _dragPointerOffset = null;
      _latestGlobalDragPosition = null;
      _isAutoSnapped = false;
      _removeOverlay();
      _currentDraggingColor = null;
      _fixedVerticalPosition = null; // 重置固定垂直位置
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _overlayPositionNotifier.dispose();
    super.dispose();
  }

  Rect? _getTargetRect() {
    final RenderBox? targetBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) {
      return null;
    }
    final Offset targetTopLeft = targetBox.localToGlobal(Offset.zero);
    return targetTopLeft & targetBox.size;
  }

  bool _isCoveringTarget(Offset pointerGlobalPosition) {
    final Rect? targetRect = _getTargetRect();
    if (targetRect == null) {
      return false;
    }

    // 字母中心对齐到拖拽点，所以拖拽矩形的左上角是 pointerGlobalPosition - Offset(_badgeSize / 2, _badgeSize / 2)
    final double fixedY =
        _fixedVerticalPosition ?? (pointerGlobalPosition.dy - _badgeSize / 2);
    final Offset dragTopLeft = Offset(
      pointerGlobalPosition.dx - _badgeSize / 2, // 水平方向：字母中心对齐到拖拽点
      fixedY, // 垂直方向：保持固定位置
    );
    final Rect dragRect = Rect.fromLTWH(
      dragTopLeft.dx,
      dragTopLeft.dy,
      _badgeSize,
      _badgeSize,
    );

    if (!dragRect.overlaps(targetRect)) {
      return false;
    }

    final Rect intersection = Rect.fromLTRB(
      max(dragRect.left, targetRect.left),
      max(dragRect.top, targetRect.top),
      min(dragRect.right, targetRect.right),
      min(dragRect.bottom, targetRect.bottom),
    );

    if (intersection.width <= 0 || intersection.height <= 0) {
      return false;
    }

    final double widthCoverage = intersection.width / targetRect.width;
    final double heightCoverage = intersection.height / targetRect.height;

    return widthCoverage >= _coverageThreshold &&
        heightCoverage >= _coverageThreshold;
  }

  bool _isNearTarget(Offset pointerGlobalPosition, Rect targetRect) {
    // 字母中心对齐到拖拽点
    final double fixedY =
        _fixedVerticalPosition ?? (pointerGlobalPosition.dy - _badgeSize / 2);
    final Offset dragTopLeft = Offset(
      pointerGlobalPosition.dx - _badgeSize / 2, // 水平方向：字母中心对齐到拖拽点
      fixedY, // 垂直方向：保持固定位置
    );
    final Offset letterCenter =
        dragTopLeft + Offset(_badgeSize / 2, _badgeSize / 2);
    final Offset targetCenter = targetRect.center;

    final double pointerDistance =
        (pointerGlobalPosition - targetCenter).distance;
    final double centerDistance = (letterCenter - targetCenter).distance;
    final double snapRadius = max(
      targetRect.longestSide * 0.35,
      _badgeSize * 0.3,
    );

    return centerDistance <= snapRadius || pointerDistance <= snapRadius;
  }

  void _setLetterCovering(bool covering) {
    if (_isLetterCoveringTarget == covering) {
      return;
    }
    if (!mounted) {
      _isLetterCoveringTarget = covering;
      return;
    }
    setState(() {
      _isLetterCoveringTarget = covering;
    });
  }

  void _setAutoSnapped(bool snapped) {
    if (_isAutoSnapped == snapped) {
      return;
    }
    if (!mounted) {
      _isAutoSnapped = snapped;
      return;
    }
    setState(() {
      _isAutoSnapped = snapped;
    });
  }

  void _ensureOverlay(String letter) {
    if (_dragOverlayEntry != null) {
      return;
    }
    final OverlayState? overlayState = Overlay.of(context, rootOverlay: true);
    if (overlayState == null) {
      return;
    }

    // 拖拽时只显示文字，没有背景圆
    final Widget badge = _buildLetterBadge(
      letter: letter,
      background: Colors.transparent, // 透明背景，无背景圆
      textColor: Colors.green.shade700, // 保持原始文字颜色
      shadowColor: null, // 无阴影
      borderColor: null, // 无边框
      scale: 1.0,
    );

    _dragOverlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return IgnorePointer(
          ignoring: true,
          child: SizedBox.expand(
            child: ValueListenableBuilder<Offset?>(
              valueListenable: _overlayPositionNotifier,
              builder: (BuildContext context, Offset? position, Widget? child) {
                if (position == null) {
                  return const SizedBox.shrink();
                }
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: position.dx,
                      top: position.dy,
                      child: child!,
                    ),
                  ],
                );
              },
              child: badge,
            ),
          ),
        );
      },
    );

    overlayState.insert(_dragOverlayEntry!);
  }

  void _updateOverlayForPointer(Offset pointerGlobalPosition) {
    if (_dragOverlayEntry == null || _overlayLockedToTarget) {
      return;
    }
    // 让字母中心对齐到拖拽点
    final double fixedY =
        _fixedVerticalPosition ?? (pointerGlobalPosition.dy - _badgeSize / 2);

    final Offset topLeft = Offset(
      pointerGlobalPosition.dx - _badgeSize / 2, // 水平方向：字母中心对齐到拖拽点
      fixedY, // 垂直方向：保持固定位置
    );
    _overlayPositionNotifier.value = topLeft;
  }

  void _lockOverlayToTarget(Rect targetRect) {
    if (_dragOverlayEntry == null) {
      return;
    }
    _overlayLockedToTarget = true;
    // 吸附时让拖拽项稍微偏移目标区域，避免在不同分辨率设备上重叠
    final double targetCenterX = targetRect.center.dx;
    final double targetCenterY = targetRect.center.dy;
    // 让拖拽字母的中心与目标字母的中心对齐，但稍微向上偏移避免重叠
    final Offset topLeft = Offset(
      targetCenterX - _badgeSize / 2, // 水平居中
      targetCenterY - _badgeSize / 2, // 向上偏移10像素，避免重叠
    );
    _overlayPositionNotifier.value = topLeft;
    _setAutoSnapped(true);
  }

  void _unlockOverlay() {
    if (!_overlayLockedToTarget) {
      return;
    }
    _overlayLockedToTarget = false;
    _setAutoSnapped(false);
  }

  void _removeOverlay() {
    _overlayLockedToTarget = false;
    _overlayPositionNotifier.value = null;
    _dragOverlayEntry?.remove();
    _dragOverlayEntry = null;
  }

  void _handleDragMovement(Offset pointerGlobalPosition) {
    _latestGlobalDragPosition = pointerGlobalPosition;

    if (_dragOverlayEntry != null && !_overlayLockedToTarget) {
      _updateOverlayForPointer(pointerGlobalPosition);
    }

    final Rect? targetRect = _getTargetRect();
    if (targetRect == null) {
      _unlockOverlay();
      _setLetterCovering(false);
      return;
    }

    if (_isNearTarget(pointerGlobalPosition, targetRect)) {
      _lockOverlayToTarget(targetRect);
      _setLetterCovering(true);
    } else {
      final bool wasLocked = _overlayLockedToTarget;
      if (wasLocked) {
        _unlockOverlay();
        _updateOverlayForPointer(pointerGlobalPosition);
      }
      final bool covering = _isCoveringTarget(pointerGlobalPosition);
      _setLetterCovering(covering);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _handleDragMovement(details.globalPosition);
  }

  void _handleDragEnd(DraggableDetails details) {
    final Offset? lastPosition = _latestGlobalDragPosition;
    final bool covering =
        lastPosition != null && _isCoveringTarget(lastPosition);
    final bool matched = (_isAutoSnapped || covering) && !_hasMatched;

    if (mounted) {
      setState(() {
        _isDragging = false;
        _isLetterCoveringTarget = false;
        _isAutoSnapped = false;
        if (matched) {
          _hasMatched = true;
        }
      });
    }

    if (matched) {
      widget.onLetterMatched(widget.expectedLetter);
    }

    _removeOverlay();
    _currentDraggingColor = null;
    _dragPointerOffset = null;
    _latestGlobalDragPosition = null;
    _fixedVerticalPosition = null; // 重置固定垂直位置
  }

  @override
  Widget build(BuildContext context) {
    final String letter = widget.expectedLetter.trim();
    if (letter.isEmpty) {
      return Center(
        child: Text(
          '等待下一项...',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final bool completed = widget.isCompleted || _hasMatched;
    final String displayLetter = letter.toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildSource(displayLetter, completed),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 140,
                child: Center(
                  child: _DashedLine(
                    color: completed
                        ? widget.activeColor
                        : Colors.grey.shade400,
                    thickness: 1.0,
                    dashWidth: 6.0,
                    gapWidth: 4.0,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTarget(displayLetter, completed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSource(String letter, bool completed) {
    // 拖拽区不使用圆形背景，只显示文字
    final Widget badge = _buildLetterBadge(
      badgeKey: _sourceKey, // 添加key以获取位置
      letter: letter,
      background: Colors.transparent, // 透明背景，无圆形背景
      textColor: Colors.green.shade700,
      shadowColor: null, // 无阴影
      borderColor: null, // 无边框
    );

    if (completed) {
      return badge;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent event) {
        _dragPointerOffset = event.localPosition;
        _latestGlobalDragPosition = event.position;
      },
      onPointerMove: (PointerMoveEvent event) {
        _latestGlobalDragPosition = event.position;
        if (_isDragging) {
          _handleDragMovement(event.position);
        }
      },
      child: Draggable<String>(
        axis: Axis.horizontal,
        dragAnchorStrategy: childDragAnchorStrategy,
        data: widget.expectedLetter,
        feedbackOffset: _defaultFeedbackOffset,
        feedback: const SizedBox.shrink(),
        onDragStarted: () {
          // 获取源位置的垂直位置并固定
          final RenderBox? sourceBox =
              _sourceKey.currentContext?.findRenderObject() as RenderBox?;
          if (sourceBox != null) {
            final Offset sourceTopLeft = sourceBox.localToGlobal(Offset.zero);
            _fixedVerticalPosition = sourceTopLeft.dy;
          }

          _ensureOverlay(letter);
          setState(() {
            _isDragging = true;
            _isLetterCoveringTarget = false;
            _isAutoSnapped = false;
            _currentDraggingColor = widget.activeColor;
            _overlayLockedToTarget = false;
          });
          if (_latestGlobalDragPosition != null) {
            // 设置初始位置，让字母中心对齐到拖拽点
            final double fixedY =
                _fixedVerticalPosition ??
                (_latestGlobalDragPosition!.dy - _badgeSize / 2);
            final Offset initialTopLeft = Offset(
              _latestGlobalDragPosition!.dx - _badgeSize / 2, // 水平方向：字母中心对齐到拖拽点
              fixedY, // 垂直方向：保持固定位置
            );
            _overlayPositionNotifier.value = initialTopLeft;
            _handleDragMovement(_latestGlobalDragPosition!);
          }
        },
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        childWhenDragging: Opacity(opacity: 0.25, child: badge),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _isDragging ? 0.8 : 1.0,
          child: badge,
        ),
      ),
    );
  }

  Widget _buildTarget(String letter, bool completed) {
    return DragTarget<String>(
      onWillAccept: (String? value) {
        if (completed) return false;
        if (value == null) return false;
        return value.toLowerCase() == widget.expectedLetter.toLowerCase();
      },
      onAccept: (_) {},
      builder:
          (
            BuildContext context,
            List<String?> candidateData,
            List<dynamic> rejectedData,
          ) {
            Color background;
            Color textColor;
            Color? borderColor;
            Color? shadowColor;

            // 拖拽成功后切换下一个字母时，直接切换，不要圆形背景和颜色
            background = Colors.transparent;
            textColor = Colors.grey.shade600;
            borderColor = null;
            shadowColor = null;

            return _buildLetterBadge(
              badgeKey: _targetKey,
              letter: letter,
              background: background,
              textColor: textColor,
              borderColor: borderColor,
              shadowColor: shadowColor,
            );
          },
    );
  }

  Widget _buildLetterBadge({
    Key? badgeKey,
    required String letter,
    required Color background,
    required Color textColor,
    Color? borderColor,
    Color? shadowColor,
    double scale = 1.0,
  }) {
    final double size = _badgeSize * scale;

    // 如果背景是透明的，不显示圆形背景
    final bool hasBackground =
        background != Colors.transparent && background.alpha != 0;

    return AnimatedContainer(
      key: badgeKey,
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: hasBackground
          ? BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 2.0)
                  : null,
              boxShadow: shadowColor != null
                  ? <BoxShadow>[
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            )
          : null, // 透明背景时不设置decoration
      child: Text(
        letter,
        style: GoogleFonts.kalam(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.8,
          decoration: TextDecoration.none, // 确保没有下划线
        ),
      ),
    );
  }
}
