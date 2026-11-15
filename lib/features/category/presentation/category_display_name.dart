import 'package:flutter_application_1/l10n/app_localizations.dart';

final _guestCategoryName = RegExp(
  r'^(?:Entries from this device|Записи з цього пристрою|Entradas de este dispositivo|Einträge von diesem Gerät|Wpisy z tego urządzenia)( [1-9][0-9]*)?$',
);

extension CategoryDisplayName on AppLocalizations {
  String categoryDisplayName(String name) {
    if (name == 'General') return generalCategory;
    final guestFolder = _guestCategoryName.firstMatch(name);
    if (guestFolder != null) {
      return '$entriesFromThisDevice${guestFolder[1] ?? ''}';
    }
    return name;
  }
}
