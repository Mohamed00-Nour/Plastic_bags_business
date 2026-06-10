import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

/// Must run before [Firebase.initializeApp] on Windows.
void configureFirebaseAuthForWindows() {
  if (!Platform.isWindows) return;
  FirebaseAuthPlatform.disableIdTokenChannelOnWindows = true;
}

/// Must run after [Firebase.initializeApp] on Windows.
Future<void> configureFirestoreForWindows() async {
  if (!Platform.isWindows) return;

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  try {
    await FirebaseFirestore.instance.clearPersistence();
  } catch (_) {
    // Safe to ignore on first launch when no cache exists yet.
  }
}
