import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:place_picker_google/place_picker_google.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Location Picker'),
      ),
      body: PlacePicker(
        apiKey: String.fromEnvironment('gmap_api_key'),
        useFreeGeocoding: true,
        usePinPointingSearch: true,
        onPlacePicked: (LocationResult result) {
          log("Place picked formattedAddress : ${result.formattedAddress}");
          log("Place picked placeId : ${result.placeId}");
          log("Place picked latitude : ${result.latLng?.latitude}");
          log("Place picked longitude : ${result.latLng?.longitude}");
          Navigator.of(context).pop(result);
        },
        enableNearbyPlaces: false,
        showSearchInput: true,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        searchInputConfig: const SearchInputConfig(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          autofocus: false,
          textDirection: TextDirection.ltr,
        ),
        searchInputDecorationConfig: const SearchInputDecorationConfig(
          hintText: "Search for a building, street or ...",
        ),
        // selectedPlaceWidgetBuilder: (ctx, state, result) {
        //   return const SizedBox.shrink();
        // },
        autocompletePlacesSearchRadius: 150,
      ),
    );
  }
}
