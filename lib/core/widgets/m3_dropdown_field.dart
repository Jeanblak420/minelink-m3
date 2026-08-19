import 'package:flutter/material.dart';

class M3DropdownField<T> extends FormField<T> {
  M3DropdownField({
    super.key,
    required String label,
    required List<DropdownMenuEntry<T>> entries,
    super.initialValue,
    ValueChanged<T?>? onSelected,
    super.validator,
    Widget? leadingIcon,
    String? hintText,
    bool enabled = true,
    bool enableSearch = false,
    bool enableFilter = false,
    EdgeInsetsGeometry expandedInsets = EdgeInsets.zero,
    double? width,
  }) : super(
         builder: (state) {
           return DropdownMenu<T>(
             initialSelection: state.value,
             dropdownMenuEntries: entries,
             label: Text(label),
             leadingIcon: leadingIcon,
             hintText: hintText,
             enabled: enabled,
             enableSearch: enableSearch,
             enableFilter: enableFilter,
             expandedInsets: expandedInsets,
             width: width,
             errorText: state.errorText,
             onSelected: enabled
                 ? (value) {
                     state.didChange(value);
                     onSelected?.call(value);
                   }
                 : null,
           );
         },
       );
}
