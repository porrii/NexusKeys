import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/theme/app_theme.dart';
import 'package:nexuskeys/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

  testWidgets('renders the title, subtitle and a letter avatar', (tester) async {
    await tester.pumpWidget(wrap(
      const VaultItemTile(title: 'Google', subtitle: 'ivan@gmail.com', avatarColor: Colors.blue),
    ));

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('ivan@gmail.com'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('shows a star instead of a chevron when favorite', (tester) async {
    await tester.pumpWidget(wrap(
      const VaultItemTile(
        title: 'Google',
        subtitle: 'ivan@gmail.com',
        avatarColor: Colors.blue,
        isFavorite: true,
      ),
    ));

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('shows a chevron instead of a star when not favorite', (tester) async {
    await tester.pumpWidget(wrap(
      const VaultItemTile(title: 'GitHub', subtitle: 'ivan_dev', avatarColor: Colors.black),
    ));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('alwaysShowStar shows an outline star instead of a chevron when not favorite', (tester) async {
    await tester.pumpWidget(wrap(
      const VaultItemTile(
        title: 'GitHub',
        subtitle: 'ivan_dev',
        avatarColor: Colors.black,
        alwaysShowStar: true,
      ),
    ));

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('alwaysShowStar still shows the filled star when favorite', (tester) async {
    await tester.pumpWidget(wrap(
      const VaultItemTile(
        title: 'Google',
        subtitle: 'ivan@gmail.com',
        avatarColor: Colors.blue,
        isFavorite: true,
        alwaysShowStar: true,
      ),
    ));

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      VaultItemTile(
        title: 'GitHub',
        subtitle: 'ivan_dev',
        avatarColor: Colors.black,
        onTap: () => tapped = true,
      ),
    ));

    await tester.tap(find.byType(VaultItemTile));

    expect(tapped, isTrue);
  });
}
