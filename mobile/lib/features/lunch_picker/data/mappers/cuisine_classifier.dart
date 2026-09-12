import '../../domain/entities/dish_category.dart';

/// Guesses [DishCategory]s from OSM's free-text `cuisine` tag plus the
/// place's name — OSM restaurant data in Vietnam is rarely tagged with a
/// clean cuisine, so the name carries most of the signal.
///
/// Deliberately *not* implemented with `\b`-based regexes: Dart/JS regex
/// word boundaries only understand ASCII `[A-Za-z0-9_]` as "word
/// characters", so `\b` silently misfires around Vietnamese diacritics
/// (e.g. it would treat "quốc" as containing the standalone word "ốc").
/// Splitting on non-letter runs and checking whole tokens sidesteps that.
class CuisineClassifier {
  const CuisineClassifier();

  /// Safe to match anywhere in the text — long/specific enough that they
  /// don't collide with unrelated Vietnamese words.
  static const _substringRules = <DishCategory, List<String>>{
    DishCategory.com: ['cơm', 'rice', 'bình dân', 'tấm', 'niêu'],
    DishCategory.phoBun: [
      'phở',
      'bún',
      'miến',
      'noodle',
      'mì vằn thắn',
      'hủ tiếu',
    ],
    DishCategory.lauNuong: [
      'lẩu',
      'nướng',
      'bbq',
      'grill',
      'hotpot',
      'hot pot',
      'nhậu',
    ],
    DishCategory.chay: ['chay', 'vegetarian', 'vegan'],
    DishCategory.japanKorea: [
      'japan',
      'sushi',
      'ramen',
      'korea',
      'hàn quốc',
      'udon',
      'nhật bản',
    ],
    DishCategory.fastFood: [
      'burger',
      'pizza',
      'kfc',
      'mcdonald',
      'jollibee',
      'popeyes',
      'fried chicken',
      'sandwich',
      'bánh mì',
    ],
    DishCategory.cafe: [
      'coffee',
      'cafe',
      'cà phê',
      'trà sữa',
      'milk tea',
      'bakery',
      'bánh',
      'dessert',
      'chè',
    ],
    DishCategory.haiSan: ['hải sản', 'seafood'],
  };

  /// Short enough to be a false-positive risk as a substring (e.g. plain
  /// "cá" inside "các") — only counted when they show up as a whole token.
  static const _wholeWordRules = <DishCategory, List<String>>{
    DishCategory.gaVit: ['gà', 'vịt', 'chicken', 'rán'],
    DishCategory.haiSan: ['ốc', 'cua', 'tôm', 'cá'],
  };

  static final _tokenSplitter = RegExp(r'[^\p{L}0-9]+', unicode: true);

  Set<DishCategory> classify({
    required String name,
    required String cuisine,
    required String amenity,
  }) {
    final haystack = '$name $cuisine'.replaceAll('_', ' ').toLowerCase();
    final tokens = haystack.split(_tokenSplitter).toSet();

    final hits = <DishCategory>{
      for (final entry in _substringRules.entries)
        if (entry.value.any(haystack.contains)) entry.key,
      for (final entry in _wholeWordRules.entries)
        if (entry.value.any(tokens.contains)) entry.key,
    };

    if (hits.isNotEmpty) return hits;
    if (amenity == 'cafe') return {DishCategory.cafe};
    if (amenity == 'fast_food') return {DishCategory.fastFood};
    return {DishCategory.khac};
  }
}
