import 'dart:async';

import 'package:flutter/material.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_card.dart';
import '../widgets/archive_list_item.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  final List<AnimeClass> _items = [];
  final List<Map<String, dynamic>> _genres = [];
  final List<Map<String, dynamic>> _selectedGenres = [];
  final List<int> _yearOptions = [];
  int _oldestYear = 1966;
  int _totalCount = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _requesting = false;
  bool _hasMore = true;
  bool _error = false;
  bool _gridView = false;
  bool _dubbed = false;
  bool _showScrollToTop = false;

  int? _year;
  String? _order;
  String? _status;
  String? _type;
  String? _season;
  int _offset = 0;

  final List<String> _orderOptions = const [
    'Lista A-Z',
    'Lista Z-A',
    'Popolarità',
    'Valutazione',
  ];
  final List<String> _statusOptions = const [
    'In Corso',
    'Terminato',
    'In Uscita',
    'Droppato',
  ];
  final List<String> _typeOptions = const [
    'TV',
    'TV Short',
    'OVA',
    'ONA',
    'Special',
    'Movie',
  ];
  final List<String> _seasonOptions = const [
    'Inverno',
    'Primavera',
    'Estate',
    'Autunno',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMetaAndInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) {
      return;
    }
    final shouldShow = _scrollController.hasClients &&
        _scrollController.position.pixels > 450;
    if (shouldShow != _showScrollToTop) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
    if (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        500) {
      _fetch();
    }
  }

  Future<void> _loadMetaAndInitial() async {
    try {
      final meta = await fetchArchivioMeta();
      _genres
        ..clear()
        ..addAll((meta['genres'] as List).cast<Map<String, dynamic>>());
      _oldestYear = meta['oldestYear'] as int;
      _totalCount = meta['total'] as int;
      _buildYearOptions();
    } catch (_) {
      // ignore meta error to allow search-only experience
    }
    await _fetch(reset: true);
  }

  void _buildYearOptions() {
    _yearOptions.clear();
    final current = DateTime.now().year + 1;
    for (var year = current; year >= _oldestYear; year--) {
      _yearOptions.add(year);
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_requesting || (!reset && !_hasMore)) {
      return;
    }
    _requesting = true;

    if (reset) {
      _offset = 0;
      _items.clear();
      _hasMore = true;
      _error = false;
      setState(() {
        _loading = true;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final response = await fetchArchivioAnimes(
        title: _searchController.text,
        type: _type,
        year: _year,
        order: _order ?? 'Lista A-Z',
        status: _status,
        genres: _selectedGenres.isEmpty ? null : _selectedGenres,
        offset: _offset,
        dubbed: _dubbed,
        season: _season,
      );

      final records = (response['records'] as List).cast<dynamic>();
      final total = response['total'] as int;

      final items = records.map(searchToObj).toList();
      setState(() {
        _totalCount = total;
        _items.addAll(items);
        _offset += items.length;
        _hasMore = items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
        _requesting = false;
        _error = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _requesting = false;
        _error = true;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _fetch(reset: true);
    });
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _selectedGenres.clear();
      _year = null;
      _order = null;
      _status = null;
      _type = null;
      _season = null;
      _dubbed = false;
    });
    _fetch(reset: true);
  }

  String _genreLabel() {
    if (_selectedGenres.isEmpty) {
      return 'Any';
    }
    final first = _selectedGenres.first['name']?.toString() ?? '';
    if (_selectedGenres.length == 1) {
      return first;
    }
    return '$first +${_selectedGenres.length - 1}';
  }

  Future<void> _showGenresPicker() async {
    final selected = List<Map<String, dynamic>>.from(_selectedGenres);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Genere',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              selected.clear();
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _genres.length,
                      itemBuilder: (context, index) {
                        final genre = _genres[index];
                        final name = genre['name']?.toString() ?? '';
                        final isSelected = selected.any(
                          (item) => item['id'] == genre['id'],
                        );
                        return CheckboxListTile(
                          title: Text(name),
                          value: isSelected,
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                selected.add(genre);
                              } else {
                                selected.removeWhere(
                                  (item) => item['id'] == genre['id'],
                                );
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedGenres
                              ..clear()
                              ..addAll(selected);
                          });
                          Navigator.of(context).pop();
                          _fetch(reset: true);
                        },
                        child: const Text('Applica'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSinglePicker<T>({
    required String title,
    required List<T> options,
    required T? current,
    required ValueChanged<T?> onSelected,
    String Function(T value)? label,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onSelected(null);
                        Navigator.of(context).pop();
                        _fetch(reset: true);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: const Text('Any'),
                        trailing: current == null
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              )
                            : null,
                        onTap: () {
                          onSelected(null);
                          Navigator.of(context).pop();
                          _fetch(reset: true);
                        },
                      );
                    }
                    final option = options[index - 1];
                    final optionLabel =
                        label != null ? label(option) : option.toString();
                    return ListTile(
                      title: Text(optionLabel),
                      trailing: current == option
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        onSelected(option);
                        Navigator.of(context).pop();
                        _fetch(reset: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const spacing = 12.0;
    const fieldWidth = 140.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Genere',
              value: _genreLabel(),
              onTap: _showGenresPicker,
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Anno',
              value: _year?.toString() ?? 'Any',
              onTap: () {
                _showSinglePicker<int>(
                  title: 'Anno',
                  options: _yearOptions,
                  current: _year,
                  onSelected: (value) {
                    setState(() {
                      _year = value;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Ordina',
              value: _order ?? 'Any',
              onTap: () {
                _showSinglePicker<String>(
                  title: 'Ordina',
                  options: _orderOptions,
                  current: _order,
                  onSelected: (value) {
                    setState(() {
                      _order = value;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Stato',
              value: _status ?? 'Any',
              onTap: () {
                _showSinglePicker<String>(
                  title: 'Stato',
                  options: _statusOptions,
                  current: _status,
                  onSelected: (value) {
                    setState(() {
                      _status = value;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Tipo',
              value: _type ?? 'Any',
              onTap: () {
                _showSinglePicker<String>(
                  title: 'Tipo',
                  options: _typeOptions,
                  current: _type,
                  onSelected: (value) {
                    setState(() {
                      _type = value;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: spacing),
          SizedBox(
            width: fieldWidth,
            child: _buildFilterField(
              label: 'Stagione',
              value: _season ?? 'Any',
              onTap: () {
                _showSinglePicker<String>(
                  title: 'Stagione',
                  options: _seasonOptions,
                  current: _season,
                  onSelected: (value) {
                    setState(() {
                      _season = value;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _items.isEmpty) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error && _items.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Errore nel caricamento',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _fetch(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'Nessun risultato',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    if (_gridView) {
      return Expanded(
        child: GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
          ),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return AnimeCard(
              anime: _items[index],
            );
          },
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return ArchiveListItem(anime: _items[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Archivio'),
      ),
      floatingActionButton: IgnorePointer(
        ignoring: !_showScrollToTop,
        child: AnimatedOpacity(
          opacity: _showScrollToTop ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
              );
            },
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cerca',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Dub ITA',
                    style: TextStyle(
                      color: theme.onBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch.adaptive(
                    value: _dubbed,
                    onChanged: (value) {
                      setState(() {
                        _dubbed = value;
                      });
                      _fetch(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_totalCount risultati',
                    style: TextStyle(
                      color: theme.onBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Reset'),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _gridView = true;
                      });
                    },
                    icon: Icon(
                      Icons.grid_view,
                      color: _gridView
                          ? theme.primary
                          : theme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _gridView = false;
                      });
                    },
                    icon: Icon(
                      Icons.view_agenda_outlined,
                      color: !_gridView
                          ? theme.primary
                          : theme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildResults(),
            ],
          ),
        ),
      ),
    );
  }
}
