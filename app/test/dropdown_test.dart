import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onward/ui/theme.dart';
import 'package:onward/ui/widgets.dart';

void main() {
  testWidgets('app dropdowns open and select values', (tester) async {
    var fieldValue = 'All';
    String? menuValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: onwardTheme(dark: false),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AppDropdownButtonFormField<String>(
                  initialValue: fieldValue,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Open', child: Text('Open')),
                  ],
                  onChanged: (value) => setState(() => fieldValue = value!),
                ),
                AppPopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: (value) => menuValue = value,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Done', child: Text('Done')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    expect(fieldValue, 'Open');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(menuValue, 'Done');
  });
}
