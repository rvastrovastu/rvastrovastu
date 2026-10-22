import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../membership/domain/membership.dart';
import '../../membership/presentation/widgets/premium_gate.dart';
import 'ai_chat_provider.dart';

/// Chat with the AI astrologer about the active profile's chart.
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _input.text).trim();
    if (question.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    final done = ref.read(aiChatProvider.notifier).ask(question);
    _toBottom();
    await done;
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chat = ref.watch(aiChatProvider);
    final chart = ref.watch(aiChartContextProvider);

    final hasChart = chart.value != null;
    final allowance = chat.allowance;
    final locked = chat.limitReached && !(allowance?.premium ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiTitle)),
      body: Column(
        children: [
          if (allowance != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Text(
                allowance.premium
                    ? l10n.aiPremiumUnlimited
                    : l10n.aiRemaining(allowance.remaining, allowance.limit),
                key: const ValueKey('aiAllowance'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: chart.isLoading && !chart.hasValue
                ? const Center(child: CircularProgressIndicator())
                : !hasChart
                ? _NeedProfile(onCreate: () => context.push('/birth-profile'))
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      if (chat.messages.isEmpty) ...[
                        Text(l10n.aiIntro, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in const ['s1', 's2', 's3', 's4', 's5'])
                              ActionChip(
                                label: Text(l10n.aiSuggestion(key)),
                                onPressed: locked || chat.sending
                                    ? null
                                    : () => _send(l10n.aiSuggestion(key)),
                              ),
                          ],
                        ),
                      ],
                      for (final m in chat.messages) _Bubble(message: m),
                      if (chat.sending)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text(l10n.aiThinking, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      if (chat.problem == AiProblem.unavailable)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.aiUnavailable,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      if (chat.limitReached && (allowance?.premium ?? false))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.aiDailyLimit),
                        ),
                      if (locked) ...[
                        const SizedBox(height: 12),
                        const PremiumLockedCard(
                          feature: PremiumFeature.aiAstrologer,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l10n.aiDisclaimer,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
          if (hasChart)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('aiInput'),
                        controller: _input,
                        enabled: !locked && !chat.sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l10n.aiInputHint,
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('aiSend'),
                      onPressed: locked || chat.sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final AiMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: user
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: user ? AppColors.primary : AppColors.outline,
            width: 0.8,
          ),
        ),
        child: SelectableText(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
    );
  }
}

class _NeedProfile extends StatelessWidget {
  final VoidCallback onCreate;

  const _NeedProfile({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.aiNeedProfile, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onCreate, child: Text(l10n.createBirthProfile)),
          ],
        ),
      ),
    );
  }
}
