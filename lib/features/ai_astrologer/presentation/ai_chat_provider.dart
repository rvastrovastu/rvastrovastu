import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language_provider.dart';
import '../../astrology/presentation/providers/astrology_provider.dart';
import '../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../dasha/domain/entities/dasha_birth_data.dart';
import '../../dasha/presentation/providers/dasha_provider.dart';
import '../../gochar/presentation/providers/gochar_provider.dart';
import '../../membership/domain/membership.dart';
import '../../membership/presentation/providers/membership_provider.dart';
import '../data/ai_astrologer_service.dart';
import '../domain/chart_context.dart';

final aiAstrologerServiceProvider = Provider<AiAstrologerService>(
  (ref) => SupabaseAiAstrologerService(),
);

/// The active profile's chart summary for the AI, or null without one.
final aiChartContextProvider = FutureProvider<Map<String, Object?>?>((
  ref,
) async {
  final kundali = await ref.watch(kundaliProvider.future);
  final profile = ref.watch(birthProfileProvider);
  if (kundali == null || profile == null) return null;

  final birth = DashaBirthData(
    birthDate: profile.dateOfBirth,
    moonLongitude: kundali.moonLongitude,
  );
  final gochar = await ref
      .watch(gocharReportProvider.future)
      .catchError((Object _) => null);

  return buildChartContext(
    kundali: kundali,
    today: DateTime.now(),
    mahadasha: ref.watch(currentDashaProvider(birth)),
    antardasha: ref.watch(currentAntardashaProvider(birth)),
    gochar: gochar,
  );
});

class AiMessage {
  final bool fromUser;
  final String text;

  const AiMessage({required this.fromUser, required this.text});
}

enum AiProblem { none, limit, unavailable }

class AiChatState {
  final List<AiMessage> messages;
  final bool sending;
  final AiAllowance? allowance;
  final AiProblem problem;

  const AiChatState({
    this.messages = const [],
    this.sending = false,
    this.allowance,
    this.problem = AiProblem.none,
  });

  bool get limitReached =>
      problem == AiProblem.limit ||
      (allowance != null && allowance!.remaining <= 0);

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? sending,
    AiAllowance? allowance,
    AiProblem? problem,
  }) => AiChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    allowance: allowance ?? this.allowance,
    problem: problem ?? this.problem,
  );
}

/// The AI question pack with its store price, or null when unavailable.
final aiPackOfferProvider = FutureProvider.autoDispose<AiPackOffer?>((
  ref,
) async {
  try {
    await ref.read(membershipProvider.future);
    return await ref.watch(purchasesServiceProvider).aiPackOffer();
  } catch (_) {
    return null;
  }
});

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);

/// The conversation for this app session.
class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    Future.microtask(_loadStatus);
    return const AiChatState();
  }

  Future<void> _loadStatus() async {
    final allowance = await ref.read(aiAstrologerServiceProvider).status();
    if (allowance != null) state = state.copyWith(allowance: allowance);
  }

  /// Re-reads the allowance after a pack purchase. The store can take a
  /// few seconds to report it, so this tries a few times.
  Future<bool> refreshAfterPurchase({
    Duration wait = const Duration(seconds: 2),
  }) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final allowance = await ref.read(aiAstrologerServiceProvider).status();
      if (allowance != null && allowance.remaining > 0) {
        state = state.copyWith(allowance: allowance, problem: AiProblem.none);
        return true;
      }
      await Future<void>.delayed(wait);
    }
    return false;
  }

  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.sending) return;

    final chart = await ref.read(aiChartContextProvider.future);
    if (chart == null) return;

    final history = [
      for (final m in state.messages) (fromUser: m.fromUser, text: m.text),
    ];
    state = state.copyWith(
      messages: [...state.messages, AiMessage(fromUser: true, text: text)],
      sending: true,
      problem: AiProblem.none,
    );

    try {
      final answer = await ref
          .read(aiAstrologerServiceProvider)
          .ask(
            question: text,
            chart: chart,
            history: history,
            language: ref.read(languageProvider).code,
          );
      state = state.copyWith(
        messages: [
          ...state.messages,
          AiMessage(fromUser: false, text: answer.text),
        ],
        sending: false,
        allowance: answer.allowance,
      );
    } on AiLimitReached catch (e) {
      state = state.copyWith(
        sending: false,
        allowance: e.allowance,
        problem: AiProblem.limit,
      );
    } catch (_) {
      state = state.copyWith(sending: false, problem: AiProblem.unavailable);
    }
  }
}
