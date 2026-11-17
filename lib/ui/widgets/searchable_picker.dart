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
                          labelText: label,
                          helperText: helperText,
                          errorText: state.errorText,
                          enabled: onChanged != null,
                          suffixIcon: const Icon(Icons.unfold_more)),
                      child: Semantics(
                          button: true,
                          label: label,
                          child: Text(selected?.label ?? 'Choose an option',
                              maxLines: 2, overflow: TextOverflow.ellipsis))));
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
    final filtered = widget.options
        .where((o) => '${o.label} ${o.detail ?? ''}'
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    return AlertDialog(
        title: Text(widget.label),
        content: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(context).height * .5,
            child: Column(children: [
              TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Search options',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => query = v)),
              const SizedBox(height: 12),
              Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matching options'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final o = filtered[i];
                            return ListTile(
                                title: Text(o.label),
                                subtitle:
                                    o.detail == null ? null : Text(o.detail!),
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
              child: const Text('Cancel'))
        ]);
  }
}

List<PickerOption<String>> get currencyOptions => kCurrencies.entries
    .map((e) => PickerOption(e.key, e.key, detail: e.value))
    .toList();
