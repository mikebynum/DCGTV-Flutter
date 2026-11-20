import 'package:flutter/material.dart';

class FavoriteSportsPicker extends StatefulWidget {
  const FavoriteSportsPicker({
    super.key,
    required this.sports,
    required this.selected,
  });

  final List<String> sports;
  final Set<String> selected;

  @override
  State<FavoriteSportsPicker> createState() => _FavoriteSportsPickerState();
}

class _FavoriteSportsPickerState extends State<FavoriteSportsPicker> {
  late final _selected = widget.selected.toSet();

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Favorite Sports',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Choose the sports you want to see on Home. Leave all unchecked to see every sport.',
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final sport in widget.sports)
                      CheckboxListTile(
                        title: Text(sport),
                        value: _selected.contains(sport),
                        onChanged: (enabled) => setState(() {
                          if (enabled == true) {
                            _selected.add(sport);
                          } else {
                            _selected.remove(sport);
                          }
                        }),
                      ),
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Clear favorites'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
