import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:beatconnect_launch_mvp/lib.dart';

enum PostVisibility {
  public,
  followers,
  private,
}

typedef FdSnapshot = DocumentSnapshot<Map<String, dynamic>>;

abstract class PostService {
  static Future<void> createPost(
      {required String? accountRef,
      required String content,
      Uint8List? image,
      required PostVisibility visibility}) async {
    assert(accountRef != null);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final imagePath = image != null
          ? await FirebaseStorageService.uploadFile(
              path: "posts/$accountRef/",
              fileName: DateTime.now().millisecondsSinceEpoch.toString(),
              fileExtension: "jpg",
              fileData: base64.encode(image),
              format: PutStringFormat.base64,
              metadata: SettableMetadata(
                contentType: "image/jpeg",
              ),
            )
          : null;

      var post = await FirebaseFirestore.instance.collection('posts').add({
        'accountRef': accountRef,
        'visibility': visibility.index,
        'content': content,
        'image': imagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
        "type": PostType.post.index,
      });
      await PostNotification.sendPostNotification(
        accountRef: accountRef!,
        postRef: post.path,
      );
    });
  }

  static Future<void> deletePost(String postId) async {
    return FirebaseFirestore.instance.doc(postId).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<int> getAccountPostsCount(String? accountRef) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where("deletedAt", isNull: true)
        .where('accountRef', isEqualTo: accountRef)
        .snapshots()
        .map((event) => event.docs.length);
  }

  static Stream<FdSnapshot?> getPost(
    String postRef,
  ) async* {
    var post = await FirebaseFirestore.instance.doc(postRef).get();
    if (post.exists) {
      yield* FirebaseFirestore.instance.doc(postRef).snapshots();
    } else {
      yield null;
    }
  }

  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getAccountPosts(
    String accountRef,
  ) {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((e) {
      final docs = e.docs
          .where((element) =>
              element['deletedAt'] == null &&
              element['accountRef'] == accountRef)
          .toList();
      return docs;
    });
  }

  static Future<List<FdSnapshot>> getAccountFollowingPostFuture(
      String accountRef) async {
    final followingRefs = (await FirebaseFirestore.instance
            .collection("follows")
            .where("followerRef", isEqualTo: accountRef)
            .get())
        .docs
        .map((e) => e['followingRef'])
        .toList()
        .cast<String>();

    final docs = <FdSnapshot>[];

    for (final ref in followingRefs) {
      final data = await FirebaseFirestore.instance
          .collection("posts")
          .where("accountRef", isEqualTo: ref)
          .where("deletedAt", isNull: true)
          .get();
      docs.addAll(data.docs);
    }

    return docs;
  }
}

abstract class PostNotification {
  static Future<void> sendPostNotification({
    required String accountRef,
    required String postRef,
    PostType type = PostType.post,
  }) async {
    var data = await UserAccountService.getUserAccountDoc(accountRef).get();
    var name = data["name"];
    var followers =
        await FollowingFollowersServices.getFollowersRefsFuture(accountRef);
    return NotificationService.sendMultipleNotifications(
      title: "$name ha publicado algo nuevo",
      body: "Revisa la publicación de $name",
      accountRefs: followers,
      type: (() {
        var notificationTypes = {
          PostType.event: NotificationType.event,
          PostType.post: NotificationType.post,
          PostType.survey: NotificationType.survey,
        };

        return notificationTypes[type]!;
      })(),
      arguments: {
        "ref": postRef,
      },
    );
  }
}

enum PostType {
  post,
  survey,
  event,
}
