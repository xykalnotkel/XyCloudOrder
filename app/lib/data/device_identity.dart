import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pseudonymous anti-abuse identity; no IMEI, phone number, or advertising ID.
/// Client identifiers are not hardware attestation and can be spoofed on modified devices.
class DeviceIdentity {
  static const _channel=MethodChannel('xycloud/settings');
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  static Future<void>? _preparing;
  static String id='',kind='install',model='';
  static Future<void> prepare()=>_preparing??=_load();
  static Future<void> _load()async{
    try{
      final r=await _channel.invokeMapMethod<String,dynamic>('deviceIdentity');
      if(r!=null&&RegExp(r'^[a-f0-9]{64}$').hasMatch('${r['id']}')){
        id='${r['id']}';kind='${r['kind']}';model='${r['model']??''}';return;
      }
    }catch(_){}
    try{
      final saved=await _storage.read(key:'xy_device_identity_v1');
      if(saved!=null&&RegExp(r'^[a-f0-9]{64}$').hasMatch(saved)){id=saved;return;}
      final random=Random.secure();id=List.generate(32,(_)=>random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
      await _storage.write(key:'xy_device_identity_v1',value:id);
    }catch(_){id='';}
  }
  static Map<String,String> get headers=>{
    if(id.isNotEmpty)'X-XY-Device':id,
    if(id.isNotEmpty)'X-XY-Device-Kind':kind,
    if(model.isNotEmpty)'X-XY-Device-Model':Uri.encodeComponent(model),
  };
}
