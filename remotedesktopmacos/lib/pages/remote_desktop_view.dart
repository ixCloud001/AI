import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/app_theme.dart';
import '../services/webrtc_manager.dart';
import '../services/clipboard_sync_service.dart';

/// 远程桌面视口页面
/// 全屏显示，底部有悬浮条
class RemoteDesktopView extends StatefulWidget {
  final String targetIp;
  final MediaStream? remoteStream;
  final WebRTCManager? webrtcManager;

  const RemoteDesktopView({
    super.key,
    required this.targetIp,
    this.remoteStream,
    this.webrtcManager,
  });

  @override
  State<RemoteDesktopView> createState() => _RemoteDesktopViewState();
}

class _RemoteDesktopViewState extends State<RemoteDesktopView> {
  RTCVideoRenderer? _remoteRenderer;
  ClipboardSyncService? _clipboardSyncService;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    // 设置为全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _remoteRenderer?.dispose();
    _clipboardSyncService?.dispose();
    // 注意：webrtcManager 由 remote_assist_page 管理，这里不需要 dispose
    super.dispose();
  }

  /// 初始化视频渲染器
  Future<void> _initRenderer() async {
    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();

    if (widget.remoteStream != null) {
      _remoteRenderer!.srcObject = widget.remoteStream;
    }

    // 初始化剪贴板同步（如果是macOS端作为被控端）
    if (widget.webrtcManager != null) {
      _initClipboardSync();
    }

    setState(() {});
  }

  /// 初始化剪贴板同步
  Future<void> _initClipboardSync() async {
    try {
      // 等待DataChannel建立
      final dataChannel = widget.webrtcManager!.dataChannel;
      if (dataChannel != null) {
        _clipboardSyncService = ClipboardSyncService();
        
        // macOS端作为被控端，不主动监听剪贴板变化，只接收远程数据
        await _clipboardSyncService!.enable(
          dataChannel: dataChannel,
          isController: false, // macOS是被控端
        );
      } else {
        // 监听DataChannel创建
        final subscription = widget.webrtcManager!.dataChannelStream.listen((channel) {
          _clipboardSyncService = ClipboardSyncService();
          _clipboardSyncService!.enable(
            dataChannel: channel,
            isController: false,
          );
        });
        
        // 在dispose中取消订阅
        Future.delayed(const Duration(seconds: 30), () {
          subscription.cancel();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('初始化剪贴板同步失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远程桌面视图
          _buildRemoteDesktopView(),
          // 底部悬浮条
          _buildFloatingBar(),
        ],
      ),
    );
  }

  /// 构建远程桌面视图
  Widget _buildRemoteDesktopView() {
    if (_remoteRenderer == null || widget.remoteStream == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
            SizedBox(height: 16),
            Text(
              '正在连接远程桌面...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: RTCVideoView(
        _remoteRenderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }

  /// 构建底部悬浮条
  Widget _buildFloatingBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧：控制信息
            Row(
              children: [
                const Icon(
                  Icons.desktop_windows,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '正在控制：${widget.targetIp}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // 右侧：关闭按钮
            IconButton(
              icon: const Icon(
                Icons.close,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              tooltip: '断开连接',
            ),
          ],
        ),
      ),
    );
  }
}
