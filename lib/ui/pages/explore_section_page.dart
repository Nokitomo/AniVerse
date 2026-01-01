import 'package:flutter/material.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_card.dart';

enum ExploreSectionKind { topAnime, archivio }

class ExploreSectionArgs {
  final String title;
  final ExploreSectionKind kind;
  final AnimeClass Function(dynamic) converter;
  final String? status;
  final String? type;
  final String? order;
  final bool popular;

  const ExploreSectionArgs({
    required this.title,
    required this.kind,
    required this.converter,
    this.status,
    this.type,
    this.order,
    this.popular = false,
  });
}

class ExploreSectionPage extends StatefulWidget {
  final ExploreSectionArgs args;

  const ExploreSectionPage({
    super.key,
    required this.args,
  });

  @override
  State<ExploreSectionPage> createState() => _ExploreSectionPageState();
}

class _ExploreSectionPageState extends State<ExploreSectionPage> {
  final ScrollController _scrollController = ScrollController();

  final List<AnimeClass> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;
  int _page = 1;
  int _offset = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) {
      return;
    }
    if (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        500) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (!reset && _loadingMore) {
      return;
    }

    final requestId = ++_requestId;
    if (reset) {
      _items.clear();
      _page = 1;
      _offset = 0;
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
      if (widget.args.kind == ExploreSectionKind.topAnime) {
        final response = await fetchTopAnimePage(
          status: widget.args.status,
          type: widget.args.type,
          order: widget.args.order,
          popular: widget.args.popular,
          page: _page,
        );
        final records = (response['data'] as List).cast<dynamic>();
        final currentPage = response['current_page'] as int? ?? _page;
        final lastPage = response['last_page'] as int? ?? _page;
        final items = records.map(widget.args.converter).toList();
        if (requestId != _requestId) {
          return;
        }
        setState(() {
          _items.addAll(items);
          _page = currentPage + 1;
          _hasMore = currentPage < lastPage && items.isNotEmpty;
          _loading = false;
          _loadingMore = false;
          _error = false;
        });
      } else {
        final response = await fetchArchivioAnimes(
          type: widget.args.type,
          order: widget.args.order ?? 'Valutazione',
          offset: _offset,
        );
        final records = (response['records'] as List).cast<dynamic>();
        final items = records.map(widget.args.converter).toList();
        if (requestId != _requestId) {
          return;
        }
        setState(() {
          _items.addAll(items);
          _offset += items.length;
          _hasMore = items.isNotEmpty;
          _loading = false;
          _loadingMore = false;
          _error = false;
        });
      }
    } catch (_) {
      if (requestId != _requestId) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.args.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(reset: true),
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
                          onPressed: () => _fetch(reset: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Riprova"),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final rawCount =
                          (constraints.maxWidth / 170).floor();
                      final crossAxisCount = rawCount < 2
                          ? 2
                          : (rawCount > 6 ? 6 : rawCount);
                      return GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return AnimeCard(anime: _items[index]);
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
