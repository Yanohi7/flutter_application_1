import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/presentation/app_preferences.dart';

class PremiumBilling {
  static const _key = String.fromEnvironment(
    'REVENUECAT_SDK_KEY',
    defaultValue: kDebugMode ? 'test_RWgLmIKGjVqvymQxwZPfyQDJRuQ' : '',
  );

  static const _entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'entrynote_premium',
  );

  static bool _ready = false;
  static bool get isAvailable => _ready;

  static Future<void> configure() async {
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final validKey =
        _key.startsWith('goog_') || (kDebugMode && _key.startsWith('test_'));
    if (!validKey || _entitlementId.isEmpty) return;

    try {
      await Purchases.configure(PurchasesConfiguration(_key));
      _ready = true;
      Purchases.addCustomerInfoUpdateListener(_updatePremium);
      unawaited(_refreshPremium());
    } catch (error) {
      debugPrint('Could not start purchase service: ${error.runtimeType}');
    }
  }

  static Future<void> _refreshPremium() async {
    try {
      _updatePremium(await Purchases.getCustomerInfo());
    } catch (error) {
      debugPrint('Could not refresh Premium: ${error.runtimeType}');
    }
  }

  static void _updatePremium(CustomerInfo info) {
    appPreferences.updatePurchasedPremium(_isEntitled(info));
  }

  static bool _isEntitled(CustomerInfo info) =>
      info.entitlements.active.containsKey(_entitlementId);

  static Future<Package?> loadLifetime() async {
    if (!_ready) return null;
    final offerings = await Purchases.getOfferings();
    return offerings.all['default']?.lifetime;
  }

  static Future<bool> buy(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    _updatePremium(result.customerInfo);
    return _isEntitled(result.customerInfo);
  }

  static Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    _updatePremium(info);
    return _isEntitled(info);
  }
}
