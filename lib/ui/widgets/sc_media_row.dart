import 'package:flutter/material.dart';

import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:aniverse/ui/widgets/sc_media_card.dart';

class ScMediaRow extends StatefulWidget {
  final Future<List<ScMedia>> Function() loader;
  final String title;
  final String cdnUrl;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? itemLimit;
  final void Function(ScMedia media)? onItemTap;

  const ScMediaRow({
    super.key,
    required this.loader,
    required this.title,
    required this.cdnUrl,
    this.actionLabel,
    this.onAction,
    this.itemLimit,
    this.onItemTap,
  });

  @override
  State<ScMediaRow> createState() => _ScMediaRowState();
}

class _ScMediaRowState extends State<ScMediaRow> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Roboto",
                ),
              ),
            ),
            if (widget.actionLabel != null && widget.onAction != null)
              TextButton(
                onPressed: widget.onAction,
                child: Text(
                  widget.actionLabel!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: FutureBuilder<List<ScMedia>>(
            future: widget.loader(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                var data = snapshot.data ?? [];
                if (widget.itemLimit != null &&
                    data.length > widget.itemLimit!) {
                  data = data.take(widget.itemLimit!).toList();
                }
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      "Nessun contenuto disponibile",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 18,
                      ),
                    ),
                  );
                }
                return RawScrollbar(
                  thumbColor: Theme.of(context).colorScheme.secondary,
                  radius: const Radius.circular(360),
                  thickness: 3,
                  child: ListView.builder(
                    shrinkWrap: true,
                    addAutomaticKeepAlives: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      return ScMediaCard(
                        media: item,
                        cdnUrl: widget.cdnUrl,
                        onTap: widget.onItemTap != null
                            ? () => widget.onItemTap!(item)
                            : null,
                      );
                    },
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        "Qualcosa e' andato storto :(",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 23,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Riprova"),
                      ),
                    ],
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          ),
        ),
      ],
    );
  }
}
