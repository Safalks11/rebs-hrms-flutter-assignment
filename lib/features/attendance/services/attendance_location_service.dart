import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rebs_hrms_assignment/features/office_profile/models/office_location.dart';
import 'package:rebs_hrms_assignment/features/office_profile/services/office_profile_store.dart';

class AttendanceLocation {
  final double latitude;
  final double longitude;
  final double accuracy;

  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

enum AttendanceLocationFailure {
  officeNotConfigured,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  unavailable,
  inaccurate,
  outsideOffice,
}

class AttendanceLocationException implements Exception {
  final AttendanceLocationFailure reason;

  const AttendanceLocationException(this.reason);

  String get message {
    switch (reason) {
      case AttendanceLocationFailure.officeNotConfigured:
        return 'Set valid office coordinates in Office Profile before marking attendance.';
      case AttendanceLocationFailure.servicesDisabled:
        return 'Turn on location services and try again.';
      case AttendanceLocationFailure.permissionDenied:
        return 'Location permission is required to mark attendance.';
      case AttendanceLocationFailure.permissionDeniedForever:
        return 'Allow location access in app settings to mark attendance.';
      case AttendanceLocationFailure.timedOut:
        return 'Getting your location timed out. Please try again.';
      case AttendanceLocationFailure.unavailable:
        return 'Your current location is unavailable. Please try again.';
      case AttendanceLocationFailure.inaccurate:
        return 'Location accuracy is too low. Move to an open area and try again.';
      case AttendanceLocationFailure.outsideOffice:
        return 'You must be within 200 metres of the office to mark attendance.';
    }
  }
}

abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<AttendanceLocation> currentLocation();
}

class GeolocatorGateway implements LocationGateway {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<AttendanceLocation> currentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return AttendanceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }
}

class AttendanceLocationService {
  final OfficeProfileStore officeStore;
  final LocationGateway gateway;

  AttendanceLocationService(this.officeStore, {LocationGateway? gateway})
    : gateway = gateway ?? GeolocatorGateway();

  Future<AttendanceLocation> validate() async {
    final OfficeLocation? office;
    try {
      office = await officeStore.load();
    } catch (_) {
      throw const AttendanceLocationException(
        AttendanceLocationFailure.officeNotConfigured,
      );
    }
    if (office == null || !office.isValid) {
      throw const AttendanceLocationException(
        AttendanceLocationFailure.officeNotConfigured,
      );
    }

    try {
      if (!await gateway.isServiceEnabled()) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.servicesDisabled,
        );
      }

      var permission = await gateway.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gateway.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.permissionDeniedForever,
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.permissionDenied,
        );
      }

      final location = await gateway.currentLocation();
      if (!location.latitude.isFinite ||
          !location.longitude.isFinite ||
          !location.accuracy.isFinite ||
          location.accuracy < 0) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.unavailable,
        );
      }
      if (location.accuracy > 100) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.inaccurate,
        );
      }
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        office.latitude,
        office.longitude,
      );
      if (distance > 200) {
        throw const AttendanceLocationException(
          AttendanceLocationFailure.outsideOffice,
        );
      }
      return location;
    } on AttendanceLocationException {
      rethrow;
    } on TimeoutException {
      throw const AttendanceLocationException(
        AttendanceLocationFailure.timedOut,
      );
    } catch (_) {
      throw const AttendanceLocationException(
        AttendanceLocationFailure.unavailable,
      );
    }
  }

  Future<void> openSettings(AttendanceLocationFailure reason) async {
    if (reason == AttendanceLocationFailure.servicesDisabled) {
      await Geolocator.openLocationSettings();
    } else if (reason == AttendanceLocationFailure.permissionDeniedForever) {
      await Geolocator.openAppSettings();
    }
  }
}
