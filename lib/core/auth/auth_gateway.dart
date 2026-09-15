// Internal contract members are documented by their owning boundary.
// ignore_for_file: public_member_api_docs
import 'package:flutter/foundation.dart';

/// External authentication boundary, replaceable in offline tests.
abstract class AuthGateway extends ChangeNotifier {
  bool get configured;
  bool get loading;
  bool get failed;
  bool get signingIn;
  bool get signInFailed;
  Future<void> signIn();
  String? get sessionKey;
  Future<void> initialize();
  Future<String> token({bool refresh = false});
  Future<void> signOut();
}
