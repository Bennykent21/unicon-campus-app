import 'package:flutter/material.dart';
import '../constants/uniben_departments.dart';

/// Department text field that suggests common departments as the student
/// types. Free text is still allowed.
class DepartmentField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const DepartmentField({
    super.key,
    required this.controller,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) => SuggestionField(
        controller: controller,
        validator: validator,
        textInputAction: textInputAction,
        suggestions: unibenDepartments,
        label: 'Department',
        hint: 'e.g. Computer Engineering',
        icon: Icons.apartment_outlined,
      );
}

/// Text field with type-ahead suggestions from a fixed list.
class SuggestionField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final List<String> suggestions;
  final String label;
  final String hint;
  final IconData icon;

  const SuggestionField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  // RawAutocomplete needs the focus node when it is given a controller.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.length < 2) return const Iterable<String>.empty();
          return widget.suggestions
              .where((d) => d.toLowerCase().contains(q))
              .take(6);
        },
        fieldViewBuilder: (context, ctrl, focusNode, onSubmit) => TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          textInputAction: widget.textInputAction,
          textCapitalization: TextCapitalization.words,
          validator: widget.validator,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, size: 20),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth, maxHeight: 260),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      title: Text(o),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
