import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_control_room_palette.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/screens/employee_register_screen.dart';

/// The console's palette for the Employee Register.
///
/// The super-admin chrome is permanently dark navy — it does not follow the
/// user's light/dark toggle, so neither can a screen pushed from it. The screen
/// itself no longer hardcodes any of this (P7-28 / P5-15): it renders whatever
/// palette it is handed, and the console is the one place that hands it a fixed
/// one.
///
/// S5-19: this was a hand-written `MlSemantic.custom` of 13 literals — the
/// third copy of the console navy in the tree, and one that had also kept the
/// pre-S5-5 accent in its `borderAccent`. It is now `MlControlRoom.semantic`.
final _consoleNavy = MlControlRoom.semantic;

/// Console entry point to the Employee Register, opened from the Employees tile
/// on the super-admin company mirror for whichever company is being mirrored.
///
/// The screen itself is shared with the portal — every company opens the same
/// one for itself at `/portal/{org}/register` (P7-27). This wrapper only
/// supplies the console's fixed navy chrome and its own scaffold.
class CompanyEmployeeRegisterScreen extends StatelessWidget {
  final Company company;
  const CompanyEmployeeRegisterScreen({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    return EmployeeRegisterScreen(
      company: company,
      palette: _consoleNavy,
      brightness: Brightness.dark,
    );
  }
}
