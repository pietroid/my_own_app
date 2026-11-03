part of '../app_renderer.dart';

/// Surface: another of the person's apps, drawn and run inside this one.
extension on _Render {
  Widget surface(Map<String, dynamic> c, _Scope scope) {
    final id = string(c['app'], scope);
    if (id.isEmpty) return const SizedBox.shrink();
    final version = value(c['version'], scope);
    final picking = value(c['picking'], scope) == true;
    return _Surface(
      // Another app, another version, or a new revision of the same one
      // (the editor changed it): load it again.
      key: ValueKey(
        'surface:$id:$version:${jsonEncode(value(c['revision'], scope))}',
      ),
      id: id,
      version: version is num ? version.toInt() : null,
      framed: c['frame'] != 'none',
      selectedId: string(c['selected'], scope),
      onPick: picking && hasAction(c)
          ? (componentId) => fire(c, scope, {'componentId': componentId})
          : null,
    );
  }
}

/// How deep in Surfaces a screen is: an app drawn inside itself draws its
/// own Surface as a placeholder, not again.
class _SurfaceDepth extends InheritedWidget {
  const _SurfaceDepth({required super.child});

  static bool inside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SurfaceDepth>() != null;

  @override
  bool updateShouldNotify(_SurfaceDepth oldWidget) => false;
}

/// The app [id] (or its [version], read-only), with its own [AppRunCubit]:
/// its own data, its own actions run by the same runner, its own server
/// actions. Drawn in a phone or a browser by its form when [framed].
class _Surface extends StatefulWidget {
  const _Surface({
    required this.id,
    required this.version,
    required this.framed,
    required this.selectedId,
    required this.onPick,
    super.key,
  });

  final String id;
  final int? version;
  final bool framed;
  final String selectedId;
  final ValueChanged<String>? onPick;

  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  AppRunCubit? _cubit;
  AppSnapshot? _viewed;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    final repository = context.read<AppsRepository>();
    final version = widget.version;
    if (version == null) {
      _cubit = AppRunCubit(repository: repository, id: widget.id);
      unawaited(_cubit!.load());
    } else {
      unawaited(_view(repository, version));
    }
  }

  Future<void> _view(AppsRepository repository, int version) async {
    try {
      final app = await repository.version(widget.id, version);
      if (mounted) setState(() => _viewed = app);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_SurfaceDepth.inside(context)) {
      return const _SurfacePlaceholder();
    }
    final cubit = _cubit;
    final screen = cubit == null
        ? _screen(_viewed, failed: _failed, pending: const {})
        : BlocBuilder<AppRunCubit, AppRunState>(
            bloc: cubit,
            builder: (context, state) => _screen(
              state.app,
              failed: state.loadFailed,
              pending: state.pending,
              error: state.error,
              cubit: cubit,
            ),
          );
    return _SurfaceDepth(child: screen);
  }

  Widget _screen(
    AppSnapshot? app, {
    required bool failed,
    required Map<String, Map<String, Object?>> pending,
    String? error,
    AppRunCubit? cubit,
  }) {
    if (app == null) {
      return SizedBox(
        height: AppSpacing.imageLarge,
        child: Center(
          child: failed
              ? AppIcon(
                  iconData: AppIcons.named['warning']!,
                  color: AppColors.negative,
                )
              : const AppTypingIndicator(),
        ),
      );
    }
    final page = ColoredBox(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // Built inside the frame: its insets are the drawn phone's.
            child: Builder(
              builder: (context) => SingleChildScrollView(
                // Below a drawn phone's status bar, above its home indicator.
                padding: MediaQuery.paddingOf(
                  context,
                ).add(const EdgeInsets.all(AppSpacing.s6)),
                child: AppRenderer(
                  ui: app.ui,
                  data: app.data,
                  pending: pending,
                  // A version is looked at, not used.
                  onEdit: cubit?.edit ?? (_, _) {},
                  onAction: (action, event) => cubit == null
                      ? null
                      : unawaited(cubit.act(action, event)),
                  onSelect: widget.onPick,
                  selectedId: widget.selectedId,
                ),
              ),
            ),
          ),
          if (error != null)
            ColoredBox(
              color: AppColors.fill,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Text(
                  error.isEmpty ? context.l10n.appsActionFailed : error,
                  style: AppTypography.label.copyWith(
                    color: AppColors.negative,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    // Its own overlay, so its sheets open inside it, not over the host.
    final screen = Overlay(
      initialEntries: [OverlayEntry(builder: (_) => page)],
    );
    if (!widget.framed) {
      return SizedBox(height: AppPhoneFrame.screen.height, child: screen);
    }
    return app.form == AppForm.web
        ? AppBrowserFrame(address: app.name, child: screen)
        : AppPhoneFrame(child: screen);
  }
}

class _SurfacePlaceholder extends StatelessWidget {
  const _SurfacePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.imageLarge,
      decoration: BoxDecoration(
        color: AppColors.fill,
        border: Border.all(color: AppColors.line),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      child: Center(
        child: AppIcon(
          iconData: AppIcons.components['Surface']!,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}
