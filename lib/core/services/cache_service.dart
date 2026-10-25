import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/core/telemetry/device_checkin.dart';

class CacheService {
  static const String _companyKeyPrefix = 'company_data_';
  static const String _employeeKeyPrefix = 'employee_data_';
  static const String _companyEmployeesKey = 'company_employees';
  static const String _availableCompaniesKey = 'available_companies';
  static const String _currentUserIdKey = 'current_user_id';

  // Cache expiration times
  static const Duration _shortCacheTime = Duration(minutes: 5);
  static const Duration _mediumCacheTime = Duration(hours: 1);
  static const Duration _longCacheTime = Duration(days: 1);

  // Store current user ID
  static Future<void> setCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId);
    debugPrint('Set current user ID: $userId');
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  // Clear current user ID
  static Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
    debugPrint('Cleared current user ID');
  }

  // Get company key for specific user
  static String _getCompanyKey(String userId) {
    return '$_companyKeyPrefix$userId';
  }

  // Get employee key for specific user
  static String _getEmployeeKey(String userId) {
    return '$_employeeKeyPrefix$userId';
  }

  // Company data cache
  static Future<void> cacheCompanyData(Map<String, dynamic> data) async {
    if (data['user_id'] == null) {
      debugPrint('Warning: Attempting to cache company data without user_id');
      return;
    }

    final userId = data['user_id'];
    final prefs = await SharedPreferences.getInstance();
    final jsonData = json.encode({
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final cacheKey = _getCompanyKey(userId);
    await prefs.setString(cacheKey, jsonData);
    debugPrint('Cached company data for user: $userId with key: $cacheKey');
  }

  static Future<Map<String, dynamic>?> getCachedCompanyData({
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // If no userId provided, try to get the current user ID
    String? targetUserId = userId;
    if (targetUserId == null) {
      targetUserId = await getCurrentUserId();
      if (targetUserId == null) {
        debugPrint(
          'No user ID provided or found for company data cache lookup',
        );
        return null;
      }
    }

    final cacheKey = _getCompanyKey(targetUserId);
    final jsonData = prefs.getString(cacheKey);

    if (jsonData == null) {
      debugPrint('No cached company data found for user: $targetUserId');
      return null;
    }

    final Map<String, dynamic> data = json.decode(jsonData);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

    // Check if cache is expired (1 hour)
    if (DateTime.now().difference(timestamp) > _mediumCacheTime) {
      debugPrint('Cached company data expired for user: $targetUserId');
      await prefs.remove(cacheKey);
      return null;
    }

    debugPrint('Retrieved cached company data for user: $targetUserId');
    return data['data'];
  }

  // Employee data cache
  static Future<void> cacheEmployeeData(Map<String, dynamic> data) async {
    if (data['user_id'] == null) {
      debugPrint('Warning: Attempting to cache employee data without user_id');
      return;
    }

    final userId = data['user_id'];
    final prefs = await SharedPreferences.getInstance();
    final jsonData = json.encode({
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final cacheKey = _getEmployeeKey(userId);
    await prefs.setString(cacheKey, jsonData);
    debugPrint('Cached employee data for user: $userId with key: $cacheKey');
  }

  static Future<Map<String, dynamic>?> getCachedEmployeeData({
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // If no userId provided, try to get the current user ID
    String? targetUserId = userId;
    if (targetUserId == null) {
      targetUserId = await getCurrentUserId();
      if (targetUserId == null) {
        debugPrint(
          'No user ID provided or found for employee data cache lookup',
        );
        return null;
      }
    }

    final cacheKey = _getEmployeeKey(targetUserId);
    final jsonData = prefs.getString(cacheKey);

    if (jsonData == null) {
      debugPrint('No cached employee data found for user: $targetUserId');
      return null;
    }

    final Map<String, dynamic> data = json.decode(jsonData);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

    // Check if cache is expired (1 hour)
    if (DateTime.now().difference(timestamp) > _mediumCacheTime) {
      debugPrint('Cached employee data expired for user: $targetUserId');
      await prefs.remove(cacheKey);
      return null;
    }

    debugPrint('Retrieved cached employee data for user: $targetUserId');
    return data['data'];
  }

  // Company employees cache
  static Future<void> cacheCompanyEmployees(
    String companyId,
    List<Map<String, dynamic>> employees,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = json.encode({
      'data': employees,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString('${_companyEmployeesKey}_$companyId', jsonData);
  }

  static Future<List<Map<String, dynamic>>?> getCachedCompanyEmployees(
    String companyId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('${_companyEmployeesKey}_$companyId');

    if (jsonData == null) return null;

    final Map<String, dynamic> data = json.decode(jsonData);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

    // Check if cache is expired (5 minutes)
    if (DateTime.now().difference(timestamp) > _shortCacheTime) {
      await prefs.remove('${_companyEmployeesKey}_$companyId');
      return null;
    }

    return List<Map<String, dynamic>>.from(data['data']);
  }

  static Future<void> clearCompanyEmployeesCache({String? companyId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (companyId != null) {
      await prefs.remove('${_companyEmployeesKey}_$companyId');
      debugPrint('Cleared company employees cache for company: $companyId');
      return;
    }

    for (final key in prefs.getKeys()) {
      if (key.startsWith('${_companyEmployeesKey}_')) {
        await prefs.remove(key);
      }
    }

    debugPrint('Cleared all company employees caches');
  }

  // Available companies cache
  static Future<void> cacheAvailableCompanies(
    List<Map<String, dynamic>> companies,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = json.encode({
      'data': companies,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(_availableCompaniesKey, jsonData);
  }

  static Future<List<Map<String, dynamic>>?>
  getCachedAvailableCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(_availableCompaniesKey);

    if (jsonData == null) return null;

    final Map<String, dynamic> data = json.decode(jsonData);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);

    // Check if cache is expired (1 day)
    if (DateTime.now().difference(timestamp) > _longCacheTime) {
      await prefs.remove(_availableCompaniesKey);
      return null;
    }

    return List<Map<String, dynamic>>.from(data['data']);
  }

  // Compatibility layer for legacy "secure" cache helpers.
  // We back these with SharedPreferences so desktop builds do not depend on
  // platform-specific secure storage plugins.
  static Future<void> saveSecureData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getSecureData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> removeSecureData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // Clear employee cache for a specific user
  static Future<void> clearEmployeeCache({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (userId != null) {
      // Clear cache for specific user
      final cacheKey = _getEmployeeKey(userId);
      await prefs.remove(cacheKey);
      debugPrint('Cleared employee cache for user: $userId');
    } else {
      // Clear all employee caches if no userId specified
      final currentUserId = await getCurrentUserId();
      if (currentUserId != null) {
        final cacheKey = _getEmployeeKey(currentUserId);
        await prefs.remove(cacheKey);
        debugPrint('Cleared employee cache for current user: $currentUserId');
      }

      // Also clear legacy cache key
      await prefs.remove(_employeeKeyPrefix);
      debugPrint('Cleared legacy employee cache');
    }
  }

  // Clear company cache for a specific user
  static Future<void> clearCompanyCache({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (userId != null) {
      // Clear cache for specific user
      final cacheKey = _getCompanyKey(userId);
      await prefs.remove(cacheKey);
      debugPrint('Cleared company cache for user: $userId');
    } else {
      // Clear all company caches if no userId specified
      final currentUserId = await getCurrentUserId();
      if (currentUserId != null) {
        final cacheKey = _getCompanyKey(currentUserId);
        await prefs.remove(cacheKey);
        debugPrint('Cleared company cache for current user: $currentUserId');
      }

      // Also clear legacy cache key
      await prefs.remove(_companyKeyPrefix);
      debugPrint('Cleared legacy company cache');
    }
  }

  // Clear user-specific cache (both company and employee)
  static Future<void> clearUserCache(String userId) async {
    await clearCompanyCache(userId: userId);
    await clearEmployeeCache(userId: userId);
    debugPrint('Cleared all cache for user: $userId');
  }

  // Clear cache for current user
  static Future<void> clearCurrentUserCache() async {
    final currentUserId = await getCurrentUserId();
    if (currentUserId != null) {
      await clearUserCache(currentUserId);
    }
    await clearCurrentUserId();
    debugPrint('Cleared all cache for current user');
  }

  /// Keys that describe the INSTALL rather than whoever is signed in, kept
  /// by [clearAllCache].
  ///
  /// Sign-in and sign-out both call [clearAllCache]. It wiped the device
  /// check-in id with everything else, so each sign-in minted a new id and
  /// the admin's device list (Crash reports) grew a phantom device every time
  /// somebody signed in on the same phone - three for one emulator in an hour
  /// (2026-10-25). The WhatsApp re-verification stamp is NOT here on purpose:
  /// it is not tied to a user, so a second person on the same phone must not
  /// inherit the first one's verification.
  static const deviceScopedKeys = {DeviceCheckin.idKey};

  // Clear all cache
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {
      for (final k in deviceScopedKeys)
        if (prefs.getString(k) != null) k: prefs.getString(k)!,
    };
    await prefs.clear();
    for (final e in keep.entries) {
      await prefs.setString(e.key, e.value);
    }
    debugPrint('Cleared all cache');
  }
}
