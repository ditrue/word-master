import 'package:flutter/material.dart';

class SelectLibraryPage extends StatelessWidget {
  const SelectLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final TextStyle subtitleStyle = const TextStyle(
      fontSize: 12,
      color: Colors.black54,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('选择词库'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('示例词库 ${index + 1}', style: titleStyle),
                        const SizedBox(height: 4),
                        Text('共 100 词，适合入门阶段', style: subtitleStyle),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('添加词库'),
            ),
          ),
        ),
      ),
    );
  }
}
