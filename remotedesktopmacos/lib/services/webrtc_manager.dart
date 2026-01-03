import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

/// WebRTC连接管理器
class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  final SignalingService _signalingService = SignalingService();
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();

  /// 远程流
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  bool _isInitialized = false;
  bool _isConnected = false;
  RTCDataChannel? _dataChannel;
  final StreamController<RTCDataChannel> _dataChannelController =
      StreamController<RTCDataChannel>.broadcast();

  /// DataChannel流
  Stream<RTCDataChannel> get dataChannelStream => _dataChannelController.stream;

  /// 初始化WebRTC连接
  Future<void> initialize({required bool isOffer}) async {
    if (_isInitialized) {
      return;
    }

    try {
      // 创建PeerConnection配置
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // 设置ICE候选处理
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _signalingService.sendMessage(
            SignalingMessage(
              type: SignalingMessageType.iceCandidate,
              data: {
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              },
            ),
          );
        }
      };

      // 设置远程流处理
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream!);
          _isConnected = true;
          if (kDebugMode) {
            print('收到远程流');
          }
        }
      };

      // 设置连接状态变化
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (kDebugMode) {
          print('连接状态: $state');
        }
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isConnected = true;
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _isConnected = false;
        }
      };

      // 监听信令消息
      _signalingService.messageStream.listen(_handleSignalingMessage);

      // 创建DataChannel（用于剪贴板同步）
      _dataChannel = await _peerConnection!.createDataChannel(
        'clipboard',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 3,
      );
      
      _setupDataChannel(_dataChannel!);

      // 监听DataChannel事件
      _peerConnection!.onDataChannel = (channel) {
        _dataChannel = channel;
        _setupDataChannel(channel);
        _dataChannelController.add(channel);
      };

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('初始化WebRTC失败: $e');
      }
      rethrow;
    }
  }

  /// 设置DataChannel
  void _setupDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (kDebugMode) {
        print('DataChannel状态: $state');
      }
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannelController.add(channel);
      }
    };
  }

  /// 获取DataChannel
  RTCDataChannel? get dataChannel => _dataChannel;

  /// 处理信令消息
  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    if (_peerConnection == null) {
      return;
    }

    try {
      switch (message.type) {
        case SignalingMessageType.offer:
          await _handleOffer(message.data!);
          break;
        case SignalingMessageType.answer:
          await _handleAnswer(message.data!);
          break;
        case SignalingMessageType.iceCandidate:
          await _handleIceCandidate(message.data!);
          break;
        default:
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('处理信令消息失败: $e');
      }
    }
  }

  /// 处理Offer
  Future<void> _handleOffer(Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String;
    final type = data['type'] as String;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // 尝试客户端模式发送，失败则尝试服务器模式
    try {
      await _signalingService.sendMessage(
        SignalingMessage(
          type: SignalingMessageType.answer,
          data: {
            'sdp': answer.sdp,
            'type': answer.type,
          },
        ),
      );
    } catch (e) {
      // 如果是服务器模式，使用sendMessageToClient
      try {
        await _signalingService.sendMessageToClient(
          SignalingMessage(
            type: SignalingMessageType.answer,
            data: {
              'sdp': answer.sdp,
              'type': answer.type,
            },
          ),
        );
      } catch (e2) {
        if (kDebugMode) {
          print('发送Answer失败: $e2');
        }
      }
    }
  }

  /// 处理Answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String;
    final type = data['type'] as String;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
  }

  /// 处理ICE候选
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );
    await _peerConnection!.addCandidate(candidate);
  }

  /// 创建Offer并发送
  Future<void> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection未初始化');
    }

    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _signalingService.sendMessage(
        SignalingMessage(
          type: SignalingMessageType.offer,
          data: {
            'sdp': offer.sdp,
            'type': offer.type,
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('创建Offer失败: $e');
      }
      rethrow;
    }
  }

  /// 连接到信令服务器
  Future<void> connectToSignaling(String host, int port) async {
    await _signalingService.connectToServer(host, port);
  }

  /// 启动信令服务器
  Future<void> startSignalingServer(int port) async {
    await _signalingService.startServer(port);
  }

  /// 获取本地流（用于屏幕共享，这里简化处理）
  Future<MediaStream?> getLocalStream() async {
    try {
      // 注意：实际屏幕共享需要更复杂的配置
      // 这里返回null，表示暂时不支持屏幕共享
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('获取本地流失败: $e');
      }
      return null;
    }
  }

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 断开连接
  Future<void> disconnect() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await _signalingService.disconnect();
    _isConnected = false;
  }

  /// 清理资源
  Future<void> dispose() async {
    await disconnect();
    await _signalingService.dispose();
    await _remoteStreamController.close();
    await _dataChannelController.close();
    _dataChannel = null;
  }
}
