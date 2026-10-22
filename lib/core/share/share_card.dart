import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';

/// Where people can get the app. Override at build time once the store
/// listings are live: --dart-define=APP_SHARE_URL=https://…
const appShareUrl = String.fromEnvironment(
  'APP_SHARE_URL',
  defaultValue: 'https://rvastrovastu.github.io/rvastrovastu/',
);

/// A branded card for sharing as an image: navy with a gold edge and the
/// app's name at the foot.
class BrandedShareCard extends StatelessWidget {
  final Widget child;

  const BrandedShareCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1F55), AppColors.background],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.shareFooter,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows [card] in a sheet with a Share button that sends it as a PNG,
/// with [text] alongside for apps that only take text.
Future<void> showShareCardSheet(
  BuildContext context, {
  required Widget card,
  required String fileName,
  String? text,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  builder: (context) =>
      _ShareCardSheet(card: card, fileName: fileName, text: text),
);

class _ShareCardSheet extends StatefulWidget {
  final Widget card;
  final String fileName;
  final String? text;

  const _ShareCardSheet({
    required this.card,
    required this.fileName,
    this.text,
  });

  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _boundary = GlobalKey();
  bool _sharing = false;

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: widget.text,
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      // Fall back to text when the image can't be made.
      if (widget.text != null) {
        await SharePlus.instance.share(
          ShareParams(text: widget.text, sharePositionOrigin: origin),
        );
      }
      debugPrint('[SHARE] image share failed: $error');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              child: RepaintBoundary(key: _boundary, child: widget.card),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (buttonContext) => FilledButton.icon(
                key: const ValueKey('shareCardButton'),
                onPressed: _sharing ? null : () => _share(buttonContext),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(l10n.shareButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
