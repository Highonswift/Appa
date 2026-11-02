import '../logic/walkthrough.dart';

/// The walkthrough library, in the order shown to Appa.
///
/// Roadmap: build in the order Appa ranks them at the week-3 review; this
/// order is a starting guess. Reorder [walkthroughLibrary] to match his
/// ranking. Every line is plain spoken Tamil written by the team; the Tamil
/// content writer and Appa should review each one before it ships to him.
///
/// Not yet scripted (need his real details first): his own bank's app, and
/// his pension portal / Aadhaar flows.

const _upiColor = 0xFF0B5D4B;
const _waColor = 0xFF128C7E;
const _busColor = 0xFFB71C1C;
const _foodColor = 0xFFE65100;
const _mapColor = 0xFF1565C0;
const _smsColor = 0xFF37474F;

const _upi = 'பயிற்சி: UPI ஆப்';
const _wa = 'பயிற்சி: WhatsApp';

// ---------------------------------------------------------------- shared views

WalkStep _intro(String say) => WalkStep(
  view: const MockView(
    app: 'பயிற்சி',
    color: 0xFF6A1B9A,
    elements: [
      MHeader('பயிற்சி', 'உண்மையான பணம், உண்மையான செய்தி எதுவும் போகாது'),
      MButton('start', 'தொடங்கு', icon: 'play'),
    ],
  ),
  say: say,
  expects: Expect.tap,
  target: 'start',
  hint: 'கீழே உள்ள "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
);

const _upiHome = MockView(
  app: _upi,
  color: _upiColor,
  elements: [
    MHeader('வணக்கம்!'),
    MGrid([
      MButton('scan', 'QR ஸ்கேன்', icon: 'qr'),
      MButton('pay', 'பணம் அனுப்பு', icon: 'send'),
      MButton('balance', 'இருப்பு பார்', icon: 'wallet'),
      MButton('history', 'பழைய பரிவர்த்தனை', icon: 'history'),
    ]),
  ],
);

const _pinView = MockView(
  app: _upi,
  color: _upiColor,
  elements: [
    MHeader('UPI PIN போடுங்கள்'),
    MNote('இந்த எண்ணை யாரிடமும் சொல்லக் கூடாது', warning: true),
    MPinPad(),
  ],
);

WalkStep _done(MockView view, String say) => WalkStep(
  view: view,
  say: say,
  expects: Expect.tap,
  target: 'done',
  hint: '"முடிந்தது" பொத்தானை அழுத்துங்கள்.',
);

const _doneButton = MButton(
  'done',
  'முடிந்தது',
  icon: 'done',
  kind: MKind.success,
);

const _waChats = MockView(
  app: _wa,
  color: _waColor,
  elements: [
    MHeader('அரட்டைகள்'),
    MTile(
      'family',
      'குடும்பம் (பயிற்சி)',
      subtitle: 'ராகுல்: அப்பா, இன்று சாப்பிட்டீர்களா?',
      leading: 'கு',
      trailing: '9:41',
    ),
    MTile(
      'ragul',
      'ராகுல்',
      subtitle: 'சரி அப்பா',
      leading: 'ரா',
      trailing: 'நேற்று',
    ),
    MTile(
      'murugan',
      'முருகன்',
      subtitle: 'ஞாயிறு டிப்போவில் சந்திப்போம்',
      leading: 'மு',
      trailing: 'திங்கள்',
    ),
  ],
);

const _waFamilyChat = MockView(
  app: _wa,
  color: _waColor,
  elements: [
    MIconBar('குடும்பம் (பயிற்சி)', [
      MButton('video', 'வீடியோ', icon: 'video', kind: MKind.plain),
      MButton('call', 'கால்', icon: 'call', kind: MKind.plain),
    ]),
    MBubble('அப்பா, இன்று சாப்பிட்டீர்களா?', author: 'ராகுல்'),
    MBubble('பேரன் இன்று பள்ளியில் பரிசு வாங்கினான்!', author: 'மருமகள்'),
    MComposer(),
  ],
);

// ---------------------------------------------------------------- money

const sendMoneyWalkthrough = Walkthrough(
  id: 'upi-send',
  title: 'பணம் அனுப்புவது',
  summary: 'GPay போன்ற UPI ஆப்பில் ஒருவருக்குப் பணம் அனுப்பும் முறை',
  category: WalkCategory.money,
  steps: [
    WalkStep(
      view: MockView(
        app: 'பயிற்சி',
        color: 0xFF6A1B9A,
        elements: [
          MHeader('பயிற்சி', 'உண்மையான பணம் எங்கும் போகாது'),
          MButton('start', 'தொடங்கு', icon: 'play'),
        ],
      ),
      say: 'இது பயிற்சி மட்டும். உண்மையான பணம் எங்கும் போகாது. எத்தனை தடவை வேண்டுமானாலும் செய்து பார்க்கலாம். தொடங்க, "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'start',
      hint: 'கீழே உள்ள "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      view: _upiHome,
      say: 'இது ஆப்பின் முதல் பக்கம். GPay-யிலும் இதே மாதிரி இருக்கும். ஒருவருக்குப் பணம் அனுப்ப, "பணம் அனுப்பு" என்ற பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'pay',
      hint: 'மஞ்சள் நிறத்தில் மின்னும் "பணம் அனுப்பு" பொத்தானை அழுத்துங்கள்.',
    ),
    WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MHeader('யாருக்கு அனுப்ப?'),
          MTile('other1', 'கணேசன்', subtitle: '98xxx xxxxx', leading: 'க'),
          MTile(
            'contact',
            practiceRecipient,
            subtitle: '98xxx xxxxx',
            leading: 'மு',
          ),
          MTile('other2', 'லட்சுமி', subtitle: '98xxx xxxxx', leading: 'ல'),
        ],
      ),
      say: 'இப்போது யாருக்கு அனுப்ப வேண்டுமோ, அவர் பெயரை அழுத்துங்கள். இங்கே {name} பெயரை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'contact',
      hint: '{name} என்ற பெயரை அழுத்துங்கள்.',
    ),
    WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [MHeader('$practiceRecipient-க்கு'), MNumberInput()],
      ),
      say: 'எவ்வளவு பணம் அனுப்ப வேண்டும் என்று எண்களில் போடுங்கள். பிறகு "அடுத்து" அழுத்துங்கள்.',
      expects: Expect.number,
      maxIsBalance: true,
      hint: 'ஒரு தொகையை எண்களில் போட்டு "அடுத்து" அழுத்துங்கள்.',
    ),
    WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MHeader('சரிபார்க்கவும்'),
          MBig(practiceRecipient, 'பெயர்'),
          MBig('₹ {amount}', 'தொகை'),
          MButton('send', 'அனுப்பு', icon: 'send'),
          MButton('cancel', 'ரத்து', kind: MKind.plain),
        ],
      ),
      say: 'அனுப்பும் முன் இரண்டு விஷயம் பாருங்கள்: பெயர் {name} தானா, தொகை {amount} ரூபாய் தானா. சரி என்றால், "அனுப்பு" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'send',
      hint: 'பெயரும் தொகையும் சரியா என்று பார்த்து, "அனுப்பு" அழுத்துங்கள்.',
    ),
    WalkStep(
      view: _pinView,
      say: 'இப்போது UPI PIN கேட்கும். இது உங்கள் ரகசிய எண். வங்கியிலிருந்து பேசுவதாகச் சொன்னாலும், யாரிடமும் இதைச் சொல்லக் கூடாது. இது பயிற்சி, அதனால் எந்த நான்கு எண்ணும் போடலாம்.',
      expects: Expect.pin,
      effect: StepEffect.debitAmount,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MTick(),
          MBig('₹ {amount}', '$practiceRecipient-க்கு அனுப்பப்பட்டது'),
          MNote('பயிற்சி இருப்பு: ₹ {balance}'),
          _doneButton,
        ],
      ),
      say: '{amount} ரூபாய் {name}-க்குப் போய்விட்டது என்று காட்டுகிறது. பச்சை சரி குறி வந்தால் பணம் போய்விட்டது. பயிற்சி இருப்பு இப்போது {balance} ரூபாய். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'done',
      hint: '"முடிந்தது" பொத்தானை அழுத்துங்கள்.',
    ),
  ],
);

final checkBalanceWalkthrough = Walkthrough(
  id: 'upi-balance',
  title: 'இருப்பு பார்ப்பது',
  summary: 'வங்கிக் கணக்கில் எவ்வளவு பணம் இருக்கிறது என்று பார்க்கும் முறை',
  category: WalkCategory.money,
  steps: [
    _intro(
      'இது பயிற்சி மட்டும். வங்கிக் கணக்கில் எவ்வளவு பணம் இருக்கிறது என்று பார்க்கக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _upiHome,
      say: 'முதல் பக்கத்தில் "இருப்பு பார்" என்ற பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'balance',
      hint: 'மஞ்சள் நிறத்தில் மின்னும் "இருப்பு பார்" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _pinView,
      say: 'இருப்பு பார்க்கவும் UPI PIN கேட்கும். இதை யாரிடமும் சொல்லக் கூடாது. பயிற்சிக்கு எந்த நான்கு எண்ணும் போடுங்கள்.',
      expects: Expect.pin,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: _upi,
        color: _upiColor,
        elements: [MBig('₹ {balance}', 'கணக்கு இருப்பு'), _doneButton],
      ),
      'உங்கள் பயிற்சிக் கணக்கில் {balance} ரூபாய் இருக்கிறது என்று காட்டுகிறது. முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

final scanQrWalkthrough = Walkthrough(
  id: 'upi-scan',
  title: 'கடையில் QR ஸ்கேன் செய்து பணம் கட்டுவது',
  summary:
      'கடையில் ஒட்டியிருக்கும் சதுரப் படத்தை ஸ்கேன் செய்து பணம் கட்டும் முறை',
  category: WalkCategory.money,
  recipient: 'ஸ்ரீ முருகன் மளிகை',
  steps: [
    _intro(
      'இது பயிற்சி. கடையில் QR படத்தை ஸ்கேன் செய்து பணம் கட்டக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _upiHome,
      say: 'முதல் பக்கத்தில் "QR ஸ்கேன்" பொத்தானை அழுத்துங்கள். போனின் கேமரா திறக்கும்.',
      expects: Expect.tap,
      target: 'scan',
      hint: 'மஞ்சள் நிறத்தில் மின்னும் "QR ஸ்கேன்" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MHeader('QR-க்கு நேராகப் பிடியுங்கள்'),
          MQr('qr', 'கடையின் QR'),
        ],
      ),
      say: 'கடையில் ஒட்டியிருக்கும் சதுரப் படத்துக்கு நேராக போனைப் பிடியுங்கள். தானாகவே படிக்கும். இங்கே பயிற்சிக்கு அந்தப் படத்தை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'qr',
      hint: 'நடுவில் உள்ள சதுரப் படத்தை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MHeader('ஸ்ரீ முருகன் மளிகை', 'கடையின் பெயர் சரியா என்று பாருங்கள்'),
          MNumberInput(),
        ],
      ),
      say: 'மேலே கடையின் பெயர் வரும். அது சரியா என்று பாருங்கள். பிறகு கடைக்காரர் சொன்ன தொகையைப் போட்டு "அடுத்து" அழுத்துங்கள்.',
      expects: Expect.number,
      maxIsBalance: true,
      hint: 'கடைக்காரர் சொன்ன தொகையை எண்களில் போட்டு "அடுத்து" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MHeader('சரிபார்க்கவும்'),
          MBig('ஸ்ரீ முருகன் மளிகை', 'கடை'),
          MBig('₹ {amount}', 'தொகை'),
          MButton('send', 'பணம் கட்டு', icon: 'send'),
        ],
      ),
      say: 'கடையின் பெயரும் தொகை {amount} ரூபாயும் சரியா என்று பாருங்கள். சரி என்றால் "பணம் கட்டு" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'send',
      hint: '"பணம் கட்டு" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _pinView,
      say: 'UPI PIN போடுங்கள். கடைக்காரர் உட்பட யாரும் பார்க்காதபடி போனை மறைத்துப் போடுங்கள். பயிற்சிக்கு எந்த நான்கு எண்ணும் போடலாம்.',
      expects: Expect.pin,
      effect: StepEffect.debitAmount,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: _upi,
        color: _upiColor,
        elements: [
          MTick(),
          MBig('₹ {amount}', 'ஸ்ரீ முருகன் மளிகை-க்குக் கட்டப்பட்டது'),
          _doneButton,
        ],
      ),
      'பணம் போய்விட்டது. கடைக்காரரிடம் இந்தப் பச்சைக் குறியைக் காட்டுங்கள். அவர் போனிலும் பணம் வந்ததாகக் காட்டும். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

// ---------------------------------------------------------------- WhatsApp

final waVoiceNoteWalkthrough = Walkthrough(
  id: 'wa-voice',
  title: 'குரல் செய்தி அனுப்புவது',
  summary: 'எழுதாமல், பேசியே WhatsApp-இல் பதில் அனுப்பும் முறை',
  category: WalkCategory.whatsapp,
  steps: [
    _intro(
      'இது பயிற்சி. இங்கே அனுப்புவது யாருக்கும் போகாது. பேசியே WhatsApp-இல் பதில் அனுப்பக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _waChats,
      say: 'இது WhatsApp-இன் முதல் பக்கம். நீங்கள் பேசும் எல்லோரும் இங்கே வரிசையாக இருப்பார்கள். புதிய செய்தி வந்தவர் மேலே வருவார். "குடும்பம்" குழுவை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'family',
      hint: 'மேலே உள்ள "குடும்பம்" என்ற பெயரை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _waFamilyChat,
      say: 'இது குடும்பக் குழு. ராகுல் ஒரு கேள்வி கேட்டிருக்கிறார். பேசிப் பதில் அனுப்ப, கீழே வலது பக்கம் உள்ள மைக் பொத்தானைத் தொட்டு, விரலை எடுக்காமல் பிடித்துக்கொண்டே பேசுங்கள். பேசி முடிந்ததும் விரலை எடுங்கள்.',
      expects: Expect.longPress,
      target: 'mic',
      hint: 'கீழே வலது பக்கம் உள்ள மைக் பொத்தானை அழுத்திப் பிடியுங்கள்.',
    ),
    _done(
      const MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MIconBar('குடும்பம் (பயிற்சி)', []),
          MBubble('அப்பா, இன்று சாப்பிட்டீர்களா?', author: 'ராகுல்'),
          MBubble('0:06', fromMe: true, voice: true),
          _doneButton,
        ],
      ),
      'உங்கள் குரல் செய்தி போய்விட்டது. அதன் அருகில் இரண்டு நீலக் குறி வந்தால், அவர்கள் கேட்டுவிட்டார்கள் என்று அர்த்தம். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

final waVideoCallWalkthrough = Walkthrough(
  id: 'wa-video',
  title: 'வீடியோ கால் செய்வது',
  summary: 'முகம் பார்த்துப் பேசும் வீடியோ கால் செய்யும் முறை',
  category: WalkCategory.whatsapp,
  steps: [
    _intro(
      'இது பயிற்சி. இங்கே யாருக்கும் கால் போகாது. வீடியோ கால் செய்யக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _waChats,
      say: 'யாரிடம் பேச வேண்டுமோ அவர் பெயரை அழுத்துங்கள். இங்கே "ராகுல்" பெயரை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'ragul',
      hint: '"ராகுல்" என்ற பெயரை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MIconBar('ராகுல்', [
            MButton('video', 'வீடியோ', icon: 'video', kind: MKind.plain),
            MButton('call', 'கால்', icon: 'call', kind: MKind.plain),
          ]),
          MBubble('சரி அப்பா', author: 'ராகுல்'),
          MComposer(),
        ],
      ),
      say: 'மேலே வலது பக்கம் இரண்டு பொத்தான்கள் இருக்கும். கேமரா படம் வீடியோ கால், போன் படம் சாதாரண கால். கேமரா படத்தை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'video',
      hint: 'மேலே உள்ள கேமரா படத்தை (வீடியோ) அழுத்துங்கள்.',
      hints: {
        'call': 'அது சாதாரண கால். முகம் பார்க்க, அதன் அருகில் உள்ள கேமரா படத்தை அழுத்துங்கள்.',
      },
    ),
    const WalkStep(
      view: MockView(
        app: _wa,
        color: 0xFF263238,
        elements: [
          MHeader('ராகுல்', 'அழைக்கிறது…'),
          MBig('📹'),
          MButton('end', 'கால் முடி', icon: 'end', kind: MKind.danger),
        ],
      ),
      say: 'இப்போது ராகுலுக்கு மணி அடிக்கும். அவர் எடுத்ததும் இருவர் முகமும் தெரியும். போனை முகத்துக்கு நேராக, கை நீளத்தில் பிடியுங்கள். பேசி முடிந்ததும் கீழே உள்ள சிவப்புப் பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'end',
      hint: 'கீழே உள்ள சிவப்பு "கால் முடி" பொத்தானை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: _wa,
        color: _waColor,
        elements: [MNote('வீடியோ கால் · 0:00'), _doneButton],
      ),
      'கால் முடிந்தது. அடுத்த முறை ராகுலே அழைத்தால், பச்சைப் பொத்தானை அழுத்தி எடுக்கலாம். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

final waPhotoWalkthrough = Walkthrough(
  id: 'wa-photo',
  title: 'படம் அனுப்புவது',
  summary: 'போனில் உள்ள படத்தைக் குடும்பக் குழுவுக்கு அனுப்பும் முறை',
  category: WalkCategory.whatsapp,
  steps: [
    _intro(
      'இது பயிற்சி. இங்கே அனுப்பும் படம் யாருக்கும் போகாது. "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _waChats,
      say: '"குடும்பம்" குழுவை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'family',
      hint: 'மேலே உள்ள "குடும்பம்" என்ற பெயரை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _waFamilyChat,
      say: 'படம் அனுப்ப, கீழே எழுதும் இடத்தின் அருகில் உள்ள குண்டூசி போன்ற "இணை" பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'attach',
      hint: 'கீழே உள்ள "இணை" பொத்தானை அழுத்துங்கள்.',
      hints: {
        'mic': 'அது குரல் செய்திக்கு. படத்துக்கு, அதன் அருகில் உள்ள "இணை" பொத்தானை அழுத்துங்கள்.',
      },
    ),
    const WalkStep(
      view: MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MHeader('எதை அனுப்ப?'),
          MGrid([
            MButton('gallery', 'கேலரி (படங்கள்)', icon: 'photo'),
            MButton('camera2', 'கேமரா', icon: 'camera'),
            MButton('document', 'ஆவணம்', icon: 'doc'),
            MButton('location', 'இடம்', icon: 'pin'),
          ]),
        ],
      ),
      say: 'போனில் ஏற்கனவே உள்ள படத்தை அனுப்ப "கேலரி" அழுத்துங்கள். புதிதாக எடுக்க "கேமரா".',
      expects: Expect.tap,
      target: 'gallery',
      hint: '"கேலரி" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MHeader('படங்கள்'),
          MTile('photo1', 'கோயில் திருவிழா', leading: '🛕'),
          MTile('photo2', 'பேரனின் பள்ளி விழா', leading: '🧒'),
          MTile('photo3', 'வீட்டுத் தோட்டம்', leading: '🌿'),
        ],
      ),
      say: 'அனுப்ப வேண்டிய படத்தை அழுத்துங்கள். இங்கே "வீட்டுத் தோட்டம்" படத்தை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'photo3',
      hint: '"வீட்டுத் தோட்டம்" படத்தை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MBig('🌿', 'வீட்டுத் தோட்டம்'),
          MButton('send', 'அனுப்பு', icon: 'send', kind: MKind.success),
        ],
      ),
      say: 'படம் பெரிதாகத் தெரியும். சரியான படம் தானா என்று பாருங்கள். பிறகு பச்சை "அனுப்பு" பொத்தானை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'send',
      hint: 'பச்சை "அனுப்பு" பொத்தானை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: _wa,
        color: _waColor,
        elements: [
          MIconBar('குடும்பம் (பயிற்சி)', []),
          MBubble('🌿 படம்', fromMe: true),
          _doneButton,
        ],
      ),
      'படம் போய்விட்டது. குடும்பத்தினர் எல்லோரும் பார்ப்பார்கள். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

// ---------------------------------------------------------------- safety

final otpSafetyWalkthrough = Walkthrough(
  id: 'otp-safety',
  title: 'OTP: யாரிடமும் சொல்லக் கூடாத எண்',
  summary: 'OTP என்றால் என்ன, அதைக் கேட்டு அழைப்பவரை எப்படிக் கையாள்வது',
  category: WalkCategory.safety,
  steps: [
    _intro(
      'இது பயிற்சி. ஏமாற்றுபவர்கள் எப்படிப் பேசுவார்கள் என்று பார்த்து வைத்துக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: செய்திகள் (SMS)',
        color: _smsColor,
        elements: [
          MSms(
            'வங்கி',
            'உங்கள் OTP 482913. இதை யாரிடமும் பகிர வேண்டாம். வங்கி ஒருபோதும் OTP கேட்காது.',
          ),
          MButton('next', 'அடுத்து', icon: 'arrow'),
        ],
      ),
      say: 'இது OTP. பணம் அனுப்பும்போது அல்லது புதிதாக உள்நுழையும்போது வங்கி அனுப்பும் ஒரு முறை மட்டும் பயன்படும் எண். இதை நீங்களே உங்கள் போனில் போட வேண்டும். யாரிடமும் சொல்லக் கூடாது. "அடுத்து" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'next',
      hint: '"அடுத்து" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: அழைப்பு',
        color: 0xFF263238,
        elements: [
          MHeader('தெரியாத எண்', '+91 9xxxx xxxxx'),
          MNote(
            '"நான் வங்கியிலிருந்து பேசுகிறேன். உங்கள் கணக்கு இன்று மூடப்படும். இப்போது வந்த OTP-யைச் சொன்னால் சரி செய்கிறேன்."',
            warning: true,
          ),
          MButton('tell', 'OTP-யைச் சொல்', icon: 'chat', kind: MKind.plain),
          MButton('hangup', 'காலை வெட்டு', icon: 'end', kind: MKind.danger),
        ],
      ),
      say: 'ஒருவர் வங்கியிலிருந்து பேசுவதாகச் சொல்லி, கணக்கு மூடப்படும் என்று பயமுறுத்தி, OTP கேட்கிறார். என்ன செய்யலாம்? உங்களுக்குச் சரி என்று தோன்றுவதை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'hangup',
      hint: 'உண்மையான வங்கி ஒருபோதும் OTP கேட்காது. கேட்பவர் ஏமாற்றுபவர். "காலை வெட்டு" அழுத்துங்கள்.',
      hints: {
        'tell': 'சொன்னால், அவர் அந்த எண்ணை வைத்து உங்கள் கணக்கிலிருந்து பணம் எடுத்துவிடுவார். உண்மையான வங்கி ஒருபோதும் OTP கேட்காது. "காலை வெட்டு" அழுத்துங்கள்.',
      },
    ),
    _done(
      const MockView(
        app: 'பயிற்சி',
        color: 0xFF6A1B9A,
        elements: [
          MNote(
            'சந்தேகம் வந்தால்: பாஸ்புக்கில் அல்லது ATM கார்டின் பின்னால் உள்ள வங்கி எண்ணுக்கு நீங்களே அழையுங்கள். அல்லது ராகுலிடம் கேளுங்கள்.',
          ),
          _doneButton,
        ],
      ),
      'காலை வெட்டியாயிற்று. அவசரப்படுத்துவது, பயமுறுத்துவது, OTP அல்லது PIN கேட்பது: இந்த மூன்றும் ஏமாற்றுபவரின் அடையாளம். சந்தேகம் வந்தால், பாஸ்புக்கில் உள்ள வங்கி எண்ணுக்கு நீங்களே அழையுங்கள். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

// ---------------------------------------------------------------- travel

final busTicketWalkthrough = Walkthrough(
  id: 'bus-ticket',
  title: 'பஸ் டிக்கெட் புக் செய்வது',
  summary:
      'அரசுப் பேருந்து ஆப்பில் இருக்கை தேர்ந்தெடுத்து டிக்கெட் எடுக்கும் முறை',
  category: WalkCategory.travel,
  steps: [
    _intro(
      'இது பயிற்சி. இங்கே எந்த டிக்கெட்டும் புக் ஆகாது, பணமும் போகாது. "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MHeader('பயணம் தேடு'),
          MTile('from', 'எங்கிருந்து', subtitle: 'சேலம்', leading: '🚏'),
          MTile('to', 'எங்கே', subtitle: 'சென்னை', leading: '📍'),
          MTile('date', 'தேதி', subtitle: 'நாளை', leading: '📅'),
          MButton('search', 'பஸ் தேடு', icon: 'search', kind: MKind.danger),
        ],
      ),
      say: 'எங்கிருந்து, எங்கே, எந்தத் தேதி என்று மூன்றும் போட வேண்டும். பயிற்சிக்கு ஏற்கனவே போட்டிருக்கிறோம்: சேலம் முதல் சென்னை, நாளை. "பஸ் தேடு" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'search',
      hint: 'கீழே உள்ள "பஸ் தேடு" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MHeader('சேலம் → சென்னை', 'நாளை'),
          MTile(
            'bus1',
            'இரவு 10:00',
            subtitle: 'அல்ட்ரா டீலக்ஸ் · 18 இருக்கை காலி',
            trailing: '₹420',
          ),
          MTile(
            'bus2',
            'இரவு 11:30',
            subtitle: 'ஏசி ஸ்லீப்பர் · 4 இருக்கை காலி',
            trailing: '₹780',
          ),
        ],
      ),
      say: 'ஒவ்வொரு பஸ்ஸுக்கும் கிளம்பும் நேரம், பஸ் வகை, கட்டணம் தெரியும். இரவு 10 மணி பஸ்ஸை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'bus1',
      hint: '"இரவு 10:00" பஸ்ஸை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MHeader('இருக்கை தேர்ந்தெடு'),
          MGrid([
            MButton('seat1', '1 · ஜன்னல்', icon: 'seat', kind: MKind.plain),
            MButton('seat2', '2', icon: 'seat', kind: MKind.plain),
            MButton('seat5', '5 · ஜன்னல்', icon: 'seat', kind: MKind.plain),
            MButton('seat6', '6', icon: 'seat', kind: MKind.plain),
          ]),
        ],
      ),
      say: 'காலியான இருக்கைகள் தெரியும். ஜன்னல் இருக்கை 5-ஐ அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'seat5',
      hint: '"5 · ஜன்னல்" இருக்கையை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MHeader('பயணிப்பவர் பெயர்'),
          MTextInput(hint: 'பெயர்', button: 'அடுத்து'),
        ],
      ),
      say: 'பயணம் செய்பவர் பெயரைப் போடுங்கள். உங்கள் பெயரே போடலாம். பிறகு "அடுத்து" அழுத்துங்கள்.',
      expects: Expect.text,
      hint: 'பெயரைப் போட்டு "அடுத்து" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MHeader('சரிபார்க்கவும்'),
          MNote('{text} · இருக்கை 5 · இரவு 10:00 · சேலம் → சென்னை'),
          MBig('₹ {amount}', 'கட்டணம்'),
          MButton('pay', 'பணம் கட்டு', icon: 'send', kind: MKind.danger),
        ],
      ),
      say: 'பெயர், இருக்கை, நேரம், கட்டணம் {amount} ரூபாய் சரியா என்று பாருங்கள். "பணம் கட்டு" அழுத்தினால், நாம் கற்ற UPI PIN பக்கம் வரும்.',
      expects: Expect.tap,
      target: 'pay',
      setAmount: 420,
      hint: '"பணம் கட்டு" பொத்தானை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: _pinView,
      say: 'UPI PIN போடுங்கள். பயிற்சிக்கு எந்த நான்கு எண்ணும் போடலாம்.',
      expects: Expect.pin,
      effect: StepEffect.debitAmount,
      hint: 'நான்கு எண்கள் போட்டு, சரி குறியை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: 'பயிற்சி: பஸ் டிக்கெட்',
        color: _busColor,
        elements: [
          MTick(),
          MBig('டிக்கெட் உறுதி', 'PNR: T12345678'),
          MNote('இருக்கை 5 · நாளை இரவு 10:00'),
          _doneButton,
        ],
      ),
      'டிக்கெட் உறுதியாகிவிட்டது. டிக்கெட் விவரம் SMS-ஆகவும் வரும். பஸ்ஸில் நடத்துனரிடம் அந்த SMS-ஐக் காட்டினால் போதும். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

// ---------------------------------------------------------------- food

final foodOrderWalkthrough = Walkthrough(
  id: 'food-order',
  title: 'உணவு ஆர்டர் செய்வது',
  summary: 'ஹோட்டலில் இருந்து வீட்டுக்கு உணவு வரவழைக்கும் முறை',
  category: WalkCategory.food,
  steps: [
    _intro(
      'இது பயிற்சி. இங்கே எந்த உணவும் ஆர்டர் ஆகாது. "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: உணவு ஆப்',
        color: _foodColor,
        elements: [
          MHeader('என்ன சாப்பிடலாம்?'),
          MTextInput(hint: 'உணவின் பெயர் (உதா: தோசை)'),
        ],
      ),
      say: 'என்ன சாப்பிட வேண்டும் என்று தேடலாம். "தோசை" என்று போட்டு "தேடு" அழுத்துங்கள்.',
      expects: Expect.text,
      hint: 'உணவின் பெயரைப் போட்டு "தேடு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: உணவு ஆப்',
        color: _foodColor,
        elements: [
          MHeader('"{text}" கிடைக்கும் ஹோட்டல்கள்'),
          MTile(
            'hotel1',
            'ஸ்ரீ அன்னபூர்ணா',
            subtitle: '4.3 ★ · 30 நிமிடத்தில் வரும் · 2 கி.மீ',
            leading: 'அ',
          ),
          MTile(
            'hotel2',
            'சரவண பவன் உணவகம்',
            subtitle: '4.1 ★ · 45 நிமிடத்தில் வரும் · 5 கி.மீ',
            leading: 'ச',
          ),
        ],
      ),
      say: 'ஒவ்வொரு ஹோட்டலுக்கும் மதிப்பீடு, எவ்வளவு நேரத்தில் வரும், எவ்வளவு தூரம் என்று தெரியும். நட்சத்திரம் அதிகம் என்றால் மற்றவர்களுக்குப் பிடித்தது. "ஸ்ரீ அன்னபூர்ணா" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'hotel1',
      hint: '"ஸ்ரீ அன்னபூர்ணா" என்ற பெயரை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: உணவு ஆப்',
        color: _foodColor,
        elements: [
          MHeader('ஸ்ரீ அன்னபூர்ணா', 'மெனு'),
          MTile(
            'add_dosa',
            'நெய் ரோஸ்ட்',
            subtitle: 'சேர்க்க அழுத்துங்கள்',
            trailing: '₹90',
          ),
          MTile(
            'add_idli',
            'இட்லி (2)',
            subtitle: 'சேர்க்க அழுத்துங்கள்',
            trailing: '₹40',
          ),
          MTile(
            'add_pongal',
            'வெண் பொங்கல்',
            subtitle: 'சேர்க்க அழுத்துங்கள்',
            trailing: '₹70',
          ),
        ],
      ),
      say: 'மெனுவில் ஒவ்வொரு உணவும் அதன் விலையும் இருக்கும். "நெய் ரோஸ்ட்" அழுத்திச் சேர்த்துக்கொள்ளுங்கள்.',
      expects: Expect.tap,
      target: 'add_dosa',
      hint: '"நெய் ரோஸ்ட்" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: உணவு ஆப்',
        color: _foodColor,
        elements: [
          MHeader('பில்'),
          MNote('நெய் ரோஸ்ட் ₹90 · டெலிவரி ₹30'),
          MBig('₹ 120', 'மொத்தம்'),
          MButton(
            'cod',
            'வீட்டில் பணம் கொடு (Cash)',
            icon: 'cash',
            kind: MKind.success,
          ),
          MButton('upi', 'UPI-யில் கட்டு', icon: 'send', kind: MKind.plain),
        ],
      ),
      say: 'உணவு 90, டெலிவரி 30, மொத்தம் 120 ரூபாய். முதலில் "வீட்டில் பணம் கொடு" தேர்ந்தெடுப்பது எளிது. உணவு வந்ததும் கையில் பணம் கொடுக்கலாம். அதை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'cod',
      hint: '"வீட்டில் பணம் கொடு" பொத்தானை அழுத்துங்கள்.',
      hints: {
        'upi': 'UPI-யிலும் கட்டலாம். இன்று எளிதான வழியைப் பார்ப்போம்: "வீட்டில் பணம் கொடு" அழுத்துங்கள்.',
      },
    ),
    _done(
      const MockView(
        app: 'பயிற்சி: உணவு ஆப்',
        color: _foodColor,
        elements: [
          MTick(),
          MBig('ஆர்டர் போய்விட்டது', 'சுமார் 30 நிமிடத்தில் வரும்'),
          _doneButton,
        ],
      ),
      'ஆர்டர் போய்விட்டது. கொண்டு வருபவர் வரும்போது போனில் அழைப்பார். வாசலில் 120 ரூபாய் கொடுங்கள். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

// ---------------------------------------------------------------- maps

final mapsWalkthrough = Walkthrough(
  id: 'maps-directions',
  title: 'ஒரு இடத்துக்கு வழி கண்டுபிடிப்பது',
  summary: 'போனில் இடத்தைத் தேடி, குரல் வழிகாட்டலுடன் போகும் முறை',
  category: WalkCategory.maps,
  steps: [
    _intro(
      'இது பயிற்சி. இடத்தைத் தேடி வழி கண்டுபிடிக்கக் கற்றுக்கொள்வோம். "தொடங்கு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [
          MHeader('எங்கே போக வேண்டும்?'),
          MTextInput(hint: 'இடத்தின் பெயர் (உதா: கோயில்)'),
        ],
      ),
      say: 'போக வேண்டிய இடத்தின் பெயரைப் போடுங்கள். உதாரணமாக "கோயில்" அல்லது "அரசு மருத்துவமனை". பிறகு "தேடு" அழுத்துங்கள்.',
      expects: Expect.text,
      hint: 'இடத்தின் பெயரைப் போட்டு "தேடு" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [
          MHeader('தேடல் முடிவு'),
          MTile(
            'place',
            '{text}',
            subtitle: '2.4 கி.மீ · இப்போது திறந்திருக்கிறது',
            leading: '📍',
          ),
        ],
      ),
      say:
          'தேடிய இடம் வரும், எவ்வளவு தூரம் என்றும் தெரியும். அதை அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'place',
      hint: 'வந்திருக்கும் இடத்தின் பெயரை அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [
          MHeader('{text}', '2.4 கி.மீ'),
          MButton('directions', 'வழி', icon: 'directions'),
          MButton('share', 'இடத்தைப் பகிர்', icon: 'share', kind: MKind.plain),
        ],
      ),
      say: 'இரண்டு பொத்தான்கள்: "வழி" அழுத்தினால் எப்படிப் போவது என்று காட்டும். "பகிர்" அழுத்தினால் இந்த இடத்தை WhatsApp-இல் ஒருவருக்கு அனுப்பலாம். இப்போது "வழி" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'directions',
      hint: '"வழி" பொத்தானை அழுத்துங்கள்.',
      hints: {
        'share':
            'பகிர்வது பிறகு பார்க்கலாம். இப்போது "வழி" பொத்தானை அழுத்துங்கள்.',
      },
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [
          MHeader('எப்படிப் போகிறீர்கள்?'),
          MGrid([
            MButton(
              'walk',
              'நடந்து · 30 நிமிடம்',
              icon: 'walk',
              kind: MKind.plain,
            ),
            MButton(
              'bike',
              'வண்டியில் · 8 நிமிடம்',
              icon: 'bike',
              kind: MKind.plain,
            ),
          ]),
        ],
      ),
      say: 'நடந்தா, வண்டியிலா என்று தேர்ந்தெடுங்கள். ஒவ்வொன்றுக்கும் எவ்வளவு நேரம் ஆகும் என்று காட்டும். "வண்டியில்" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'bike',
      hint: '"வண்டியில்" அழுத்துங்கள்.',
    ),
    const WalkStep(
      view: MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [
          MNote('200 மீட்டரில் வலது பக்கம் திரும்பவும்'),
          MButton('start', 'தொடங்கு', icon: 'play', kind: MKind.success),
        ],
      ),
      say: '"தொடங்கு" அழுத்தினால், போன் ஒவ்வொரு திருப்பத்திலும் குரலில் சொல்லும்: வலது, இடது என்று. வண்டி ஓட்டும்போது போனைப் பார்க்க வேண்டாம், கேட்டால் போதும். "தொடங்கு" அழுத்துங்கள்.',
      expects: Expect.tap,
      target: 'start',
      hint: 'பச்சை "தொடங்கு" பொத்தானை அழுத்துங்கள்.',
    ),
    _done(
      const MockView(
        app: 'பயிற்சி: மேப்',
        color: _mapColor,
        elements: [MTick(), MBig('வந்துவிட்டீர்கள்', '{text}'), _doneButton],
      ),
      'இடம் வந்ததும் "நீங்கள் வந்துவிட்டீர்கள்" என்று சொல்லும். முடிக்க "முடிந்தது" அழுத்துங்கள்.',
    ),
  ],
);

/// Shown in this order. Reorder to Appa's ranking.
final walkthroughLibrary = <Walkthrough>[
  waVoiceNoteWalkthrough,
  waVideoCallWalkthrough,
  waPhotoWalkthrough,
  sendMoneyWalkthrough,
  checkBalanceWalkthrough,
  scanQrWalkthrough,
  otpSafetyWalkthrough,
  busTicketWalkthrough,
  foodOrderWalkthrough,
  mapsWalkthrough,
];
