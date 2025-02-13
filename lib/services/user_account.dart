import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beatconnect_launch_mvp/lib.dart';

enum SettingsPrivacyView {
  friends,
  nobody,
  everyone,
}

String privacyViewValue(SettingsPrivacyView view) {
  return {
    SettingsPrivacyView.friends: "friends",
    SettingsPrivacyView.nobody: "nobody",
    SettingsPrivacyView.everyone: "everyone",
  }[view]!;
}

String privacyViewLabel(view) {
  return {
    SettingsPrivacyView.friends: "Amigos",
    SettingsPrivacyView.nobody: "Nadie",
    SettingsPrivacyView.everyone: "Todos",
  }[view]!;
}

SettingsPrivacyView privacyFromValue(String? value) {
  if (value == null) return SettingsPrivacyView.everyone;
  return {
    "friends": SettingsPrivacyView.friends,
    "nobody": SettingsPrivacyView.nobody,
    "everyone": SettingsPrivacyView.everyone,
  }[value]!;
}

abstract class UserAccountService {
  static Future<String> getAccountName(String accountRef) async {
    final doc = await FirebaseFirestore.instance.doc(accountRef).get();
    return doc.data()!["name"] as String;
  }

  static Future<void> changeProfileAvatarVisibility({
    required String accountRef,
    required SettingsPrivacyView value,
  }) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "profileAvatarVisibility": privacyViewValue(value),
    });
  }

  static Future<SettingsPrivacyView> getProfileAvatarVisibility(
      String accountRef) async {
    final doc = await FirebaseFirestore.instance.doc(accountRef).get();
    final value = doc.data()!["profileAvatarVisibility"] as String?;
    return privacyFromValue(value);
  }

  static Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      searchAccountsVisiting(String accountRef, String searchText) async {
    final people = await UserAccountService.searchAccounts(searchText);

    final peopleVisiting = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (var personDoc in people) {
      var profileTripStatusVisibility =
          personDoc.data()["profileTripStatusVisibility"];
      var isVisible = profileTripStatusVisibility == "everyone" ||
          profileTripStatusVisibility == null;

      if (isVisible && personDoc.data()['currentVisit'] != null) {
        peopleVisiting.add(personDoc);
      }
    }
    return peopleVisiting
        .where((element) => (element["name"] as String).toLowerCase().contains(
              searchText.toLowerCase(),
            ))
        .toList();
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      searchAccounts(
    String searchText, {
    String? category,
  }) async {
    QuerySnapshot<Map<String, dynamic>> results = await FirebaseFirestore
        .instance
        .collection("users")
        .where("category", isEqualTo: category)
        .get();
    var query = results.docs
        .where((element) => (element["name"] as String).toLowerCase().contains(
              searchText.toLowerCase(),
            ));
    return query.toList();
  }

  static Future<void> createAccount({
    required String email,
    required String password,
    required String name,
    required Uint8List? image,
    LatLng? location,
    String? address,
    String? category,
    UserAccountType type = UserAccountType.user,
    required FirebaseApp firebaseApp,
  }) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final user = (await FirebaseAuth.instanceFor(app: firebaseApp)
              .createUserWithEmailAndPassword(
        email: email,
        password: password,
      ))
          .user!;
      user.sendEmailVerification();
      final id = user.uid;

      transaction = transaction
          .set(FirebaseFirestore.instance.collection("users").doc(id), {
        "name": name,
        "email": email,
        "address": address,
        "category": category,
        "type": type.index,
        "location": location != null
            ? GeoPoint(location.latitude, location.longitude)
            : null,
      });

      String? imagePath;
      try {
        image != null
            ? imagePath = await setAvatar(accountRef: id, image: image)
            : null;
      } catch (e) {
        imagePath = null;
      }

      transaction = transaction
          .update(FirebaseFirestore.instance.collection("users").doc(id), {
        "image": imagePath,
      });
    });
  }

  static Future<void> setLocation({
    required String accountRef,
    required LatLng location,
  }) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "location": GeoPoint(location.latitude, location.longitude),
    });
  }

  static Future<String> setAvatar({
    required String accountRef,
    required Uint8List image,
  }) async {
    final imagePath = await FirebaseStorageService.uploadFile(
      path: "users/$accountRef/avatar",
      fileName: "avatar",
      fileExtension: "jpg",
      fileData: base64.encode(image),
      format: PutStringFormat.base64,
      metadata: SettableMetadata(
        contentType: "image/jpeg",
      ),
    );

    return imagePath;
  }

  static Future<String> setWallpaper({
    required String accountRef,
    required Uint8List image,
  }) async {
    final imagePath = await FirebaseStorageService.uploadFile(
      path: "users/$accountRef/wallpaper",
      fileName: "wallpaper",
      fileExtension: "jpg",
      fileData: base64.encode(image),
      format: PutStringFormat.base64,
      metadata: SettableMetadata(
        contentType: "image/jpeg",
      ),
    );

    return imagePath;
  }

  static Future<void> changeAvatar({
    required Uint8List image,
    required String accountRef,
  }) async {
    var path = await setAvatar(accountRef: accountRef, image: image);

    return FirebaseFirestore.instance
        .collection("users")
        .doc(accountRef)
        .update({
      "image": path,
    });
  }

  static Future<void> changeWallpaper({
    required Uint8List image,
    required String accountRef,
  }) async {
    var path = await setWallpaper(accountRef: accountRef, image: image);

    return FirebaseFirestore.instance
        .collection("users")
        .doc(accountRef)
        .update({
      "wallpaper": path,
    });
  }

  static DocumentReference<Map<String, dynamic>> getUserAccountRef(String? id) {
    return FirebaseFirestore.instance.collection("users").doc(id);
  }

  static DocumentReference<Map<String, dynamic>> getUserAccountDoc(
      String path) {
    return FirebaseFirestore.instance.doc(path);
  }

  static Future<void> saveActiveStatus(String uid, {bool active = true}) {
    return FirebaseFirestore.instance.collection("users").doc(uid).update({
      "active": active,
      "lastActive": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addAcademicStudy({
    required String accountRef,
    required String value,
  }) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "academicStudies": FieldValue.arrayUnion([value]),
    });
  }

  static Future<void> removeAcademicStudy({
    required String accountRef,
    required String value,
  }) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "academicStudies": FieldValue.arrayRemove([value]),
    });
  }

  static Future<void> changeMaritalStatus({
    required String accountRef,
    required String value,
  }) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "maritalStatus": value,
    });
  }

  static Future<SettingsPrivacyView> getProfileStatusVisibility(
      String accountRef) {
    return FirebaseFirestore.instance.doc(accountRef).get().then(
        (value) => privacyFromValue(value.data()!["profileStatusVisibility"]));
  }

  static Future<void> changeProfileStatusVisibility(
      {required String accountRef, required SettingsPrivacyView value}) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "profileStatusVisibility": privacyViewValue(value),
    });
  }

  static Future<SettingsPrivacyView> getProfileBusinessStatusVisibility(
      String accountRef) {
    return FirebaseFirestore.instance.doc(accountRef).get().then(
          (value) => privacyFromValue(
              value.data()!["profileBusinessStatusVisibility"]),
        );
  }

  static Future<void> changeProfileBusinessStatusVisibility(
      {required String accountRef, required SettingsPrivacyView value}) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "profileBusinessStatusVisibility": privacyViewValue(value),
    });
  }

  static Future<void> deleteAccount(String uid,
      {required FirebaseApp firebaseApp}) {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction =
          transaction.delete(FirebaseFirestore.instance.doc("users/$uid"));
      transaction =
          transaction.delete(FirebaseFirestore.instance.doc("business/$uid"));
    });
  }

  static Future<SettingsPrivacyView> getProfileTripStatusVisibility(String s) {
    return FirebaseFirestore.instance.doc(s).get().then(
          (value) =>
              privacyFromValue(value.data()!["profileTripStatusVisibility"]),
        );
  }

  static Future<void> changeProfileTripStatusVisibility(
      {required String accountRef, required SettingsPrivacyView value}) {
    return FirebaseFirestore.instance.doc(accountRef).update({
      "profileTripStatusVisibility": privacyViewValue(value),
    });
  }
}

enum UserAccountType {
  business,
  user,
}
