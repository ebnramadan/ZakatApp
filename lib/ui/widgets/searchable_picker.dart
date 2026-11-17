import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';

class PickerOption<T> {
  final T value;
  final String label;
  final String? detail;
  const PickerOption(this.value, this.label, {this.detail});
}

class SearchablePicker<T> extends FormField<T> {
  SearchablePicker(
      {super.key,
      required String label,
      required List<PickerOption<T>> options,
      T? value,
      required ValueChanged<T>? onChanged,
      super.validator,
      String? helperText})
      : super(
            initialValue: value,
            builder: (state) {
              final matches = options.where((o) => o.value == value);
              final selected = matches.isEmpty ? null : matches.first;
              return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onChanged == null
                      ? null
                      : () async {
                          final result = await showDialog<T>(
                              context: state.context,
                              builder: (_) => _PickerDialog<T>(
                                  label: label,
                                  options: options,
                                  selected: value));
                          if (result != null && state.mounted) {
                            state.didChange(result);
                            onChanged(result);
                          }
                        },
                  child: InputDecorator(
                      decoration: InputDecoration(
                          labelText: l(state.context, label),
                          helperText: helperText == null
                              ? null
                              : l(state.context, helperText),
                          errorText: state.errorText,
                          enabled: onChanged != null,
                          suffixIcon: const Icon(Icons.unfold_more)),
                      child: Semantics(
                          button: true,
                          label: l(state.context, label),
                          child: Text(
                              l(state.context,
                                  selected?.label ?? 'Choose an option'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis))));
            });
  @override
  FormFieldState<T> createState() => _SearchablePickerState<T>();
}

class _SearchablePickerState<T> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant FormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}

class _PickerDialog<T> extends StatefulWidget {
  final String label;
  final List<PickerOption<T>> options;
  final T? selected;
  const _PickerDialog(
      {required this.label, required this.options, this.selected});
  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    String normalized(String text) =>
        text.toLowerCase().replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
          final n = m[0]!.codeUnitAt(0);
          return (n > 0x6ef ? n - 0x6f0 : n - 0x660).toString();
        });
    final filtered = widget.options
        .where((o) => normalized(
                '${o.label} ${l(context, o.label)} ${o.detail ?? ''} ${l(context, o.detail ?? '')}')
            .contains(normalized(query)))
        .toList();
    return AlertDialog(
        title: Text(l(context, widget.label)),
        content: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(context).height * .5,
            child: Column(children: [
              TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: l(context, "Search options"),
                      prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) => setState(() => query = v)),
              const SizedBox(height: 12),
              Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text(l(context, "No matching options")))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final o = filtered[i];
                            return ListTile(
                                title: Text(l(context, o.label)),
                                subtitle: o.detail == null
                                    ? null
                                    : Text(l(context, o.detail!)),
                                trailing: o.value == widget.selected
                                    ? const Icon(Icons.check,
                                        color: kPrimaryGreen)
                                    : null,
                                onTap: () => Navigator.pop(context, o.value));
                          }))
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l(context, "Cancel")))
        ]);
  }
}

List<PickerOption<String>> get currencyOptions => kCurrencies.entries
    .map((e) => PickerOption(e.key, e.key, detail: e.value))
    .toList();
