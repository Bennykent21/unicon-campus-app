import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/home_provider.dart';

void showFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FilterSheet(ref: ref),
  );
}

class _FilterSheet extends StatefulWidget {
  final WidgetRef ref;
  const _FilterSheet({required this.ref});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Start with whatever is already active
    _selected = Set.from(widget.ref.read(feedFiltersProvider));
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  void _apply() {
    widget.ref.read(feedFiltersProvider.notifier).state = Set.from(_selected);
    Navigator.pop(context);
  }

  void _clear() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.93,
      builder: (context, scrollCtrl) => Column(
        children: [
          // Handle + header (fixed, not scrollable)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: theme.dividerTheme.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Text('Filter Posts',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: _clear,
                    child: Text('Clear all (${_selected.length})',
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('Select one or more to combine filters',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              const SizedBox(height: 8),
            ]),
          ),
          const Divider(height: 1),

          // Scrollable sections
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                _Section(
                    'Post Type',
                    const [
                      'Question',
                      'Marketplace',
                      'Job',
                      'Event',
                      'General'
                    ],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Level',
                    const [
                      '100L',
                      '200L',
                      '300L',
                      '400L',
                      '500L',
                      '600L',
                      '700L'
                    ],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Engineering & Technology',
                    const [
                      'CPE',
                      'CSE',
                      'EEE',
                      'MEE',
                      'CHE',
                      'CVE',
                      'MCE',
                      'GEO'
                    ],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Sciences',
                    const [
                      'MTH',
                      'PHY',
                      'CHM',
                      'BIO',
                      'MCB',
                      'BCH',
                      'ZOO',
                      'BOT',
                      'STA'
                    ],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Medicine & Health',
                    const ['MED', 'NUR', 'PHA', 'DEN', 'VET', 'MLS'],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Social Sciences & Management',
                    const [
                      'ACC',
                      'ECO',
                      'BUS',
                      'MKT',
                      'FIN',
                      'SOC',
                      'POL',
                      'PSY',
                      'LAW'
                    ],
                    _selected,
                    _toggle),
                const SizedBox(height: 20),
                _Section(
                    'Arts & Humanities',
                    const ['ENG', 'YOR', 'IGB', 'HAU', 'HIS', 'CRS', 'LIB'],
                    _selected,
                    _toggle),
              ],
            ),
          ),

          // Apply button (fixed at bottom)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _apply,
                  child: Text(
                    _selected.isEmpty
                        ? 'Show All Posts'
                        : 'Apply  (${_selected.length} filter${_selected.length > 1 ? "s" : ""})',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _Section(this.title, this.items, this.selected, this.onToggle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.primary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = selected.contains(item);
            return GestureDetector(
              onTap: () => onToggle(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerTheme.color ?? Colors.grey,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
