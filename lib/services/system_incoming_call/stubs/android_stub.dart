/// ANDROID (вставлять на устройстве / в android/, не обязательно в git)
///
/// Канал: su.dyhanie/system_incoming_call
/// Events: su.dyhanie/system_incoming_call_events
///
/// Методы MethodChannel:
///   getPushToken → String?   (FCM token)
///   showIncoming(map)        (room, from, offer?)
///   endCall()
///
/// EventChannel payload:
///   { type: 'incoming'|'accepted'|'declined', payload: { room, from, offer? } }
///
/// Реализация позже:
///   - FirebaseMessagingService
///   - high-priority notification + fullScreenIntent
///   - по Accept → startActivity → FlutterEngine → event 'accepted'
///
/// Этот файл — только описание. Код Kotlin/Java в android/app/...
class AndroidSystemIncomingCallStub {
  AndroidSystemIncomingCallStub._();
}