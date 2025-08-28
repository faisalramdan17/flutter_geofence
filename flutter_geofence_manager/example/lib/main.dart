import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:example/screens/location_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofence_manager/flutter_geofence_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:place_picker_google/place_picker_google.dart';
import 'models/region_model.dart';
import 'services/region_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap
      debugPrint('Notification tapped: ${response.payload}');
    },
  );

  runApp(GeoFencingExampleApp(
    flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
  ));
}

class GeoFencingExampleApp extends StatelessWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const GeoFencingExampleApp({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter GeoFencing Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: GeoFencingHomePage(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin),
    );
  }
}

class GeoFencingHomePage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const GeoFencingHomePage({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  State<GeoFencingHomePage> createState() => _GeoFencingHomePageState();
}

class _GeoFencingHomePageState extends State<GeoFencingHomePage> {
  final FlutterGeofenceManager _geoFencing = FlutterGeofenceManager.instance;

  bool _isInitialized = false;
  bool _isMonitoring = false;
  List<GeoFenceEvent> events = [];
  List<RegionModel> regions = [];
  bool _isLoadingRegions = true;
  StreamSubscription<GeoFenceEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGeoFencing();
    _loadSavedRegions();
  }

  Future<void> _loadSavedRegions() async {
    setState(() {
      _isLoadingRegions = true;
    });

    try {
      final savedRegions = await RegionStorageService.loadRegions();
      setState(() {
        regions = savedRegions;
        _isLoadingRegions = false;
      });
    } catch (e) {
      debugPrint('Failed to load saved regions: $e');
      setState(() {
        _isLoadingRegions = false;
      });
      _showSnackBar('Failed to load saved regions');
    }
  }

  Future<void> _saveRegions() async {
    try {
      await RegionStorageService.saveRegions(regions);
    } catch (e) {
      debugPrint('Failed to save regions: $e');
      _showSnackBar('Failed to save regions');
    }
  }

  Future<void> _addRegion(RegionModel region) async {
    setState(() {
      regions.add(region);
    });
    await _saveRegions();
  }

  Future<void> _updateRegion(RegionModel region, int index) async {
    setState(() {
      regions[index] = region;
    });
    await _saveRegions();
  }

  Future<void> _deleteRegion(int index) async {
    setState(() {
      regions.removeAt(index);
    });
    await _saveRegions();
  }

  Future<LocationResult?> _showLocationPickerDialog() async {
    return Navigator.push<LocationResult?>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );
  }

  Future<void> _showAddRegionDialog() async {
    final TextEditingController idController = TextEditingController();
    final TextEditingController latitudeController = TextEditingController();
    final TextEditingController longitudeController = TextEditingController();
    final TextEditingController radiusController = TextEditingController(text: '100.0');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Region'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    final pickedData = await _showLocationPickerDialog();
                    if (pickedData != null) {
                      setState(() {
                        latitudeController.text = pickedData.latLng?.latitude.toString() ?? '';
                        longitudeController.text = pickedData.latLng?.longitude.toString() ?? '';
                      });
                    }
                  },
                  child: const Text('Pick Location'),
                ),
                Divider(),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Region ID (example: home)',
                    hintText: 'Enter a unique identifier',
                  ),
                ),
                TextField(
                  controller: latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'Enter latitude (-90 to 90)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'Enter longitude (-180 to 180)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                    hintText: 'Enter radius in meters',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                // Validate inputs
                if (idController.text.isEmpty ||
                    latitudeController.text.isEmpty ||
                    longitudeController.text.isEmpty ||
                    radiusController.text.isEmpty) {
                  _showSnackBar('All fields are required');
                  return;
                }

                try {
                  final double latitude = double.parse(latitudeController.text);
                  final double longitude = double.parse(longitudeController.text);
                  final double radius = double.parse(radiusController.text);

                  // Check if region ID is already used
                  if (regions.any((r) => r.id == idController.text)) {
                    _showSnackBar('Region ID already exists. Please use a unique ID.');
                    return;
                  }

                  // Create new region
                  final RegionModel newRegion = RegionModel(
                    id: idController.text,
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                  );

                  // Add to list and save
                  _addRegion(newRegion);
                  Navigator.of(context).pop();
                } catch (e) {
                  _showSnackBar('Invalid input. Please enter valid numbers.');
                }
              },
            ),
          ],
        );
      },
    );

    // idController.dispose();
    // latitudeController.dispose();
    // longitudeController.dispose();
    // radiusController.dispose();
  }

  Future<void> _showEditRegionDialog(RegionModel region, int index) async {
    final TextEditingController idController = TextEditingController(text: region.id);
    final TextEditingController latitudeController = TextEditingController(text: region.latitude.toString());
    final TextEditingController longitudeController =
        TextEditingController(text: region.longitude.toString());
    final TextEditingController radiusController = TextEditingController(text: region.radius.toString());

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Region'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    final pickedData = await _showLocationPickerDialog();
                    if (pickedData != null) {
                      setState(() {
                        latitudeController.text = pickedData.latLng?.latitude.toString() ?? '';
                        longitudeController.text = pickedData.latLng?.longitude.toString() ?? '';
                      });
                    }
                  },
                  child: const Text('Pick Location'),
                ),
                Divider(),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Region ID (example: home)',
                    hintText: 'Enter a unique identifier',
                  ),
                ),
                TextField(
                  controller: latitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'Enter latitude (-90 to 90)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: longitudeController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'Enter longitude (-180 to 180)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                    hintText: 'Enter radius in meters',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                // Validate inputs
                if (idController.text.isEmpty ||
                    latitudeController.text.isEmpty ||
                    longitudeController.text.isEmpty ||
                    radiusController.text.isEmpty) {
                  _showSnackBar('All fields are required');
                  return;
                }

                try {
                  final double latitude = double.parse(latitudeController.text);
                  final double longitude = double.parse(longitudeController.text);
                  final double radius = double.parse(radiusController.text);

                  // Check if region ID is already used (by any other region)
                  if (idController.text != region.id && regions.any((r) => r.id == idController.text)) {
                    _showSnackBar('Region ID already exists. Please use a unique ID.');
                    return;
                  }

                  // Create updated region
                  final RegionModel updatedRegion = RegionModel(
                    id: idController.text,
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                  );

                  // Update list and save
                  _updateRegion(updatedRegion, index);
                  Navigator.of(context).pop();
                } catch (e) {
                  _showSnackBar('Invalid input. Please enter valid numbers.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteRegionDialog(int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Region'),
          content: Text('Are you sure you want to delete the region "${regions[index].id}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                _deleteRegion(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGeoFencing() async {
    try {
      await _geoFencing.initialize();

      // Request notification permissions
      await _requestNotificationPermissions();

      if (Platform.isAndroid) {
        final hasPermissions = await _requestAndroidPermissions();
        if (!hasPermissions) {
          _showSnackBar('Location permissions required for geofencing');
          return;
        }
      } else if (Platform.isIOS) {
        // For iOS, request notification permission
        // iOS permissions are handled automatically by the system
        debugPrint('iOS notification permissions will be requested by the system');
      }
      setState(() {
        _isInitialized = true;
      });
      _listenToEvents();
      // await _startMonitoring();
    } catch (e) {
      debugPrint('Failed to initialize geofencing: $e');
      _showSnackBar('Failed to initialize geofencing: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        // For Android 13+, request notification permission
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation = widget
            .flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          final bool? granted = await androidImplementation.requestNotificationsPermission();
          debugPrint('Android notification permission granted: $granted');
        }
      } else if (Platform.isIOS) {
        // For iOS, request notification permission
        // iOS permissions are handled automatically by the system
        debugPrint('iOS notification permissions will be requested by the system');
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    try {
      // Request location permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationAlways,
        Permission.locationWhenInUse,
      ].request();

      // Check if all permissions are granted
      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (allGranted) {
        log('All location permissions granted');
        return true;
      } else {
        log('Some permissions denied: $statuses');

        // Show dialog explaining why permissions are needed
        bool shouldOpenSettings = await _showPermissionDialog();
        if (shouldOpenSettings) {
          await openAppSettings();
        }
        return false;
      }
    } catch (e) {
      log('Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Location Permissions Required'),
              content: Text(
                'Geofencing requires location permissions to work properly. '
                'Please grant location permissions in app settings.',
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Open Settings'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _listenToEvents() {
    debugPrint("UI: Subscribing to plugin stream");
    _eventSubscription = _geoFencing.onEvent().listen(
      (event) {
        setState(() {
          events.add(event);
        });
        log("UI: Received event ${event.id}-----${event.transitionType}");

        // Show notification for the geofence event
        _showGeofenceNotification(event);
      },
      onError: (error) => debugPrint("UI: Stream error: $error"),
      onDone: () => debugPrint("UI: Stream done"),
    );
  }

  Future<void> _startMonitoring() async {
    if (!_isInitialized) {
      _showSnackBar('Please wait for initialization to complete');
      return;
    }
    if (regions.isEmpty) {
      _showSnackBar('Please add at least one region to monitor');
      return;
    }
    try {
      // Convert RegionModel to GeoFenceRegion
      final geoFenceRegions = regions
          .map((region) => GeoFenceRegion(
                id: region.id,
                latitude: region.latitude,
                longitude: region.longitude,
                radius: region.radius,
              ))
          .toList();

      // final geoFenceRegions = [
      //   GeoFenceRegion(
      //     id: 'home',
      //     latitude: -6.174879, // Asya Daily
      //     longitude: 106.7090942,
      //     radius: 100.0, // 100 meters
      //   ),
      //   GeoFenceRegion(
      //     id: 'swiming_pool',
      //     latitude: -6.175065, // San Francisco coordinates as example
      //     longitude: 106.710677,
      //     radius: 100.0, // 100 meters
      //   ),
      //   GeoFenceRegion(
      //     id: 'office',
      //     latitude: 37.7849,
      //     longitude: -122.4094,
      //     radius: 200.0, // 200 meters
      //   ),
      // ];

      bool status = await _geoFencing.registerGeoFences(geoFenceRegions);
      setState(() {
        _isMonitoring = status;
      });
      _showSnackBar('Started monitoring ${geoFenceRegions.length} geofences');
    } catch (e) {
      _showSnackBar('Failed to start monitoring: $e');
    }
  }

  Future<void> _stopMonitoring() async {
    try {
      // Remove all geofences
      for (var region in regions) {
        await _geoFencing.removeGeoFence(region.id);
      }

      setState(() {
        _isMonitoring = false;
        events.clear();
      });
      _showSnackBar('Stopped monitoring geofences');
    } catch (e) {
      _showSnackBar('Failed to stop monitoring: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showGeofenceNotification(GeoFenceEvent event) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Events',
      channelDescription: 'Notifications for geofence enter/exit events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final String title = '${event.transitionType.name.toUpperCase()} - ${event.id}';
    final String body = 'Lat: ${event.latitude.toStringAsFixed(4)}, '
        'Lng: ${event.longitude.toStringAsFixed(4)}\n'
        'Time: ${event.timestamp.toLocal()}';

    await widget.flutterLocalNotificationsPlugin.show(
      event.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: 'geofence_${event.id}_${event.transitionType.name}',
    );

    debugPrint('Notification shown for geofence event: ${event.id} - ${event.transitionType.name}');
  }

  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications for debugging',
      importance: Importance.none,
      priority: Priority.low,
      showWhen: true,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSDetails,
    );

    await widget.flutterLocalNotificationsPlugin.show(
      1, // Test notification ID
      'Test Notification',
      'This is a test notification to verify the notification system is working!',
      platformChannelSpecifics,
      payload: 'test_notification',
    );

    debugPrint('Test notification shown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Flutter GeoFencing Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text('Initialized: ${_isInitialized ? "Yes" : "No"}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _isMonitoring ? Icons.location_on : Icons.location_off,
                          color: _isMonitoring ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('Monitoring: ${_isMonitoring ? "Yes" : "No"}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Regions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Regions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (!_isMonitoring)
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Add Region',
                            onPressed: _showAddRegionDialog,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingRegions)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Loading regions...'),
                            ],
                          ),
                        ),
                      )
                    else if (regions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            'No regions added yet. Add a region to start monitoring.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: regions.length,
                        itemBuilder: (context, index) {
                          final region = regions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            color: Colors.blue.shade100,
                            child: ListTile(
                              title: Text(region.id),
                              subtitle: Text(
                                'Lat: ${region.latitude.toStringAsFixed(4)},\n'
                                'Lng: ${region.longitude.toStringAsFixed(4)}\n'
                                'Radius: ${region.radius.toStringAsFixed(1)}m',
                              ),
                              isThreeLine: true,
                              leading: const Icon(Icons.location_on_outlined),
                              trailing: !_isMonitoring
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          child: const Icon(Icons.edit),
                                          onTap: () => _showEditRegionDialog(region, index),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          child: const Icon(Icons.delete, color: Colors.red),
                                          onTap: () => _showDeleteRegionDialog(index),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isMonitoring ? _startMonitoring : null,
                    child: const Text('Start Monitoring'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop Monitoring'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test Notification Button
            // ElevatedButton.icon(
            //   onPressed: () => _showTestNotification(),
            //   icon: const Icon(Icons.notifications),
            //   label: const Text('Test Notification'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.orange,
            //     foregroundColor: Colors.white,
            //   ),
            // ),
            // const SizedBox(height: 16),

            // Events List
            ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: 200, maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Geofence Events (${events.length})',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: events.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No events yet. Start monitoring to see geofence events.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return ListTile(
                                  leading: Icon(
                                    event.transitionType == TransitionType.enter ? Icons.login : Icons.logout,
                                    color: event.transitionType == TransitionType.enter
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  title: Text('${event.transitionType.name.toUpperCase()} - ${event.id}'),
                                  subtitle: Text(
                                    'Lat: ${event.latitude.toStringAsFixed(4)}, '
                                    'Lng: ${event.longitude.toStringAsFixed(4)}\n'
                                    'Time: ${event.timestamp.toLocal()}',
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
