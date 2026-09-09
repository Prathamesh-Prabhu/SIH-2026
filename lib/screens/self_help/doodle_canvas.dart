import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/doodle_library.dart';

/// Zen doodling canvas with reference pictures and a trace overlay.
/// Ported from mindspace's `DoodleCanvas.tsx`.
class DoodleCanvas extends StatefulWidget {
  const DoodleCanvas({
    super.key,
    this.initialDoodleId,
    this.onSaved,
    this.fullscreen = false,
  });
  final int? initialDoodleId;
  final VoidCallback? onSaved;

  /// When true the widget fills its parent — the canvas [Expanded]s to take
  /// all spare height, toolbars are pinned top and bottom, and there is no
  /// scroll (so a stroke can never be mistaken for a page scroll). The
  /// reference-picture picker moves into a bottom sheet.
  final bool fullscreen;

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

enum _Brush { pen, marker, glow, watercolor, eraser }

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double size;
  final _Brush brush;
  _Stroke(this.points, this.color, this.size, this.brush);
}

class _PaletteColor {
  final String name;
  final Color color;
  const _PaletteColor(this.name, this.color);
}

const _palette = <_PaletteColor>[
  _PaletteColor('Sage Leaf', Color(0xFF4F6B57)),
  _PaletteColor('Deep Forest', Color(0xFF243327)),
  _PaletteColor('Warm Terracotta', Color(0xFFC86D51)),
  _PaletteColor('Lavender Mist', Color(0xFF8E7DBE)),
  _PaletteColor('Calm Teal', Color(0xFF3B8B88)),
  _PaletteColor('Sunset Glow', Color(0xFFE07A5F)),
  _PaletteColor('Golden Honey', Color(0xFFD4A373)),
  _PaletteColor('Soft Charcoal', Color(0xFF3A3F3B)),
  _PaletteColor('Pure Chalk', Color(0xFFFFFFFF)),
];

const _lightBg = Color(0xFFFAF7F2);
const _darkBg = Color(0xFF1A211D);

class _DoodleCanvasState extends State<DoodleCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();

  final List<_Stroke> _history = [];
  List<Offset> _current = [];

  Color _color = _palette.first.color;
  double _brushSize = 4;
  _Brush _brush = _Brush.pen;
  bool _dark = false;

  late int _doodleId;
  bool _trace = false;
  double _traceOpacity = 0.35;

  @override
  void initState() {
    super.initState();
    _doodleId = (widget.initialDoodleId != null &&
            kFeaturedDoodleIds.contains(widget.initialDoodleId))
        ? widget.initialDoodleId!
        : kFeaturedDoodleIds.first;
  }

  @override
  void didUpdateWidget(covariant DoodleCanvas old) {
    super.didUpdateWidget(old);
    if (widget.initialDoodleId != null &&
        widget.initialDoodleId != old.initialDoodleId &&
        kFeaturedDoodleIds.contains(widget.initialDoodleId)) {
      setState(() => _doodleId = widget.initialDoodleId!);
    }
  }

  DoodleReference get _doodle => doodleById(_doodleId);

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _history.removeLast());
  }

  void _commitStroke() {
    setState(() {
      if (_current.isNotEmpty) {
        _history.add(_Stroke(_current, _color, _brushSize, _brush));
      }
      _current = [];
    });
  }

  Future<void> _clear() async {
    if (_history.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear canvas?'),
        content: const Text('Start fresh with a blank canvas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) setState(() => _history.clear());
  }

  Future<void> _save() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final slug = _doodle.title.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      final file = File(
          '${dir.path}/manofit-doodle-$slug-${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],
          text: 'My ManoFit doodle: ${_doodle.title}');

      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export the doodle: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullscreen) return _buildFullscreen();
    return _buildInline();
  }

  Widget _buildInline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reference banner + trace toggle
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5E5D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOW DRAWING · ${_doodle.title.toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.secondary)),
                        const SizedBox(height: 2),
                        Text(
                          'Pick a picture below and draw along, or turn on the trace overlay.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _trace = !_trace),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _trace ? AppColors.primaryContainer : Colors.white,
                    foregroundColor:
                        _trace ? Colors.white : AppColors.primary,
                    side: BorderSide(
                        color: _trace
                            ? AppColors.primaryContainer
                            : AppColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(_trace ? Icons.visibility : Icons.layers_outlined,
                      size: 16),
                  label: Text(_trace
                      ? 'Trace Overlay Active'
                      : 'Overlay Picture on Canvas'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Toolbar row 1 — brushes, size, dark toggle
        _toolbar(
          child: Column(
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Brush',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                  for (final b in _Brush.values) _brushChip(b),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Size',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: 2,
                      max: 24,
                      onChanged: (v) => setState(() => _brushSize = v),
                    ),
                  ),
                  SizedBox(
                      width: 22,
                      child: Text('${_brushSize.round()}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant))),
                  IconButton(
                    tooltip: _dark ? 'Light canvas' : 'Dark canvas',
                    onPressed: () => setState(() => _dark = !_dark),
                    icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode,
                        size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Toolbar row 2 — colours + actions
        _toolbar(
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _palette)
                    GestureDetector(
                      onTap: () => setState(() {
                        _color = p.color;
                        if (_brush == _Brush.eraser) _brush = _Brush.pen;
                      }),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (_color == p.color &&
                                    _brush != _Brush.eraser)
                                ? AppColors.primary
                                : (p.color == Colors.white
                                    ? AppColors.outlineVariant
                                    : Colors.transparent),
                            width: (_color == p.color &&
                                    _brush != _Brush.eraser)
                                ? 3
                                : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _actionBtn('Undo', Icons.undo,
                      _history.isEmpty ? null : _undo),
                  const SizedBox(width: 8),
                  _actionBtn('Clear', Icons.delete_outline,
                      _history.isEmpty ? null : _clear),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.ios_share, size: 15),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // The canvas
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = (w * 0.68).clamp(300.0, 460.0);
            return SizedBox(width: w, height: h, child: _canvasStack());
          },
        ),

        if (_trace) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Overlay opacity',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant)),
              Expanded(
                child: Slider(
                  value: _traceOpacity,
                  min: 0.15,
                  max: 0.8,
                  onChanged: (v) => setState(() => _traceOpacity = v),
                ),
              ),
              Text('${(_traceOpacity * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
        const SizedBox(height: 14),

        // Picker
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  const Text('Pick a Picture',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showSteps(_doodle),
                    icon: const Icon(Icons.open_in_full, size: 14),
                    label: const Text('Drawing steps'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: [
                  for (final d in featuredDoodles) _pickerTile(d),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Fullscreen layout ────────────────────────────────────────────────────
  Widget _buildFullscreen() {
    return Column(
      children: [
        // Pinned top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              _fsChip(
                icon: _trace ? Icons.visibility : Icons.layers_outlined,
                label: _trace ? 'Tracing' : 'Trace',
                active: _trace,
                onTap: () => setState(() => _trace = !_trace),
              ),
              const SizedBox(width: 8),
              _fsChip(
                icon: Icons.image_outlined,
                label: 'Pictures',
                active: false,
                onTap: _showPicker,
              ),
              const Spacer(),
              IconButton(
                tooltip: _dark ? 'Light canvas' : 'Dark canvas',
                onPressed: () => setState(() => _dark = !_dark),
                icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode, size: 20),
              ),
            ],
          ),
        ),

        // The canvas fills all remaining height
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _canvasStack(),
          ),
        ),

        if (_trace)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.opacity, size: 14, color: AppColors.onSurfaceVariant),
                Expanded(
                  child: Slider(
                    value: _traceOpacity,
                    min: 0.15,
                    max: 0.8,
                    onChanged: (v) => setState(() => _traceOpacity = v),
                  ),
                ),
                Text('${(_traceOpacity * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),

        // Pinned bottom toolbar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final b in _Brush.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _brushChip(b),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Size',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                  Expanded(
                    child: Slider(
                      value: _brushSize,
                      min: 2,
                      max: 24,
                      onChanged: (v) => setState(() => _brushSize = v),
                    ),
                  ),
                  SizedBox(
                      width: 22,
                      child: Text('${_brushSize.round()}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant))),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _palette)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _paletteDot(p),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _actionBtn('Undo', Icons.undo,
                      _history.isEmpty ? null : _undo),
                  const SizedBox(width: 8),
                  _actionBtn('Clear', Icons.delete_outline,
                      _history.isEmpty ? null : _clear),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.ios_share, size: 15),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The drawing surface itself — painter + trace/hint overlays + the pan
  /// recognizer that keeps a stroke from becoming a scroll. Shared by both
  /// layouts; sizes to whatever bounded box it is given.
  Widget _canvasStack() {
    final onCanvas = _dark ? Colors.white70 : const Color(0xFF56685A);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DoodlePainter(
                  history: _history,
                  active: _current.isEmpty
                      ? null
                      : _Stroke(_current, _color, _brushSize, _brush),
                  dark: _dark,
                ),
              ),
            ),
            if (_trace)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _traceOpacity,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _doodle.toPicture(
                          color: _dark ? Colors.white : AppColors.primary),
                    ),
                  ),
                ),
              ),
            if (_history.isEmpty && _current.isEmpty && !_trace)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.brush_outlined, color: onCanvas, size: 26),
                          const SizedBox(height: 8),
                          Text(
                            'Pick a reference picture and draw "${_doodle.title}"…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: onCanvas),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Zero pressure. Enjoy each line as a mindful breath.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: onCanvas.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // A pan recognizer that *wins* the gesture arena instead of
            // yielding to an ancestor scroll view, so a stroke that starts on
            // the canvas draws a line rather than moving the page.
            Positioned.fill(
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _DrawPanRecognizer:
                      GestureRecognizerFactoryWithHandlers<_DrawPanRecognizer>(
                    () => _DrawPanRecognizer(),
                    (_DrawPanRecognizer r) {
                      r.onStart =
                          (d) => setState(() => _current = [d.localPosition]);
                      r.onUpdate = (d) => setState(
                          () => _current = [..._current, d.localPosition]);
                      r.onEnd = (_) => _commitStroke();
                      r.onCancel = _commitStroke;
                    },
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fsChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active
                  ? AppColors.primaryContainer
                  : AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15, color: active ? Colors.white : AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _paletteDot(_PaletteColor p) {
    final selected = _color == p.color && _brush != _Brush.eraser;
    return GestureDetector(
      onTap: () => setState(() {
        _color = p.color;
        if (_brush == _Brush.eraser) _brush = _Brush.pen;
      }),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: p.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (p.color == Colors.white
                    ? AppColors.outlineVariant
                    : Colors.transparent),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                const Text('Pick a picture',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    _showSteps(_doodle);
                  },
                  icon: const Icon(Icons.open_in_full, size: 14),
                  label: const Text('Steps'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: [
                  for (final d in featuredDoodles)
                    GestureDetector(
                      onTap: () {
                        setState(() => _doodleId = d.id);
                        Navigator.pop(c);
                      },
                      child: AbsorbPointer(child: _pickerTile(d)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }

  Widget _brushChip(_Brush b) {
    const labels = {
      _Brush.pen: 'Pen',
      _Brush.marker: 'Marker',
      _Brush.glow: 'Neon',
      _Brush.watercolor: 'Watercolor',
      _Brush.eraser: 'Eraser',
    };
    final selected = _brush == b;
    return GestureDetector(
      onTap: () => setState(() => _brush = b),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(labels[b]!,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.onSurfaceVariant)),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }

  Widget _pickerTile(DoodleReference d) {
    final selected = _doodleId == d.id;
    return GestureDetector(
      onTap: () => setState(() => _doodleId = d.id),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: d.toPicture(color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  void _showSteps(DoodleReference d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                height: 140,
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: d.toPicture(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(d.title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            Text('"${d.tagline}"',
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 14),
            for (var i = 0; i < d.instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d.instructions[i],
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  setState(() {
                    _doodleId = d.id;
                    _trace = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.layers_outlined, size: 16),
                label: const Text('Overlay Picture on Canvas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({required this.history, required this.active, required this.dark});
  final List<_Stroke> history;
  final _Stroke? active;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = dark ? _darkBg : _lightBg;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // Subtle grid texture.
    final grid = Paint()
      ..color = dark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.025)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final s in history) {
      _drawStroke(canvas, s, bg);
    }
    if (active != null) _drawStroke(canvas, active!, bg);
  }

  void _drawStroke(Canvas canvas, _Stroke s, Color bg) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (s.brush) {
      case _Brush.eraser:
        paint
          ..color = bg
          ..strokeWidth = s.size * 2.5;
        break;
      case _Brush.glow:
        paint
          ..color = s.color
          ..strokeWidth = s.size
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size * 0.9);
        break;
      case _Brush.marker:
        paint
          ..color = s.color.withOpacity(0.45)
          ..strokeWidth = s.size * 2;
        break;
      case _Brush.watercolor:
        paint
          ..color = s.color.withOpacity(0.25)
          ..strokeWidth = s.size * 2.8
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size * 0.6);
        break;
      case _Brush.pen:
        paint
          ..color = s.color
          ..strokeWidth = s.size;
        break;
    }

    final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
    if (s.points.length == 1) {
      path.lineTo(s.points.first.dx + 0.1, s.points.first.dy + 0.1);
    } else {
      for (var i = 1; i < s.points.length - 1; i++) {
        final xc = (s.points[i].dx + s.points[i + 1].dx) / 2;
        final yc = (s.points[i].dy + s.points[i + 1].dy) / 2;
        path.quadraticBezierTo(
            s.points[i].dx, s.points[i].dy, xc, yc);
      }
      path.lineTo(s.points.last.dx, s.points.last.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => true;
}

/// Pan recognizer for the drawing surface. It overrides [rejectGesture] to
/// accept instead — so when it is placed inside a scroll view, a stroke that
/// begins on the canvas wins the gesture arena and draws, rather than the
/// scroll view stealing vertical drags and panning the page.
class _DrawPanRecognizer extends PanGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
