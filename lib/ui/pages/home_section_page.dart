import 'package:flutter/material.dart';

import '../../helper/classes/anime_obj.dart';
import '../widgets/anime_card.dart';

class HomeSectionArgs {
  final String title;
  final Future<List> Function() loader;
  final AnimeClass Function(dynamic) converter;

  const HomeSectionArgs({
    required this.title,
    required this.loader,
    required this.converter,
  });
}

class HomeSectionPage extends StatefulWidget {
  final HomeSectionArgs args;

  const HomeSectionPage({
    super.key,
    required this.args,
  });

  @override
  State<HomeSectionPage> createState() => _HomeSectionPageState();
}

class _HomeSectionPageState extends State<HomeSectionPage> {
  bool _loading = true;
  bool _error = false;
  final List<AnimeClass> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await widget.args.loader();
      final items = data.map(widget.args.converter).toList();
      setState(() {
        _items
          ..clear()
          ..addAll(items);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.args.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Riprova"),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      return AnimeCard(anime: _items[index]);
                    },
                  ),
      ),
    );
  }
}
