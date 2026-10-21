import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../presentation/providers/compass_provider.dart';
import '../../domain/vastu_layout.dart';
import '../vastu_layout_providers.dart';
import '../vastu_layout_text.dart';
import '../widgets/plan_canvas.dart';

enum _Step { entrance, rooms, outline }

/// Creates or edits a property: plan photo, entrance, rooms and outline.
class VastuPlanEditorPage extends ConsumerStatefulWidget {
  /// Null for a new property.
  final String? layoutId;

  /// Picks the plan photo; replaceable in tests.
  final Future<XFile?> Function(ImageSource source)? pickImage;

  const VastuPlanEditorPage({super.key, this.layoutId, this.pickImage});

  @override
  ConsumerState<VastuPlanEditorPage> createState() =>
      _VastuPlanEditorPageState();
}

class _VastuPlanEditorPageState extends ConsumerState<VastuPlanEditorPage> {
  VastuLayout? _layout;
  File? _image;
  final _name = TextEditingController();
  final _degrees = TextEditingController();
  _Step _step = _Step.entrance;
  VastuRoom _room = VastuRoom.kitchen;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VastuLayout? layout;
    if (widget.layoutId case final id?) {
      final all = await ref.read(vastuLayoutsProvider.future);
      layout = all.where((l) => l.id == id).firstOrNull;
    }
    layout ??= VastuLayout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '',
      updatedAt: DateTime.now(),
      // A blank plan uses the whole square as the house.
      frame: const PlanFrame(left: 0.04, top: 0.04, right: 0.96, bottom: 0.96),
    );
    final ready = layout;
    File? image;
    if (ready.imageFile case final name?) {
      image = await ref.read(vastuImageStoreProvider).file(name);
    }
    if (!mounted) return;
    setState(() {
      _layout = ready;
      _image = image;
      _name.text = ready.name;
      _degrees.text = ready.entranceFacing.round().toString();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _degrees.dispose();
    super.dispose();
  }

  void _update(VastuLayout Function(VastuLayout) change) =>
      setState(() => _layout = change(_layout!));

  void _setFacing(double degrees, {bool syncField = true}) {
    final wrapped = ((degrees % 360) + 360) % 360;
    _update((l) => l.copyWith(entranceFacing: wrapped));
    if (syncField) _degrees.text = wrapped.round().toString();
  }

  Future<void> _pick(ImageSource source) async {
    final picker = widget.pickImage ??
        (ImageSource s) => ImagePicker().pickImage(
          source: s,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 88,
        );
    final file = await picker(source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    final ratio = decoded.width / decoded.height;
    decoded.dispose();
    final name = await ref
        .read(vastuImageStoreProvider)
        .save(_layout!.id, bytes);
    final saved = await ref.read(vastuImageStoreProvider).file(name);
    if (!mounted) return;
    setState(() {
      _image = saved;
      _layout = _layout!.copyWith(
        imageFile: name,
        aspectRatio: ratio,
        frame: const PlanFrame(),
        clearEntrance: true,
        rooms: const [],
      );
    });
  }

  void _tap(PlanPoint p) {
    switch (_step) {
      case _Step.entrance:
        _update((l) => l.copyWith(entrance: p));
      case _Step.rooms:
        final rooms = _layout!.rooms;
        final hit = rooms.where((r) {
          final dx = (r.at.x - p.x) * _layout!.aspectRatio;
          final dy = r.at.y - p.y;
          return dx * dx + dy * dy < 0.0025;
        }).firstOrNull;
        _update(
          (l) => l.copyWith(
            rooms: hit != null
                ? [
                    for (final r in rooms)
                      if (r.id != hit.id) r,
                  ]
                : [
                    ...rooms,
                    RoomMark(
                      id: '${DateTime.now().microsecondsSinceEpoch}',
                      room: _room,
                      at: p,
                    ),
                  ],
          ),
        );
      case _Step.outline:
        break;
    }
  }

  Future<void> _save() async {
    final layout = _layout;
    if (layout == null || _saving) return;
    setState(() => _saving = true);
    final name = _name.text.trim().isEmpty
        ? context.l10n.vastuPlanNew
        : _name.text.trim();
    final saved = layout.copyWith(name: name, updatedAt: DateTime.now());
    await ref.read(vastuLayoutsProvider.notifier).save(saved);
    if (!mounted) return;
    if (widget.layoutId == null) {
      context.pushReplacement('/vastu/plans/${saved.id}');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final layout = _layout;
    final compass = ref.watch(compassHeadingProvider).value;

    if (layout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.layoutId == null ? l10n.vastuPlanNew : layout.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.vastuPlanName,
              hintText: l10n.vastuPlanNameHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.vastuPlanImageTitle, style: theme.textTheme.titleMedium),
          if (_image == null) ...[
            const SizedBox(height: 4),
            Text(l10n.vastuPlanImageHint, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _image == null
                      ? l10n.vastuPlanChoosePhoto
                      : l10n.vastuPlanReplacePhoto,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.vastuPlanTakePhoto),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Step>(
            segments: [
              ButtonSegment(
                value: _Step.entrance,
                icon: const Icon(Icons.door_front_door_outlined),
                label: Text(l10n.vastuPlanStepEntrance),
              ),
              ButtonSegment(
                value: _Step.rooms,
                icon: const Icon(Icons.meeting_room_outlined),
                label: Text(l10n.vastuPlanStepRooms),
              ),
              ButtonSegment(
                value: _Step.outline,
                icon: const Icon(Icons.crop_free),
                label: Text(l10n.vastuPlanStepOutline),
              ),
            ],
            selected: {_step},
            onSelectionChanged: (s) => setState(() => _step = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            switch (_step) {
              _Step.entrance => l10n.vastuPlanTapEntrance,
              _Step.rooms => l10n.vastuPlanTapRooms,
              _Step.outline => l10n.vastuPlanOutlineHelp,
            },
            style: theme.textTheme.bodySmall,
          ),
          if (_step == _Step.rooms) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final room in VastuRoom.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(roomIcon(room), size: 16),
                        label: Text(l10n.roomName(room)),
                        selected: _room == room,
                        onSelected: (_) => setState(() => _room = room),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          PlanCanvas(layout: layout, image: _image, onTap: _tap),
          const SizedBox(height: 12),
          if (_step == _Step.entrance) ...[
            Text(l10n.vastuPlanDoorSide, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<PlanSide>(
              segments: [
                for (final side in PlanSide.values)
                  ButtonSegment(
                    value: side,
                    label: Text(l10n.vastuPlanSide(side.name)),
                  ),
              ],
              selected: {layout.doorSide},
              onSelectionChanged: (s) =>
                  _update((l) => l.copyWith(doorSide: s.first)),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.facingLabel(layout.entranceFacing),
              style: theme.textTheme.titleSmall,
            ),
            Row(
              children: [
                SizedBox(
                  width: 76,
                  child: TextField(
                    key: const ValueKey('facingField'),
                    controller: _degrees,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(suffixText: '°'),
                    onChanged: (v) {
                      final value = int.tryParse(v);
                      if (value != null && value < 360) {
                        _setFacing(value.toDouble(), syncField: false);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: layout.entranceFacing.clamp(0, 359).toDouble(),
                    max: 359,
                    divisions: 359,
                    onChanged: _setFacing,
                  ),
                ),
              ],
            ),
            Text(l10n.vastuPlanFacingHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  if (compass == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.vastuPlanCompassUnavailable),
                      ),
                    );
                    return;
                  }
                  _setFacing(compass);
                },
                icon: const Icon(Icons.explore_outlined),
                label: Text(l10n.vastuPlanUseCompass),
              ),
            ),
          ],
          if (_step == _Step.outline) ...[
            Text(l10n.vastuPlanOutlineWidth, style: theme.textTheme.titleSmall),
            RangeSlider(
              values: RangeValues(layout.frame.left, layout.frame.right),
              onChanged: (v) {
                if (v.end - v.start < 0.2) return;
                _update(
                  (l) => l.copyWith(
                    frame: l.frame.copyWith(left: v.start, right: v.end),
                  ),
                );
              },
            ),
            Text(
              l10n.vastuPlanOutlineHeight,
              style: theme.textTheme.titleSmall,
            ),
            RangeSlider(
              values: RangeValues(layout.frame.top, layout.frame.bottom),
              onChanged: (v) {
                if (v.end - v.start < 0.2) return;
                _update(
                  (l) => l.copyWith(
                    frame: l.frame.copyWith(top: v.start, bottom: v.end),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(l10n.vastuPlanCutCorners, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final corner in VastuCorner.values)
                  FilterChip(
                    label: Text(l10n.vastuCornerName(corner.name)),
                    selected: layout.cutCorners.contains(corner),
                    onSelected: (on) => _update(
                      (l) => l.copyWith(
                        cutCorners: on
                            ? {...l.cutCorners, corner}
                            : ({...l.cutCorners}..remove(corner)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(l10n.vastuPlanSave),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
