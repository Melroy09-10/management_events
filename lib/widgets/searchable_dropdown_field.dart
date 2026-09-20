import 'package:flutter/material.dart';

/// A single selectable option for a [SearchableDropdownField].
///
/// Set [alwaysVisible] on entries that should stay in the list no matter
/// what the user has typed — used for a trailing "Add new…" action so it's
/// always reachable even while filtering.
class SearchableDropdownOption<T> {
  final T value;
  final String label;
  final Widget? leading;
  final bool alwaysVisible;

  const SearchableDropdownOption({
    required this.value,
    required this.label,
    this.leading,
    this.alwaysVisible = false,
  });
}

/// The app's single, consistent type-to-search dropdown, used everywhere a
/// field previously used a plain dropdown — Event Type, Event Name, Person
/// Who Called, and list filters. Built on [DropdownMenu] so it behaves and
/// looks the same on Web, Android and iOS: tapping opens the option list,
/// typing filters it case-insensitively by matching the entered letters
/// anywhere in the label.
class SearchableDropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData icon;
  final List<SearchableDropdownOption<T>> options;
  final ValueChanged<T?> onSelected;
  final String hintText;
  final bool enabled;
  final String? errorText;
  final String? helperText;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelected,
    this.hintText = 'Type to search…',
    this.enabled = true,
    this.errorText,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlwaysVisible = options.any((o) => o.alwaysVisible);

    return DropdownMenu<T>(
      initialSelection: value,
      enabled: enabled,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      label: Text(label),
      leadingIcon: Icon(icon),
      hintText: hintText,
      errorText: errorText,
      helperText: helperText,
      dropdownMenuEntries: [
        for (final option in options)
          DropdownMenuEntry<T>(
            value: option.value,
            label: option.label,
            leadingIcon: option.leading,
          ),
      ],
      // Default DropdownMenu filtering is already a case-insensitive
      // substring match; only override it when an entry (e.g. "Add new…")
      // needs to stay pinned regardless of the typed query.
      filterCallback: hasAlwaysVisible
          ? (entries, filter) {
              final query = filter.trim().toLowerCase();
              if (query.isEmpty) return entries;
              return entries.where((entry) {
                final option = options.firstWhere(
                  (o) => o.value == entry.value,
                );
                return option.alwaysVisible ||
                    entry.label.toLowerCase().contains(query);
              }).toList();
            }
          : null,
      onSelected: onSelected,
    );
  }
}
