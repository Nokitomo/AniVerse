import 'package:flutter/material.dart';

import '../../helper/api.dart';
import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_card.dart';

class LatestSectionPage extends StatefulWidget {
  final String title;

  const LatestSectionPage({
    super.key,
    required this.title,
  });

  @override
  State<LatestSectionPage> createState() => _LatestSectionPageState();
}

class _LatestSectionPageState extends State<LatestSectionPage> {
  final ScrollController _scrollController = ScrollController();
  final List<AnimeClass> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;
  int _page = 1;
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
      final records = await fetchLatestAnimePage(page: _page);
      final items = records.map(latestToObj).toList();
      if (requestId != _requestId) {
        return;
      }
      setState(() {
        _items.addAll(items);
        _page += 1;
        _hasMore = items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
        _error = false;
      });
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
        title: Text(widget.title),
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
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
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
                  ),
      ),
    );
  }
}
