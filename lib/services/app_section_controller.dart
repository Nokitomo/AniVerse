import 'package:get/get.dart';

enum AppSection {
  anime,
  media,
}

class AppSectionController extends GetxController {
  final Rx<AppSection> section = AppSection.anime.obs;
  final RxInt index = 0.obs;

  void switchTo(AppSection value) {
    if (section.value == value) {
      return;
    }
    section.value = value;
    index.value = 0;
  }

  void setIndex(int value) {
    index.value = value;
  }
}
