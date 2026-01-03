import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 信令消息类型
enum SignalingMessageType {
  offer,
  answer,
  iceCandidate,
  connect,
  disconnect,
}

/// 信令消息模型
class SignalingMessage {
  final SignalingMessageType type;
  final Map<String, dynamic>? data;

  SignalingMessage({
    required this.type,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
    };
  }

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: SignalingMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SignalingMessageType.connect,
      ),
      data: json['data'],
    );
  }
}

/// TCP信令服务
/// 用于交换WebRTC的Offer/Answer和ICE候选
class SignalingService {
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  Socket? _acceptedSocket; // 服务器模式下的已接受连接
  final StreamController<SignalingMessage> _messageController =
      StreamController<SignalingMessage>.broadcast();

  /// 消息流
  Stream<SignalingMessage> get messageStream => _messageController.stream;

  bool _isServerRunning = false;
  bool _isClientConnected = false;

  /// 启动信令服务器（作为被连接方）
  Future<void> startServer(int port) async {
    try {
      if (_isServerRunning) {
        return;
      }

      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isServerRunning = true;

      if (kDebugMode) {
        print('信令服务器已启动，监听端口: $port');
      }

      _serverSocket!.listen((Socket socket) {
        if (kDebugMode) {
          print('客户端已连接: ${socket.remoteAddress.address}:${socket.remotePort}');
        }
        
        // 保存接受的连接
        _acceptedSocket = socket;

        socket.listen(
          (data) {
            try {
              final messageStr = utf8.decode(data).trim();
              final messages = messageStr.split('\n');
              for (final msg in messages) {
                if (msg.isNotEmpty) {
                  final message = SignalingMessage.fromJson(
                    jsonDecode(msg),
                  );
                  _messageController.add(message);
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('解析消息失败: $e');
              }
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('Socket错误: $error');
            }
            socket.close();
            _acceptedSocket = null;
          },
          onDone: () {
            if (kDebugMode) {
              print('客户端断开连接');
            }
            socket.close();
            _acceptedSocket = null;
          },
        );
      });
    } catch (e) {
      if (kDebugMode) {
        print('启动信令服务器失败: $e');
      }
      rethrow;
    }
  }

  /// 连接到信令服务器（作为连接方）
  Future<void> connectToServer(String host, int port) async {
    try {
      if (_isClientConnected && _clientSocket != null) {
        return;
      }

      _clientSocket = await Socket.connect(host, port);
      _isClientConnected = true;

      if (kDebugMode) {
        print('已连接到信令服务器: $host:$port');
      }

      _clientSocket!.listen(
        (data) {
          try {
            final messageStr = utf8.decode(data).trim();
            final messages = messageStr.split('\n');
            for (final msg in messages) {
              if (msg.isNotEmpty) {
                final message = SignalingMessage.fromJson(
                  jsonDecode(msg),
                );
                _messageController.add(message);
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('解析消息失败: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('Socket错误: $error');
          }
          _isClientConnected = false;
        },
        onDone: () {
          if (kDebugMode) {
            print('与服务器断开连接');
          }
          _isClientConnected = false;
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('连接信令服务器失败: $e');
      }
      _isClientConnected = false;
      rethrow;
    }
  }

  /// 发送消息（客户端模式）
  Future<void> sendMessage(SignalingMessage message) async {
    if (_clientSocket == null || !_isClientConnected) {
      throw Exception('客户端未连接');
    }

    try {
      final json = jsonEncode(message.toJson());
      _clientSocket!.add(utf8.encode('$json\n'));
      await _clientSocket!.flush();
    } catch (e) {
      if (kDebugMode) {
        print('发送消息失败: $e');
      }
      rethrow;
    }
  }

  /// 发送消息到已连接的客户端（服务器模式）
  Future<void> sendMessageToClient(SignalingMessage message) async {
    if (_acceptedSocket == null) {
      throw Exception('没有已接受的客户端连接');
    }

    try {
      final json = jsonEncode(message.toJson());
      _acceptedSocket!.add(utf8.encode('$json\n'));
      await _acceptedSocket!.flush();
    } catch (e) {
      if (kDebugMode) {
        print('发送消息到客户端失败: $e');
      }
      rethrow;
    }
  }

  /// 停止服务器
  Future<void> stopServer() async {
    if (_serverSocket != null) {
      await _serverSocket!.close();
      _serverSocket = null;
      _isServerRunning = false;
      if (kDebugMode) {
        print('信令服务器已停止');
      }
    }
  }

  /// 断开客户端连接
  Future<void> disconnect() async {
    if (_clientSocket != null) {
      await _clientSocket!.close();
      _clientSocket = null;
      _isClientConnected = false;
      if (kDebugMode) {
        print('已断开连接');
      }
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    await stopServer();
    await disconnect();
    await _messageController.close();
  }
}
