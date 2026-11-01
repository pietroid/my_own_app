import 'package:app_ui/app_ui.dart';

/// {@template app_build_grid}
/// A faint square grid behind [child], in [AppColors.line] every
/// [AppSpacing.gridCell]: the workbench the app is built on. Decoration for
/// a screen with little on it, like the sign-in; never behind running text.
/// {@endtemplate}
class AppBuildGrid extends StatelessWidget {
  /// {@macro app_build_grid}
  const AppBuildGrid({required this.child, super.key});

  /// What sits on the grid.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _GridPainter(), child: child);
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = AppSpacing.hairline;
    for (var x = 0.0; x <= size.width; x += AppSpacing.gridCell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += AppSpacing.gridCell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
