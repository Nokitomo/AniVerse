import 'package:aniverse/helper/models/anime_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodeStr serializza episodes in JSON', () {
    final model = AnimeModel()
      ..episodes = {
        '1': 'Ep1',
        '2': {'title': 'Ep2'}
      };

    model.encodeStr();

    expect(model.episodeStr, contains('"1"'));
    expect(model.episodeStr, contains('Ep1'));
    expect(model.episodeStr, contains('Ep2'));
  });

  test('decodeStr ripristina episodes dal JSON', () {
    final model = AnimeModel()..episodeStr = '{"1":"Ep1","2":2}';

    model.decodeStr();

    expect(model.episodes['1'], 'Ep1');
    expect(model.episodes['2'], 2);
  });
}
