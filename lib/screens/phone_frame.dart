import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Constrains page content to a comfortable reading width.
///
/// On phones it is just padding; on tablets and desktop windows it centres the
/// content in a card so the UI does not stretch across the whole screen.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.maxWidth = 460,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final surfaces = AppSurfaces.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > maxWidth + 48;

        final content = Padding(padding: padding, child: child);
        if (!isWide) return content;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: surfaces.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: surfaces.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
        );
      },
    );
  }
}
