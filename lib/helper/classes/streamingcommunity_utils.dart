import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/helper/models/media_model.dart';
import 'package:aniverse/services/internal_db.dart';
import 'package:get/get.dart';

String buildScImageUrl({
  required List<ScImage> images,
  required String cdnUrl,
  List<String>? preferredTypes,
}) {
  if (images.isEmpty) {
    return '';
  }
  final order = preferredTypes ??
      const ['poster', 'cover', 'cover_mobile', 'background', 'logo'];
  ScImage? selected;
  for (final type in order) {
    selected = images.firstWhere(
      (img) => img.type == type && img.filename.isNotEmpty,
      orElse: () => const ScImage(filename: '', type: ''),
    );
    if (selected.filename.isNotEmpty) {
      break;
    }
  }
  selected ??= images.first;
  final filename = selected.filename;
  return resolveScImageUrl(filename, cdnUrl);
}

String resolveScImageUrl(String filename, String cdnUrl) {
  if (filename.isEmpty) {
    return '';
  }
  if (filename.startsWith('http')) {
    return filename;
  }
  final base = cdnUrl.trim();
  if (base.isEmpty) {
    return filename;
  }
  return '$base/images/$filename';
}

MediaModel fetchMediaModel(ScMedia media, {String? imageUrl}) {
  final box = Get.find<ObjectBox>().store.box<MediaModel>();
  final existing = box.get(media.id);
  MediaModel model;
  if (existing != null) {
    model = existing;
  } else {
    model = MediaModel()
      ..id = media.id
      ..title = media.name
      ..imageUrl = imageUrl ?? '';
  }
  model.decodeStr();
  return model;
}
