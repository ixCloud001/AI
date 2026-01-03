import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 剪贴板服务
/// 用于监听系统剪贴板变化，并将内容转换为字节流
class ClipboardService {
  /// 剪贴板内容变化流
  final StreamController<Uint8List> _clipboardController =
      StreamController<Uint8List>.broadcast();

  /// 剪贴板内容变化流
  Stream<Uint8List> get clipboardStream => _clipboardController.stream;

  /// 是否正在监听
  bool _isListening = false;

  /// 上次剪贴板内容（用于去重）
  String? _lastTextContent;
  Uint8List? _lastImageContent;

  /// 定时器（用于轮询检查剪贴板变化）
  Timer? _pollingTimer;

  /// 开始监听剪贴板变化
  /// 
  /// 注意：由于 Flutter 没有直接监听剪贴板变化的 API，
  /// 这里使用轮询方式检查剪贴板内容变化
  void startListening({Duration pollingInterval = const Duration(milliseconds: 500)}) {
    if (_isListening) {
      return;
    }

    _isListening = true;

    // 使用定时器轮询检查剪贴板变化
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      _checkClipboardChanges();
    });

    if (kDebugMode) {
      print('剪贴板监听已启动');
    }
  }

  /// 停止监听剪贴板变化
  void stopListening() {
    if (!_isListening) {
      return;
    }

    _isListening = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (kDebugMode) {
      print('剪贴板监听已停止');
    }
  }

  /// 检查剪贴板变化
  Future<void> _checkClipboardChanges() async {
    try {
      // 检查文本内容
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData?.text != null && textData!.text != _lastTextContent) {
        final text = textData.text!;
        _lastTextContent = text;
        final bytes = utf8.encode(text);
        _clipboardController.add(Uint8List.fromList(bytes));
        
        if (kDebugMode) {
          final preview = text.length > 50 
              ? '${text.substring(0, 50)}...' 
              : text;
          print('检测到剪贴板文本变化: $preview');
        }
      }

      // 检查图片内容（使用原生 MethodChannel）
      try {
        const platform = MethodChannel('com.remotedesktopmacos.clipboard');
        final imageBytes = await platform.invokeMethod<Uint8List>('getImage');
        if (imageBytes != null && imageBytes.isNotEmpty) {
          // 简单比较：如果字节数组长度不同，认为内容变化了
          if (_lastImageContent == null || 
              _lastImageContent!.length != imageBytes.length) {
            _lastImageContent = imageBytes;
            _clipboardController.add(imageBytes);
            
            if (kDebugMode) {
              print('检测到剪贴板图片变化: ${imageBytes.length} 字节');
            }
          }
        }
      } catch (e) {
        // 如果没有图片或获取失败，忽略
        if (kDebugMode) {
          print('获取剪贴板图片失败: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('检查剪贴板变化失败: $e');
      }
    }
  }

  /// 获取当前剪贴板内容并转换为字节流
  /// 
  /// 返回格式：
  /// - 如果是文本，返回文本的 UTF-8 编码字节流
  /// - 如果是图片，返回图片的原始字节流
  Future<Uint8List?> getClipboardContentAsBytes() async {
    try {
      // 优先检查图片（使用原生 MethodChannel）
      try {
        const platform = MethodChannel('com.remotedesktopmacos.clipboard');
        final imageBytes = await platform.invokeMethod<Uint8List>('getImage');
        if (imageBytes != null && imageBytes.isNotEmpty) {
          return imageBytes;
        }
      } catch (e) {
        // 如果没有图片，继续检查文本
        if (kDebugMode) {
          print('获取剪贴板图片失败: $e');
        }
      }

      // 检查文本内容
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData != null && textData.text != null) {
        final text = textData.text!;
        final bytes = utf8.encode(text);
        return Uint8List.fromList(bytes);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('获取剪贴板内容失败: $e');
      }
      return null;
    }
  }

  /// 发送数据块
  /// 
  /// 这是一个预留方法，后续会配合 WebRTC 的 DataChannel 使用
  /// 
  /// [data] 要发送的数据字节流
  /// [chunkSize] 每个数据块的大小（默认 16KB）
  /// 
  /// 返回：发送的数据块数量
  Future<int> sendDataChunk(
    Uint8List data, {
    int chunkSize = 16 * 1024, // 16KB
  }) async {
    // TODO: 实现数据分块发送逻辑
    // 这里预留接口，后续配合 WebRTC DataChannel 实现
    
    if (kDebugMode) {
      print('sendDataChunk 被调用，数据大小: ${data.length} 字节，块大小: $chunkSize 字节');
    }

    // 计算需要分多少块
    final totalChunks = (data.length / chunkSize).ceil();
    
    // 模拟分块发送（实际实现需要配合 WebRTC DataChannel）
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < data.length) ? start + chunkSize : data.length;
      final chunk = data.sublist(start, end);
      
      // TODO: 通过 WebRTC DataChannel 发送 chunk
      if (kDebugMode) {
        print('数据块 ${i + 1}/$totalChunks: ${chunk.length} 字节');
      }
    }

    return totalChunks;
  }

  /// 释放资源
  void dispose() {
    stopListening();
    _clipboardController.close();
  }
}

