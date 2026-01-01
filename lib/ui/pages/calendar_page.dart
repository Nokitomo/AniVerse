import 'package:flutter/material.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_card.dart';

class _CalendarEntry {
  final AnimeClass anime;
  final String day;

  _CalendarEntry({
    required this.anime,
    required this.day,
  });
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final List<_CalendarEntry> _entries = [];
  bool _loading = true;
  bool _error = false;

  static const List<String> _dayOrder = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
    'Indeterminato',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final raw = await fetchCalendarioItems();
      final entries = <_CalendarEntry>[];
      for (final item in raw) {
        final day = (item['day'] ?? '').toString().trim();
        entries.add(
          _CalendarEntry(
            anime: calendarToObj(item),
            day: day.isEmpty ? 'Indeterminato' : day,
          ),
        );
      }
      setState(() {
        _entries
          ..clear()
          ..addAll(entries);
        _loading = false;
        _error = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  List<MapEntry<String, List<_CalendarEntry>>> _groupByDay() {
    final grouped = <String, List<_CalendarEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.day, () => []).add(entry);
    }
    final result = <MapEntry<String, List<_CalendarEntry>>>[];
    for (final day in _dayOrder) {
      final items = grouped[day];
      if (items != null && items.isNotEmpty) {
        result.add(MapEntry(day, items));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay();
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: RefreshIndicator(
          onRefresh: _fetch,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            "Qualcosa e andato storto :(",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 23,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _fetch,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Riprova"),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.key,
                              style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final rawCount =
                                    (constraints.maxWidth / 180).floor();
                                final crossAxisCount = rawCount < 2
                                    ? 2
                                    : (rawCount > 4 ? 4 : rawCount);
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 0.7,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                                  itemCount: group.value.length,
                                  itemBuilder: (context, itemIndex) {
                                    return AnimeCard(
                                      anime: group.value[itemIndex].anime,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
