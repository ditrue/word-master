import 'package:flutter/material.dart';
import 'select_library_page.dart';
import 'practice_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp build called');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '记词大师',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF66BB6A), // 暖绿色（适合小学生）
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // 浅灰色背景
      ),
      home: const StudyHomePage(),
    );
  }
}

class StudyHomePage extends StatefulWidget {
  const StudyHomePage({super.key});

  @override
  State<StudyHomePage> createState() => _StudyHomePageState();
}

class _StudyHomePageState extends State<StudyHomePage> {
  int masteredWords = 81;
  int learnedWords = 493;
  int totalWords = 943;

  int newDone = 0;
  int newTarget = 70;
  int reviewDone = 41;
  int reviewTarget = 70;

  int selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    debugPrint('StudyHomePage build called');
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double progress =
        (masteredWords + learnedWords) / (totalWords == 0 ? 1 : totalWords);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '我的词库',
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SelectLibraryPage(),
                        ),
                      );
                    },
                    child: const Text('选择词库'),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _LabeledProgressBar(value: progress),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 24,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _LegendDot(color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('掌握$masteredWords'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _LegendDot(color: scheme.tertiary),
                              const SizedBox(width: 6),
                              Text('已学$learnedWords'),
                            ],
                          ),
                          Text(
                            '$totalWords词',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '今日计划',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Expanded(
                            child: _BigCounter(
                              title: '新学',
                              done: newDone,
                              total: newTarget,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 56,
                            color: Colors.black.withOpacity(0.06),
                          ),
                          Expanded(
                            child: _BigCounter(
                              title: '复习',
                              done: reviewDone,
                              total: reviewTarget,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                debugPrint('Navigating to PracticePage');
                                try {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PracticePage(),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint(
                                    'Error navigating to PracticePage: $e',
                                  );
                                }
                              },
                              child: const Text('新学'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  reviewDone = (reviewDone + 1).clamp(
                                    0,
                                    reviewTarget,
                                  );
                                });
                              },
                              child: const Text('复习'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Center(child: _SectionTitle(text: '自由练习')),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (BuildContext context) {
                          // Control item height here
                          const double practiceTileHeight = 88; // 修改为需要的高度
                          const int crossAxisCount = 2;
                          const double gridCrossAxisSpacing = 12;

                          final double gridWidth =
                              MediaQuery.of(context).size.width - 48;
                          final double tileWidth =
                              (gridWidth - gridCrossAxisSpacing) /
                              crossAxisCount;
                          final double aspectRatio =
                              tileWidth / practiceTileHeight;

                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: gridCrossAxisSpacing,
                            childAspectRatio: aspectRatio,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: const <Widget>[
                              _PracticeTile(
                                leadingText: '听',
                                subtitle: '听力训练',
                                color: Color(0xFF3E63DD),
                                background: Color(0xFFE9F0FF),
                              ),
                              _PracticeTile(
                                leadingText: '说',
                                subtitle: '跟读对比',
                                color: Color(0xFF7A3EC8),
                                background: Color(0xFFF0E8FF),
                              ),
                              _PracticeTile(
                                leadingText: '读',
                                subtitle: '释义巩固',
                                color: Color(0xFFE9860E),
                                background: Color(0xFFFFF2DF),
                              ),
                              _PracticeTile(
                                leadingText: '写',
                                subtitle: '拼写练习',
                                color: Color(0xFF0EA471),
                                background: Color(0xFFE7FFF5),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const <Widget>[
                    _QuickIcon(icon: Icons.list_alt),
                    _QuickIcon(icon: Icons.videocam),
                    _QuickIcon(icon: Icons.headphones),
                    _QuickIcon(icon: Icons.security),
                    _QuickIcon(icon: Icons.text_fields),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedTabIndex,
        onTap: (int index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
        selectedItemColor: scheme.primary,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '单词'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '词典'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const _Mascot(),
            const SizedBox(height: 12),
            Text(
              '记词大师',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '让记忆像引擎一样高效运转',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class _LabeledProgressBar extends StatelessWidget {
  const _LabeledProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: Colors.black.withOpacity(0.06),
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BigCounter extends StatelessWidget {
  const _BigCounter({
    required this.title,
    required this.done,
    required this.total,
  });

  final String title;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            '$done',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
          ),
          Text('/$total', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.leadingText,
    required this.subtitle,
    required this.color,
    required this.background,
  });

  final String leadingText;
  final String subtitle;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            leadingText,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.black87),
    );
  }
}

class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            Icons.rocket_launch_outlined,
            size: 56,
            color: const Color(0xFF66BB6A),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '火箭模式',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// moved to select_library_page.dart
