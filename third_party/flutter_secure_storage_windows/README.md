# Windows secure storage without the legacy ATL plugin

Based on flutter_secure_storage_windows 4.2.2 from https://github.com/mogol/flutter_secure_storage
The upstream license is included in LICENSE

The Dart implementation in lib is copied unchanged from the published package
Only the plugin manifest differs: it registers the Dart DPAPI implementation and does not compile the legacy C++ migration plugin that requires ATL
Development-only dependencies are omitted

This application introduced private fields with the current DPAPI implementation and has no legacy native secure-storage data to migrate
Always use WindowsOptions(useBackwardCompatibility: false)
The cryptography and persistence implementation are unchanged

When upgrading, review the upstream package and this override together
