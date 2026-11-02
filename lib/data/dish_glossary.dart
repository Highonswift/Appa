/// Tamil glossary of common restaurant dishes (roadmap: food walkthrough
/// "includes a Tamil glossary of common restaurant dishes with photos").
/// Photos are not bundled yet: add them under `assets/dishes/ID.jpg` and set
/// [Dish.photo] once the team has free-licence or own photos.
class Dish {
  const Dish(this.id, this.name, this.tamil, this.explain, {this.photo});
  final String id;

  /// As printed on menus (usually English).
  final String name;
  final String tamil;
  final String explain;
  final String? photo;
}

const dishGlossary = <Dish>[
  Dish(
    'biryani',
    'Biryani',
    'பிரியாணி',
    'மசாலாவுடன் வேகவைத்த சாதமும் கறியும். சிக்கன், மட்டன், காய்கறி என்று பல வகை.',
  ),
  Dish(
    'fried-rice',
    'Fried Rice',
    'ஃப்ரைடு ரைஸ்',
    'சாதத்தைக் காய்கறி, முட்டையுடன் வாணலியில் வதக்கியது. காரம் குறைவு.',
  ),
  Dish(
    'noodles',
    'Noodles / Hakka Noodles',
    'நூடுல்ஸ்',
    'மெல்லிய நீண்ட மாவுச் சேமியா போன்றது, காய்கறியுடன் வதக்கியது.',
  ),
  Dish(
    'gobi-manchurian',
    'Gobi Manchurian',
    'கோபி மஞ்சூரியன்',
    'காலிஃப்ளவரை மாவில் தோய்த்துப் பொரித்து, புளிப்பு-காரச் சாஸில் போட்டது.',
  ),
  Dish(
    'paneer-butter-masala',
    'Paneer Butter Masala',
    'பனீர் பட்டர் மசாலா',
    'பனீர் என்பது பாலில் செய்த கட்டி. தக்காளி, வெண்ணெய் குழம்பில் போட்டது. இனிப்பும் காரமும் கலந்தது.',
  ),
  Dish(
    'dal-tadka',
    'Dal Tadka / Dal Fry',
    'தால் தட்கா',
    'பருப்புக் கடைசல், மேலே எண்ணெயில் தாளித்தது. நம் பருப்பு போலவே.',
  ),
  Dish(
    'naan',
    'Naan',
    'நான்',
    'மைதா மாவில் செய்து தந்தூர் அடுப்பில் சுட்ட மென்மையான ரொட்டி.',
  ),
  Dish(
    'roti',
    'Roti / Chapati / Phulka',
    'ரொட்டி / சப்பாத்தி',
    'கோதுமை மாவு ரொட்டி. சப்பாத்தி போலவே, எண்ணெய் குறைவு.',
  ),
  Dish(
    'kulcha',
    'Kulcha',
    'குல்சா',
    'நான் போன்ற ரொட்டி, உள்ளே சில நேரம் உருளைக்கிழங்கு அல்லது வெங்காயம்.',
  ),
  Dish(
    'shawarma',
    'Shawarma',
    'ஷவர்மா',
    'சுட்ட சிக்கன் துண்டுகளை மெல்லிய ரொட்டியில் சுருட்டியது.',
  ),
  Dish(
    'burger',
    'Burger',
    'பர்கர்',
    'இரண்டு வட்டமான பன்களுக்கு நடுவில் கட்லெட், காய்கறி, சாஸ் வைத்தது.',
  ),
  Dish(
    'pizza',
    'Pizza',
    'பீட்சா',
    'வட்டமான தட்டையான ரொட்டி மேல் தக்காளிச் சாஸ், சீஸ், காய்கறி போட்டுச் சுட்டது.',
  ),
  Dish(
    'sandwich',
    'Sandwich',
    'சாண்ட்விச்',
    'இரண்டு பிரெட் துண்டுகளுக்கு நடுவில் காய்கறி அல்லது முட்டை.',
  ),
  Dish(
    'momos',
    'Momos',
    'மோமோஸ்',
    'கொழுக்கட்டை போல, உள்ளே காய்கறி அல்லது சிக்கன், ஆவியில் வேகவைத்தது.',
  ),
  Dish(
    'pasta',
    'Pasta',
    'பாஸ்தா',
    'சிறிய குழாய் வடிவ மாவுப் பண்டம், தக்காளி அல்லது பால் சாஸில் வேகவைத்தது.',
  ),
  Dish(
    'chilli-chicken',
    'Chilli Chicken',
    'சில்லி சிக்கன்',
    'பொரித்த சிக்கனைக் குடைமிளகாய், வெங்காயத்துடன் காரச் சாஸில் வதக்கியது.',
  ),
  Dish(
    'chole-bhature',
    'Chole Bhature',
    'சோலே பட்டூரா',
    'பெரிய உப்பிய பூரியுடன் கொண்டைக்கடலைக் குழம்பு.',
  ),
  Dish(
    'falooda',
    'Falooda',
    'ஃபலூடா',
    'பால், சேமியா, சப்ஜா விதை, ஐஸ்கிரீம் கலந்த இனிப்பு பானம்.',
  ),
];
