import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }

    throw UnsupportedError(
      'FirebaseOptions não configurado para esta plataforma.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmYQ51K2IK-NrlW4QadM-bgJosqRmuYWU',
    appId: '1:27442511194:android:00d18bf9d6618b052f4763',
    messagingSenderId: '27442511194',
    projectId: 'motogoapp-573e1',
    storageBucket: 'motogoapp-573e1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBhy815IfYa2YeuFbBA3V-XkN4XtK9qiwo',
    appId: '1:27442511194:ios:6b1b0bc0188f44a92f4763',
    messagingSenderId: '27442511194',
    projectId: 'motogoapp-573e1',
    storageBucket: 'motogoapp-573e1.firebasestorage.app',
    iosBundleId: 'com.example.motogo',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJfhQafVrgwtUnnsKZxKa8Xne7db7CvmI',
    appId: '1:27442511194:web:ea3665ec403427112f4763',
    messagingSenderId: '27442511194',
    projectId: 'motogoapp-573e1',
    authDomain: 'motogoapp-573e1.firebaseapp.com',
    storageBucket: 'motogoapp-573e1.firebasestorage.app',
    measurementId: 'G-G5VLR3T41X',
  );
}