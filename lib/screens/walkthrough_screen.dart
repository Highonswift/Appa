import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/dish_glossary.dart';
import '../data/walkthroughs.dart';
import '../logic/walkthrough.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The walkthrough library, grouped by topic in the library's own order.
class WalkthroughListScreen extends StatelessWidget {
  const WalkthroughListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final order = <WalkCategory>[];
    for (final w in walkthroughLibrary) {
      if (!order.contains(w.category)) order.add(w.category);
    }

    return AppScreen(
      title: 'கற்றுக்கொள்வோம்',
      speakText:
          'இங்கே எல்லாம் பயிற்சி மட்டும். உண்மையான பணமோ செய்தியோ எங்கும் போகாது. '
          'எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteBox(
            icon: Icons.shield_outlined,
            color: AppColors.practice,
            text: 'இங்கே எல்லாம் பயிற்சி மட்டும். உண்மையான பணமோ செய்தியோ எங்கும் போகாது. எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம்.',
          ),
          for (final cat in order) ...[
            const SizedBox(height: 24),
            Text(categoryTitles[cat]!, style: t.titleLarge),
            const SizedBox(height: 10),
            for (final w in walkthroughLibrary.where(
              (w) => w.category == cat,
            )) ...[
              _WalkTile(
                w: w,
                done: s.completedWalkthroughs.contains(w.id),
                real: s.realWorldDone.contains(w.id),
              ),
              const SizedBox(height: 12),
            ],
            if (cat == WalkCategory.food)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                ),
                icon: const Icon(Icons.menu_book, size: 28),
                label: const Text('மெனுவில் வரும் உணவுப் பெயர்கள்'),
              ),
          ],
        ],
      ),
    );
  }
}

class _WalkTile extends StatelessWidget {
  const _WalkTile({required this.w, required this.done, required this.real});
  final Walkthrough w;
  final bool done;
  final bool real;

  static const _icons = {
    WalkCategory.whatsapp: Icons.chat,
    WalkCategory.money: Icons.currency_rupee,
    WalkCategory.safety: Icons.shield,
    WalkCategory.travel: Icons.directions_bus,
    WalkCategory.food: Icons.restaurant,
    WalkCategory.maps: Icons.map,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeTile(
          icon: _icons[w.category]!,
          title: w.title,
          subtitle: done ? '${w.summary}\n✓ செய்து பார்த்தீர்கள்' : w.summary,
          color: AppColors.practice,
          soft: const Color(0xFFF1E4F6),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WalkthroughScreen(walkthrough: w),
            ),
          ),
        ),
        // Self-reported, never asked twice (roadmap exit criterion: "done the
        // real thing at least once without help").
        if (done && !real)
          TextButton.icon(
            onPressed: () => s.markRealWorldDone(w.id),
            icon: const Icon(Icons.verified_outlined, size: 26),
            label: const Text('உண்மையான ஆப்பில் நானே செய்தேன்'),
          ),
        if (real)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Text(
              '✓ உண்மையான ஆப்பிலும் நீங்களே செய்தீர்கள்',
              style: t.bodyMedium?.copyWith(
                color: AppColors.callGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Runs one walkthrough on a mock phone screen.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, required this.walkthrough});
  final Walkthrough walkthrough;
  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  late final WalkthroughSession session = WalkthroughSession(
    widget.walkthrough,
  );
  String? hint;
  bool firstTime = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _say(session.narration(session.step)),
    );
  }

  void _say(String text) => context.read<AppState>().speaker.speak(text);

  Future<void> _act(MockAction a) async {
    final r = session.handle(a);
    if (!r.advanced) {
      setState(() => hint = r.message);
      if (r.message != null) _say(r.message!);
      return;
    }
    if (session.completed) {
      final first = await context.read<AppState>().markWalkthroughDone(
        widget.walkthrough.id,
      );
      setState(() {
        hint = null;
        firstTime = first;
      });
      _say(
        first
            ? 'நீங்களே முழுவதும் செய்து முடித்தீர்கள். உண்மையான ஆப்பிலும் இதே மாதிரி தான்.'
            : 'முடிந்தது.',
      );
      return;
    }
    setState(() => hint = null);
    if (r.message != null) _say(r.message!);
  }

  void _restart() {
    setState(() {
      session.restart();
      firstTime = false;
      hint = null;
    });
    _say(session.narration(session.step));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final step = session.step;

    return AppScreen(
      title: widget.walkthrough.title,
      speakText: session.completed ? 'முடிந்தது' : session.narration(step),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.practice,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'பயிற்சி — உண்மையானது இல்லை',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (session.completed) ...[
            NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: firstTime
                  ? 'நீங்களே முழுவதும் செய்து முடித்தீர்கள். உண்மையான ஆப்பிலும் இதே மாதிரி தான்.'
                  : 'முடிந்தது.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay, size: 32),
              label: const Text('மீண்டும் செய்து பார்'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('போதும்'),
            ),
          ] else ...[
            Text(
              'படி ${session.index + 1} / ${widget.walkthrough.steps.length}',
              style: t.titleMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(session.narration(step), style: t.bodyLarge),
            if (hint != null) ...[
              const SizedBox(height: 10),
              NoteBox(
                text: hint!,
                icon: Icons.touch_app,
                color: AppColors.accent,
              ),
            ],
            const SizedBox(height: 16),
            MockPhone(
              key: ValueKey('${widget.walkthrough.id}-${session.index}'),
              session: session,
              onAction: _act,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay, size: 26),
              label: const Text('முதலிலிருந்து'),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Mock phone renderer. Draws a step's MockView element by element; the
// control the narration points at glows yellow.

const _iconMap = <String, IconData>{
  'arrow': Icons.arrow_forward,
  'play': Icons.play_arrow_rounded,
  'send': Icons.send_rounded,
  'qr': Icons.qr_code_scanner,
  'wallet': Icons.account_balance_wallet,
  'history': Icons.history,
  'done': Icons.done_all,
  'video': Icons.videocam,
  'call': Icons.call,
  'end': Icons.call_end,
  'photo': Icons.photo_library,
  'camera': Icons.photo_camera,
  'doc': Icons.description,
  'pin': Icons.location_on,
  'chat': Icons.chat_bubble_outline,
  'search': Icons.search,
  'seat': Icons.event_seat,
  'cash': Icons.payments,
  'directions': Icons.directions,
  'share': Icons.share,
  'walk': Icons.directions_walk,
  'bike': Icons.two_wheeler,
};

class MockPhone extends StatelessWidget {
  const MockPhone({super.key, required this.session, required this.onAction});
  final WalkthroughSession session;
  final void Function(MockAction) onAction;

  @override
  Widget build(BuildContext context) {
    final view = session.step.view;
    final appColor = Color(view.color);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink, width: 6),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: appColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              view.app,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in view.elements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _element(e, appColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _f(String s) => session.fill(s);
  bool _target(String id) => session.step.target == id;

  Color _kindColor(MKind k, Color app) => switch (k) {
    MKind.primary => app,
    MKind.success => AppColors.callGreen,
    MKind.danger => const Color(0xFFC62828),
    MKind.plain => const Color(0xFFEFF3F8),
  };

  Widget _element(MockElement e, Color app) => switch (e) {
    MHeader(:final title, :final subtitle) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _f(title),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Text(
            _f(subtitle),
            style: const TextStyle(fontSize: 18, color: AppColors.muted),
          ),
      ],
    ),
    MButton() => _button(e, app),
    MTile() => _tile(e),
    MGrid(:final items) => _grid(items, app),
    MIconBar(:final title, :final items) => Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: app,
          child: Text(
            title.characters.first,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _f(title),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final b in items)
          Glow(
            on: _target(b.id),
            child: IconButton(
              tooltip: b.label,
              iconSize: 32,
              onPressed: () => onAction(Tap(b.id)),
              icon: Icon(_iconMap[b.icon] ?? Icons.circle, color: app),
            ),
          ),
      ],
    ),
    MBubble(:final text, :final fromMe, :final author, :final voice) => Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromMe ? const Color(0xFFDCF8C6) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (author != null)
              Text(
                author,
                style: TextStyle(
                  fontSize: 15,
                  color: app,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (voice)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, size: 28),
                  Container(width: 110, height: 3, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Text(text, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.done_all,
                    size: 18,
                    color: Color(0xFF34B7F1),
                  ),
                ],
              )
            else
              Text(_f(text), style: const TextStyle(fontSize: 19)),
          ],
        ),
      ),
    ),
    MComposer(:final attachId, :final cameraId, :final micId) => Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCCCCCC)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Text(
                      'செய்தி',
                      style: TextStyle(fontSize: 18, color: AppColors.muted),
                    ),
                  ),
                ),
                Glow(
                  on: _target(attachId),
                  child: IconButton(
                    tooltip: 'இணை',
                    iconSize: 30,
                    onPressed: () => onAction(Tap(attachId)),
                    icon: const Icon(Icons.attach_file),
                  ),
                ),
                Glow(
                  on: _target(cameraId),
                  child: IconButton(
                    tooltip: 'கேமரா',
                    iconSize: 30,
                    onPressed: () => onAction(Tap(cameraId)),
                    icon: const Icon(Icons.photo_camera),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Glow(
          on: _target(micId),
          circle: true,
          child: Semantics(
            button: true,
            label: 'மைக்: அழுத்திப் பிடியுங்கள்',
            child: GestureDetector(
              onTap: () => onAction(Tap(micId)),
              onLongPress: () => onAction(LongPress(micId)),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: app,
                child: const Icon(Icons.mic, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ],
    ),
    MBig(:final text, :final caption) => Column(
      children: [
        Text(
          _f(text),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
        ),
        if (caption != null)
          Text(
            _f(caption),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppColors.muted),
          ),
      ],
    ),
    MNote(:final text, :final warning) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFDECEA) : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _f(text),
        style: TextStyle(
          fontSize: 18,
          color: warning ? const Color(0xFFB71C1C) : AppColors.ink,
          fontWeight: warning ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
    MSms(:final from, :final text) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            from,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 19)),
        ],
      ),
    ),
    MQr(:final id, :final caption) => Center(
      child: Glow(
        on: _target(id),
        child: InkWell(
          onTap: () => onAction(Tap(id)),
          child: Column(
            children: [
              const Icon(Icons.qr_code_2, size: 160),
              Text(caption, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    ),
    MTick() => const Icon(
      Icons.check_circle,
      size: 110,
      color: AppColors.callGreen,
    ),
    MNumberInput() => _NumberEntry(spec: e, onAction: onAction),
    MTextInput() => _TextEntry(spec: e, onAction: onAction),
    MPinPad() => _PinEntry(onAction: onAction),
  };

  Widget _button(MButton b, Color app) {
    final bg = _kindColor(b.kind, app);
    final plain = b.kind == MKind.plain;
    return Glow(
      on: _target(b.id),
      child: FilledButton.icon(
        onPressed: () => onAction(Tap(b.id)),
        icon: Icon(_iconMap[b.icon] ?? Icons.arrow_forward, size: 30),
        label: Text(_f(b.label)),
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: plain ? AppColors.ink : Colors.white,
        ),
      ),
    );
  }

  Widget _tile(MTile tile) => Glow(
    on: _target(tile.id),
    child: Material(
      color: const Color(0xFFEFF3F8),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        minVerticalPadding: 16,
        onTap: () => onAction(Tap(tile.id)),
        leading: tile.leading == null
            ? null
            : CircleAvatar(
                radius: 26,
                child: Text(
                  tile.leading!,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
        title: Text(
          _f(tile.title),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        subtitle: tile.subtitle == null
            ? null
            : Text(_f(tile.subtitle!), style: const TextStyle(fontSize: 16)),
        trailing: tile.trailing == null
            ? null
            : Text(
                tile.trailing!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    ),
  );

  Widget _grid(List<MButton> items, Color app) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _gridItem(items[i], app)),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < items.length
                    ? _gridItem(items[i + 1], app)
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < items.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _gridItem(MButton b, Color app) => Glow(
    on: _target(b.id),
    child: Material(
      color: const Color(0xFFEFF3F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onAction(Tap(b.id)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconMap[b.icon] ?? Icons.circle, size: 40, color: app),
              const SizedBox(height: 8),
              Text(
                _f(b.label),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NumberEntry extends StatefulWidget {
  const _NumberEntry({required this.spec, required this.onAction});
  final MNumberInput spec;
  final void Function(MockAction) onAction;
  @override
  State<_NumberEntry> createState() => _NumberEntryState();
}

class _NumberEntryState extends State<_NumberEntry> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Glow(
        on: true,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: widget.spec.prefix,
            hintText: widget.spec.hint,
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () =>
            widget.onAction(EnterNumber(int.tryParse(c.text) ?? 0)),
        child: Text(widget.spec.button),
      ),
    ],
  );
}

class _TextEntry extends StatefulWidget {
  const _TextEntry({required this.spec, required this.onAction});
  final MTextInput spec;
  final void Function(MockAction) onAction;
  @override
  State<_TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Glow(
        on: true,
        child: TextField(
          controller: c,
          style: const TextStyle(fontSize: 24),
          decoration: InputDecoration(
            hintText: widget.spec.hint,
            prefixIcon: const Icon(Icons.search, size: 28),
          ),
          onSubmitted: (v) => widget.onAction(EnterText(v)),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => widget.onAction(EnterText(c.text)),
        child: Text(widget.spec.button),
      ),
    ],
  );
}

/// A large on-screen keypad, so practice never depends on the phone keyboard.
class _PinEntry extends StatefulWidget {
  const _PinEntry({required this.onAction});
  final void Function(MockAction) onAction;
  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  int digits = 0;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 32)
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    void add() => setState(() => digits = (digits + 1).clamp(0, 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < digits ? AppColors.ink : Colors.transparent,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, add)]),
        Row(
          children: [
            key(
              '',
              () => setState(() => digits = (digits - 1).clamp(0, 6)),
              icon: Icons.backspace_outlined,
            ),
            key('0', add),
            key('', () {
              widget.onAction(EnterPin(digits));
              setState(() => digits = 0);
            }, icon: Icons.check_circle),
          ],
        ),
      ],
    );
  }
}

/// Yellow glow around the control the narration is pointing at.
class Glow extends StatelessWidget {
  const Glow({
    super.key,
    required this.on,
    required this.child,
    this.circle = false,
  });
  final bool on;
  final bool circle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return Container(
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(20),
        border: Border.all(color: AppColors.highlight, width: 5),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlight.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: child,
    );
  }
}

/// Restaurant dish names explained in Tamil, read aloud on tap.
class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.read<AppState>();
    return AppScreen(
      title: 'உணவுப் பெயர்கள்',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'மெனுவில் ஆங்கிலத்தில் வரும் உணவுகள். அழுத்தினால் படித்துக் காட்டும்.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          for (final d in dishGlossary)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                minVerticalPadding: 14,
                title: Text('${d.tamil}  ·  ${d.name}', style: t.titleMedium),
                subtitle: Text(d.explain, style: t.bodyMedium),
                trailing: const Icon(
                  Icons.volume_up,
                  size: 28,
                  color: AppColors.primary,
                ),
                onTap: () => s.speaker.speak('${d.tamil}. ${d.explain}'),
              ),
            ),
        ],
      ),
    );
  }
}
