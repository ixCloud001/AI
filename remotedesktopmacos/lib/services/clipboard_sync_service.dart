import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rich_clipboard/rich_clipboard.dart';

/// 剪贴板数据类型
enum ClipboardDataType {
  text,
  image,
}

/// 剪贴板同步服务
/// 通过WebRTC DataChannel实现双向剪贴板同步
class ClipboardSyncService {
  RTCDataChannel? _dataChannel;
  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();
  
  bool _isEnabled = false;
  bool _isRemoteUpdate = false; // 标记是否由远程更新触发
  
  /// 数据流
  Stream<Uint8List> get dataStream => _dataController.stream;

  /// 启用剪贴板同步
  Future<void> enable({required RTCDataChannel dataChannel, required bool isController}) async {
    if (_isEnabled) {
      return;
    }

    _dataChannel = dataChannel;
    _isEnabled = true;

    _setupDataChannel(_dataChannel!);

    // 如果是控制端（Windows），监听本地剪贴板变化
    if (isController) {
      _startClipboardMonitoring();
    }
  }

  /// 设置DataChannel
  void _setupDataChannel(RTCDataChannel channel) {
    channel.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        // 接收二进制数据（图片）
        _handleRemoteData(message.binary);
      } else {
        // 接收文本数据
        _handleRemoteText(message.text);
      }
    };

    channel.onDataChannelState = (RTCDataChannelState state) {
      if (kDebugMode) {
        print('DataChannel状态: $state');
      }
    };
  }

  /// 处理远程文本数据
  Future<void> _handleRemoteText(String text) async {
    if (kDebugMode) {
      print('收到远程数据: ${text.length} 字符');
    }

    try {
      // 尝试解析为JSON（可能是图片数据）
      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        final type = json['type'] as String?;
        
        if (type == 'image') {
          // 这是图片数据
          final imageDataBase64 = json['data'] as String;
          _isRemoteUpdate = true;
          
          // 解码Base64图片数据
          final imageBytes = base64Decode(imageDataBase64);
          
          // 使用原生方法写入图片到剪贴板（macOS）
          await _writeImageToClipboard(imageBytes);
          
          if (kDebugMode) {
            print('已写入剪贴板图片');
          }
          _isRemoteUpdate = false;
          return;
        }
      } catch (e) {
        // 不是JSON，继续作为普通文本处理
      }

      // 普通文本数据
      _isRemoteUpdate = true;
      
      // 写入本地剪贴板
      await RichClipboard.setData(
        RichClipboardData(text: text),
      );
      
      if (kDebugMode) {
        print('已写入剪贴板文本');
      }
    } catch (e) {
      if (kDebugMode) {
        print('写入剪贴板失败: $e');
      }
    } finally {
      _isRemoteUpdate = false;
    }
  }

  /// 处理远程二进制数据（图片）
  Future<void> _handleRemoteData(Uint8List data) async {
    // 注意：由于DataChannel的限制，图片数据通过文本消息发送（JSON格式）
    // 这里实际上不会收到二进制数据，二进制数据会以文本形式在_handleRemoteText中处理
  }

  /// 写入图片到剪贴板（macOS原生方法）
  Future<void> _writeImageToClipboard(Uint8List imageData) async {
    try {
      const platform = MethodChannel('com.remotedesktopmacos.clipboard');
      await platform.invokeMethod('setImage', imageData);
    } catch (e) {
      if (kDebugMode) {
        print('写入图片到剪贴板失败: $e');
      }
      rethrow;
    }
  }

  /// 从剪贴板读取图片（macOS原生方法）
  Future<Uint8List?> _readImageFromClipboard() async {
    try {
      const platform = MethodChannel('com.remotedesktopmacos.clipboard');
      final result = await platform.invokeMethod<Uint8List>('getImage');
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('读取剪贴板图片失败: $e');
      }
      return null;
    }
  }

  /// 发送文本到远程
  Future<void> sendText(String text) async {
    if (!_isEnabled || _dataChannel == null) {
      return;
    }

    try {
      if (_dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage(text));
        if (kDebugMode) {
          print('已发送文本: $text');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('发送文本失败: $e');
      }
    }
  }

  /// 发送图片到远程
  Future<void> sendImage(Uint8List imageData) async {
    if (!_isEnabled || _dataChannel == null) {
      return;
    }

    try {
      if (_dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
        // 将图片数据编码为Base64
        final base64Data = base64Encode(imageData);
        
        // 创建JSON消息
        final message = jsonEncode({
          'type': 'image',
          'data': base64Data,
        });

        // 发送文本消息（包含JSON）
        _dataChannel!.send(RTCDataChannelMessage(message));
        
        if (kDebugMode) {
          print('已发送图片: ${imageData.length} bytes');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('发送图片失败: $e');
      }
    }
  }

  /// 启动剪贴板监听（控制端）
  void _startClipboardMonitoring() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isEnabled || _isRemoteUpdate) {
        return;
      }

      try {
        // 检查文本变化
        final clipboardData = await RichClipboard.getData();
        if (clipboardData.text != null && clipboardData.text!.isNotEmpty) {
          await sendText(clipboardData.text!);
        }

        // 检查图片变化（macOS）
        final imageData = await _readImageFromClipboard();
        if (imageData != null && imageData.isNotEmpty) {
          await sendImage(imageData);
        }
      } catch (e) {
        if (kDebugMode) {
          print('剪贴板监听错误: $e');
        }
      }
    });
  }

  /// 禁用剪贴板同步
  void disable() {
    _isEnabled = false;
    _dataChannel = null;
  }

  /// 清理资源
  Future<void> dispose() async {
    disable();
    await _dataController.close();
  }
}
