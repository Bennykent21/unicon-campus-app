import 'package:flutter/material.dart';
import '../constants/uniben_departments.dart';

/// Department text field that suggests UNIBEN departments as the student
/// types. Free text is still allowed.
class DepartmentField extends StatefulWidget {
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
  State<DepartmentField> createState() => _DepartmentFieldState();
}

class _DepartmentFieldState extends State<DepartmentField> {
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
          return unibenDepartments
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
          decoration: const InputDecoration(
            labelText: 'Department',
            hintText: 'e.g. Computer Engineering',
            prefixIcon: Icon(Icons.apartment_outlined, size: 20),
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
