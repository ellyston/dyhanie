/// iOS (вставлять на Mac/устройстве в ios/Runner/, репо может без секретов)
///
/// Тот же MethodChannel / EventChannel, что Android.
///
/// Реализация позже:
///   - PushKit (VoIP push)
///   - CallKit CXProvider (Accept / Decline)
///   - по Accept → event 'accepted' + payload
///
/// App Store: VoIP push только для реальных звонков.
class IosSystemIncomingCallStub {
  IosSystemIncomingCallStub._();
}