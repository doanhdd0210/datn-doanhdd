/// The kind of food a place serves, guessed from its OSM tags — see
/// `CuisineClassifier` in the data layer for how a place gets tagged.
enum DishCategory {
  com('Cơm', '🍚'),
  phoBun('Phở / Bún', '🍜'),
  lauNuong('Lẩu / Nướng', '🍲'),
  gaVit('Gà / Vịt', '🍗'),
  haiSan('Hải sản', '🦐'),
  japanKorea('Nhật / Hàn', '🍱'),
  fastFood('Burger / Pizza', '🍔'),
  chay('Chay', '🥗'),
  cafe('Cà phê / Nhẹ', '☕'),
  khac('Khác', '🍽️');

  const DishCategory(this.label, this.emoji);

  final String label;
  final String emoji;
}
