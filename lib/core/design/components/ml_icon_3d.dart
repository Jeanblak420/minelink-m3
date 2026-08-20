import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Soft-shaded faux-3D icon set — SVGs ported 1:1 from the design system's
/// `components/core/Icon3D.jsx` (`assets/icons3d/{name}.svg`). Use for hero
/// tiles, dashboard headers, stat/feature wells and empty states.
///
/// Prefer resolving a Material Symbols name through [resolveIcon3D] so display
/// primitives auto-upgrade identity glyphs to 3D and leave functional glyphs flat.
class Icon3D extends StatelessWidget {
  final String name; // an Icon3D concept name (see [icon3DNames])
  final double size;

  const Icon3D({super.key, required this.name, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final concept = icon3DNames.contains(name) ? name : 'inventory';
    return SvgPicture.asset(
      'assets/icons3d/$concept.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// The concept names for which a 3D SVG exists (assets/icons3d/*.svg).
const Set<String> icon3DNames = {
  'security', 'route', 'alerts', 'contract', 'inventory', 'shipment',
  'weighbridge', 'map', 'payment', 'team', 'settings', 'dashboard',
  'companies', 'mine', 'token', 'warning', 'energy', 'driver', 'supervisor',
  'buyer', 'console', 'stockpile', 'active', 'expired', 'suspended',
  'history', 'register', 'export',
};

/// Material Symbols name → Icon3D concept (ported from ICON3D_ALIASES).
/// Deduped for Dart (`verified_user` → security).
const Map<String, String> icon3DAliases = {
  'local_shipping': 'shipment', 'truck': 'shipment', 'fire_truck': 'shipment',
  'alt_route': 'route', 'route': 'route', 'directions': 'route', 'fork_right': 'route',
  'balance': 'weighbridge', 'scale': 'weighbridge', 'monitor_weight': 'weighbridge',
  'forklift': 'weighbridge', 'pallet': 'weighbridge',
  'map': 'map', 'place': 'map', 'location_on': 'map', 'my_location': 'map', 'pin_drop': 'map',
  'inventory_2': 'inventory', 'inventory': 'inventory', 'package_2': 'inventory', 'widgets': 'inventory',
  'groups': 'team', 'group': 'team', 'people': 'team', 'diversity_3': 'team',
  'admin_panel_settings': 'settings', 'tune': 'settings', 'settings': 'settings', 'manage_accounts': 'settings',
  'security': 'security', 'shield': 'security', 'verified_user': 'security', 'gpp_good': 'security', 'lock': 'security',
  'description': 'contract', 'article': 'contract', 'assignment': 'contract', 'handshake': 'contract', 'receipt_long': 'contract',
  'dashboard': 'dashboard', 'space_dashboard': 'dashboard', 'speed': 'dashboard', 'monitoring': 'dashboard',
  'notifications': 'alerts', 'notifications_active': 'alerts', 'campaign': 'alerts',
  'payments': 'payment', 'payment': 'payment', 'credit_card': 'payment', 'paid': 'payment',
  'apartment': 'companies', 'business': 'companies', 'domain': 'companies', 'corporate_fare': 'companies',
  'conveyor_belt': 'mine', 'factory': 'mine', 'landscape': 'mine', 'terrain': 'mine', 'diamond': 'mine',
  'key': 'token', 'vpn_key': 'token', 'password': 'token', 'token': 'token',
  'warning': 'warning', 'error': 'warning', 'report': 'warning', 'priority_high': 'warning', 'gpp_maybe': 'warning',
  'bolt': 'energy', 'flash_on': 'energy', 'electric_bolt': 'energy', 'flash': 'energy',
  'badge': 'driver', 'directions_car': 'driver', 'local_taxi': 'driver', 'drive_eta': 'driver',
  'airport_shuttle': 'driver', 'no_crash': 'driver',
  'engineering': 'supervisor', 'construction': 'supervisor', 'hard_hat': 'supervisor',
  'foreman': 'supervisor', 'supervisor_account': 'supervisor', 'precision_manufacturing': 'supervisor',
  'storefront': 'buyer', 'shopping_bag': 'buyer', 'store': 'buyer', 'shopping_cart': 'buyer',
  'local_mall': 'buyer', 'business_center': 'buyer',
  'dns': 'console', 'terminal': 'console', 'account_tree': 'console', 'developer_board': 'console',
  'hub': 'console', 'memory': 'console', 'settings_applications': 'console', 'shield_person': 'console',
  'stockpile': 'stockpile', 'grain': 'stockpile', 'dataset': 'stockpile',
  'check_circle': 'active', 'task_alt': 'active', 'done_all': 'active',
  'timer_off': 'expired', 'timer': 'expired', 'hourglass_bottom': 'expired',
  'hourglass_empty': 'expired', 'history_toggle_off': 'expired',
  'block': 'suspended', 'do_not_disturb_on': 'suspended', 'cancel': 'suspended',
  'remove_circle': 'suspended', 'gpp_bad': 'suspended',
  'history': 'history', 'restore': 'history', 'timeline': 'history',
  'manage_history': 'history', 'schedule_send': 'history',
  'add_business': 'register', 'domain_add': 'register', 'add_home_work': 'register',
  'open_in_new': 'export', 'launch': 'export', 'ios_share': 'export', 'open_in_full': 'export',
};

/// Resolve a Material Symbols name (or a direct concept) to an Icon3D concept,
/// or null when there is no 3D equivalent (caller should fall back to flat).
String? resolveIcon3D(String name) {
  if (icon3DNames.contains(name)) return name;
  return icon3DAliases[name];
}
