import 'package:aniverse/helper/classes/streamingcommunity_models.dart';
import 'package:flutter/material.dart';

class ScEpisodeTile extends StatelessWidget {
  final ScEpisode episode;
  final VoidCallback onTap;

  const ScEpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        "Episodio ${episode.number}",
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        episode.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        Icons.play_arrow,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
