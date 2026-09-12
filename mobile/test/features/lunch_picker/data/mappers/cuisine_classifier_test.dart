import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lunch_picker/data/mappers/cuisine_classifier.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';

void main() {
  const classifier = CuisineClassifier();

  test('matches "cơm" in the name', () {
    final result = classifier.classify(
      name: 'Cơm Tấm Tường Hân',
      cuisine: '',
      amenity: 'restaurant',
    );
    expect(result, contains(DishCategory.com));
  });

  test('can match more than one category', () {
    final result = classifier.classify(
      name: 'Bún Ốc Chuối Đậu',
      cuisine: '',
      amenity: 'restaurant',
    );
    expect(result, {DishCategory.phoBun, DishCategory.haiSan});
  });

  test('underscores in the cuisine tag are treated as spaces', () {
    final result = classifier.classify(
      name: 'Nhà hàng Bò Đội Nón',
      cuisine: 'Lẩu_-_nướng_&_các_món_nhậu',
      amenity: 'restaurant',
    );
    expect(result, contains(DishCategory.lauNuong));
  });

  test('a plain coffee shop falls back to the amenity tag', () {
    final result = classifier.classify(
      name: 'Highlands Coffee',
      cuisine: 'coffee_shop',
      amenity: 'cafe',
    );
    expect(result, {DishCategory.cafe});
  });

  test('an unrecognised place with no useful amenity is "khác"', () {
    final result = classifier.classify(
      name: 'Nhà Hàng Gecko',
      cuisine: '',
      amenity: 'restaurant',
    );
    expect(result, {DishCategory.khac});
  });

  test('"quốc" does not falsely match the "ốc" seafood rule', () {
    final result = classifier.classify(
      name: 'Nhà ăn sinh viên quốc tế',
      cuisine: '',
      amenity: 'restaurant',
    );
    expect(result, isNot(contains(DishCategory.haiSan)));
  });
}
