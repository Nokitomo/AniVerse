import 'package:aniverse/helper/classes/anime_obj.dart';
import 'package:aniverse/helper/models/anime_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeImageUrl restituisce stringa vuota con null o vuota', () {
    expect(normalizeImageUrl(null), '');
    expect(normalizeImageUrl(''), '');
  });

  test('normalizeImageUrl riscrive i link di animeworld', () {
    const input = 'https://animeworld.so/images/cover.jpg';
    const expected = 'https://img.animeunity.so/anime/cover.jpg';

    expect(normalizeImageUrl(input), expected);
  });

  test('normalizeImageUrl lascia intatti gli altri host', () {
    const input = 'https://example.com/cover.jpg';

    expect(normalizeImageUrl(input), input);
  });

  test('searchToObj applica fallback e gestisce liste mancanti', () {
    final obj = searchToObj({
      'title_it': 'Titolo IT',
      'imageurl': 'https://animeworld.so/images/cover.jpg',
      'id': 10,
      'plot': null,
      'episodes': 'not-a-list',
      'genres': null,
      'episodes_count': 24,
      'slug': 'slug-it',
    });

    expect(obj.title, 'Titolo IT');
    expect(obj.imageUrl, 'https://img.animeunity.so/anime/cover.jpg');
    expect(obj.description, '');
    expect(obj.episodes, isEmpty);
    expect(obj.genres, isEmpty);
    expect(obj.episodesCount, 24);
    expect(obj.slug, 'slug-it');
  });

  test('latestToObj legge i campi annidati', () {
    final obj = latestToObj({
      'anime': {
        'title': 'Latest',
        'imageurl': 'https://example.com/cover.jpg',
        'id': 7,
        'plot': 'desc',
        'status': 'ongoing',
        'episodes_count': 12,
        'slug': 'latest',
      }
    });

    expect(obj.title, 'Latest');
    expect(obj.imageUrl, 'https://example.com/cover.jpg');
    expect(obj.id, 7);
    expect(obj.description, 'desc');
    expect(obj.status, 'ongoing');
    expect(obj.episodesCount, 12);
    expect(obj.slug, 'latest');
  });

  test('modelToObj mappa i campi e lastSeen', () {
    final model = AnimeModel()
      ..title = 'Model'
      ..imageUrl = 'https://example.com/cover.jpg'
      ..id = 3
      ..lastSeenDate = DateTime(2024, 1, 2);

    final obj = modelToObj(model);

    expect(obj.title, 'Model');
    expect(obj.imageUrl, 'https://example.com/cover.jpg');
    expect(obj.id, 3);
    expect(obj.lastSeen, DateTime(2024, 1, 2));
  });

  test('AnimeClass.getModel popola i campi principali', () {
    final anime = AnimeClass(
      title: 'Title',
      imageUrl: 'https://example.com/cover.jpg',
      id: 5,
      description: 'desc',
      episodes: const [],
      status: 'completed',
      genres: const [],
      episodesCount: 10,
      slug: 'slug',
    );

    final model = anime.getModel();

    expect(model.title, 'Title');
    expect(model.imageUrl, 'https://example.com/cover.jpg');
    expect(model.id, 5);
    expect(model.lastSeenDate, isNotNull);
  });
}
