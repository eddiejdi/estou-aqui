import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import '../models/chat_message.dart';

typedef MessageCallback = void Function(ChatMessage message);
typedef EstimateCallback = void Function(Map<String, dynamic> data);
typedef CheckinCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _estimateController = StreamController<Map<String, dynamic>>.broadcast();
  final _checkinController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get estimateStream => _estimateController.stream;
  Stream<Map<String, dynamic>> get checkinStream => _checkinController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return;

    _socket = io.io(AppConstants.wsUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .enableAutoConnect()
      .enableReconnection()
      .build(),
    );

    _socket!.onConnect((_) {
      print('🔌 Socket.IO conectado');
    });

    _socket!.on('chat:message', (data) {
      final message = ChatMessage.fromJson(data as Map<String, dynamic>);
      _messageController.add(message);
    });

    _socket!.on('estimate:updated', (data) {
      _estimateController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('checkin:new', (data) {
      _checkinController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('checkout', (data) {
      _checkinController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.onDisconnect((_) {
      print('📴 Socket.IO desconectado');
    });

    _socket!.onError((error) {
      print('❌ Socket.IO erro: $error');
    });
  }

  void joinEvent(String eventId) {
    _socket?.emit('event:join', eventId);
  }

  void leaveEvent(String eventId) {
    _socket?.emit('event:leave', eventId);
  }

  void sendMessage(String eventId, String content, {String type = 'text'}) {
    _socket?.emit('chat:send', {
      'eventId': eventId,
      'content': content,
      'type': type,
    });
  }

  void sendTyping(String eventId) {
    _socket?.emit('chat:typing', {'eventId': eventId});
  }

  void updateLocation(String eventId, double lat, double lng) {
    _socket?.emit('location:update', {
      'eventId': eventId,
      'latitude': lat,
      'longitude': lng,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _estimateController.close();
    _checkinController.close();
  }
}
