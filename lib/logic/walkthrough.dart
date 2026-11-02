/// Scripted walkthrough engine.
///
/// Walkthroughs are data, not LLM output, so they are deterministic and never
/// confidently wrong (roadmap: "Walkthroughs: scripted step engine"). Each
/// step describes one mock screen as a list of plain elements, what to say
/// aloud, and the one action that moves forward. Any other action gets a
/// gentle pointer to the right control, never a "wrong".
///
/// Mock screens are generic drawings of the *shape* of each flow, clearly
/// labelled as practice. They copy no real app's branding.
library;

// ------------------------------------------------------------------ actions

/// What the learner did on a mock screen.
sealed class MockAction {
  const MockAction();
}

/// Tapped the control with this id.
class Tap extends MockAction {
  const Tap(this.target);
  final String target;
}

/// Pressed and held the control with this id (WhatsApp voice notes).
class LongPress extends MockAction {
  const LongPress(this.target);
  final String target;
}

/// Typed a number and pressed continue.
class EnterNumber extends MockAction {
  const EnterNumber(this.value);
  final int value;
}

/// Typed some text and pressed continue.
class EnterText extends MockAction {
  const EnterText(this.text);
  final String text;
}

/// Entered a PIN of this many digits and pressed the tick.
class EnterPin extends MockAction {
  const EnterPin(this.digits);
  final int digits;
}

enum Expect { tap, longPress, number, text, pin }

// ------------------------------------------------------------------ mock UI

/// One element of a mock screen. The renderer draws these top to bottom.
/// Text may contain {amount}, {balance}, {name} and {text} placeholders.
sealed class MockElement {
  const MockElement();
}

/// Large heading inside the mock app.
class MHeader extends MockElement {
  const MHeader(this.title, [this.subtitle]);
  final String title;
  final String? subtitle;
}

/// A button. [kind] picks its colour.
class MButton extends MockElement {
  const MButton(
    this.id,
    this.label, {
    this.icon = 'arrow',
    this.kind = MKind.primary,
  });
  final String id;
  final String label;
  final String icon;
  final MKind kind;
}

enum MKind { primary, success, danger, plain }

/// A row in a list: a chat, a contact, a bus, a dish.
class MTile extends MockElement {
  const MTile(
    this.id,
    this.title, {
    this.subtitle,
    this.leading,
    this.trailing,
  });
  final String id;
  final String title;
  final String? subtitle;

  /// A letter or short word shown in the circle on the left.
  final String? leading;

  /// Short text on the right (a price, a time).
  final String? trailing;
}

/// Big square icon buttons, two to a row.
class MGrid extends MockElement {
  const MGrid(this.items);
  final List<MButton> items;
}

/// A row of small icon buttons, like a chat's top bar.
class MIconBar extends MockElement {
  const MIconBar(this.title, this.items);
  final String title;
  final List<MButton> items;
}

/// A chat bubble.
class MBubble extends MockElement {
  const MBubble(
    this.text, {
    this.fromMe = false,
    this.author,
    this.voice = false,
  });
  final String text;
  final bool fromMe;
  final String? author;
  final bool voice;
}

/// A chat input bar with attach, camera and a hold-to-record mic.
class MComposer extends MockElement {
  const MComposer({
    this.attachId = 'attach',
    this.cameraId = 'camera',
    this.micId = 'mic',
  });
  final String attachId;
  final String cameraId;
  final String micId;
}

/// A big value, like an amount or a balance.
class MBig extends MockElement {
  const MBig(this.text, [this.caption]);
  final String text;
  final String? caption;
}

/// A plain note inside the mock app. [warning] draws it in red.
class MNote extends MockElement {
  const MNote(this.text, {this.warning = false});
  final String text;
  final bool warning;
}

/// An SMS as it appears in the messages app.
class MSms extends MockElement {
  const MSms(this.from, this.text);
  final String from;
  final String text;
}

/// A tappable QR code (stands in for pointing the camera).
class MQr extends MockElement {
  const MQr(this.id, this.caption);
  final String id;
  final String caption;
}

/// A big success tick.
class MTick extends MockElement {
  const MTick();
}

/// A number field + continue button. Completes [Expect.number].
class MNumberInput extends MockElement {
  const MNumberInput({
    this.prefix = '₹ ',
    this.hint = '0',
    this.button = 'அடுத்து',
  });
  final String prefix;
  final String hint;
  final String button;
}

/// A text field + continue button. Completes [Expect.text].
class MTextInput extends MockElement {
  const MTextInput({required this.hint, this.button = 'தேடு'});
  final String hint;
  final String button;
}

/// A large keypad for a UPI PIN. Completes [Expect.pin].
class MPinPad extends MockElement {
  const MPinPad();
}

/// What a mock screen looks like.
class MockView {
  const MockView({
    required this.app,
    required this.elements,
    this.color = 0xFF0B5D4B,
  });

  /// Shown in the mock app's top bar, e.g. "பயிற்சி: WhatsApp".
  final String app;
  final int color;
  final List<MockElement> elements;
}

// ------------------------------------------------------------------ script

/// What happens when a step's action is done.
enum StepEffect { none, debitAmount }

class WalkStep {
  const WalkStep({
    required this.view,
    required this.say,
    required this.expects,
    this.target,
    this.hint,
    this.hints = const {},
    this.minNumber = 1,
    this.maxIsBalance = false,
    this.setAmount,
    this.effect = StepEffect.none,
  });

  final MockView view;

  /// Spoken aloud (Tamil) when the step starts, and shown in large text.
  final String say;

  final Expect expects;

  /// For tap and long-press steps: the control that moves on. Highlighted.
  final String? target;

  /// Said when he does something else. Points at the right control.
  final String? hint;

  /// Said instead of [hint] when he taps a particular other control, to
  /// explain why (used in the safety walkthroughs).
  final Map<String, String> hints;

  /// For number steps.
  final int minNumber;
  final bool maxIsBalance;

  /// Fixes {amount} when the step starts (a ticket with a set price).
  final int? setAmount;

  final StepEffect effect;
}

enum WalkCategory { money, whatsapp, safety, travel, food, maps }

const categoryTitles = {
  WalkCategory.whatsapp: 'WhatsApp',
  WalkCategory.money: 'பணம் (UPI)',
  WalkCategory.safety: 'பாதுகாப்பு',
  WalkCategory.travel: 'பயணம்',
  WalkCategory.food: 'உணவு',
  WalkCategory.maps: 'வழி கண்டுபிடிக்க',
};

class Walkthrough {
  const Walkthrough({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.steps,
    this.recipient = practiceRecipient,
  });

  final String id;
  final String title;
  final String summary;
  final WalkCategory category;
  final List<WalkStep> steps;

  /// Fills {name}.
  final String recipient;
}

/// Name of the pretend person in practice contact lists.
const practiceRecipient = 'முருகன்';
const practiceStartBalance = 5000;

/// Result of handling an action.
class StepResult {
  const StepResult({required this.advanced, this.message});
  final bool advanced;

  /// Text to speak: the next step's narration, or a hint.
  final String? message;
}

/// Runs one walkthrough over a fake balance. Moves no money: there is no
/// network or payment code anywhere in this module.
class WalkthroughSession {
  WalkthroughSession(this.walkthrough, {this.balance = practiceStartBalance}) {
    _enter();
  }

  final Walkthrough walkthrough;
  int balance;
  int index = 0;
  int? amount;
  String text = '';
  bool _done = false;

  WalkStep get step => walkthrough.steps[index];

  /// True once the last step's action has been done.
  bool get completed => _done;

  void _enter() {
    final set = step.setAmount;
    if (set != null) amount = set;
  }

  StepResult _hint([String? target]) {
    final s = step;
    final special = target == null ? null : s.hints[target];
    final m = special ?? s.hint;
    return StepResult(advanced: false, message: m == null ? null : fill(m));
  }

  /// Handle [action] on the current step.
  StepResult handle(MockAction action) {
    if (_done) return const StepResult(advanced: false);
    final s = step;

    switch ((s.expects, action)) {
      case (Expect.tap, Tap(:final target)):
        if (target != s.target) return _hint(target);
      case (Expect.longPress, LongPress(:final target)):
        if (target != s.target) return _hint(target);
      case (Expect.longPress, Tap(:final target)) when target == s.target:
        return const StepResult(
          advanced: false,
          message: 'தொட்டவுடன் விரலை எடுக்க வேண்டாம். அழுத்திப் பிடித்துக்கொண்டே இருங்கள்.',
        );
      case (Expect.number, EnterNumber(:final value)):
        if (value < s.minNumber) {
          return const StepResult(
            advanced: false,
            message: 'ஒரு தொகையை எண்களில் போடுங்கள். உதாரணமாக 100.',
          );
        }
        if (s.maxIsBalance && value > balance) {
          return const StepResult(
            advanced: false,
            message: 'இருப்பை விடக் குறைவான தொகை போடுங்கள்.',
          );
        }
        amount = value;
      case (Expect.text, EnterText(text: final t)):
        if (t.trim().isEmpty) {
          return const StepResult(
            advanced: false,
            message: 'ஏதாவது ஒரு சொல்லைப் போட்டு அழுத்துங்கள்.',
          );
        }
        text = t.trim();
      case (Expect.pin, EnterPin(:final digits)):
        if (digits != 4 && digits != 6) {
          return const StepResult(
            advanced: false,
            message: 'PIN நான்கு அல்லது ஆறு எண்கள். இது பயிற்சி, எந்த எண்ணும் போடலாம்.',
          );
        }
      case (_, Tap(:final target)):
        return _hint(target);
      case (_, LongPress(:final target)):
        return _hint(target);
      default:
        return _hint();
    }

    // The pretend payment "happens" only in this practice object.
    if (s.effect == StepEffect.debitAmount && amount != null) {
      balance -= amount!;
    }

    if (index == walkthrough.steps.length - 1) {
      _done = true;
      return const StepResult(advanced: true);
    }
    index++;
    _enter();
    return StepResult(advanced: true, message: narration(step));
  }

  /// The narration for [s], with the practice values filled in.
  String narration(WalkStep s) => fill(s.say);

  String fill(String t) => t
      .replaceAll('{amount}', '${amount ?? 0}')
      .replaceAll('{balance}', '$balance')
      .replaceAll('{name}', walkthrough.recipient)
      .replaceAll('{text}', text);

  /// Start again from the first step, with the balance reset. Unlimited.
  void restart() {
    index = 0;
    amount = null;
    text = '';
    balance = practiceStartBalance;
    _done = false;
    _enter();
  }
}

/// The action that moves [step] forward, for tests and for a future
/// "show me" demo mode.
MockAction goldenAction(WalkStep step) => switch (step.expects) {
  Expect.tap => Tap(step.target!),
  Expect.longPress => LongPress(step.target!),
  Expect.number => EnterNumber(step.minNumber < 100 ? 100 : step.minNumber),
  Expect.text => const EnterText('கோயில்'),
  Expect.pin => const EnterPin(4),
};
