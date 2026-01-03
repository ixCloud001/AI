import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/app_theme.dart';
import '../services/webrtc_manager.dart';
import '../utils/ip_parser.dart';

/// 远程桌面页面
/// 显示连接状态和远程桌面视图
class RemoteDesktopPage extends StatefulWidget {
  final String targetIp;
  final int targetPort;

  const RemoteDesktopPage({
    super.key,
    required this.targetIp,
    required this.targetPort,
  });

  @override
  State<RemoteDesktopPage> createState() => _RemoteDesktopPageState();
}

class _RemoteDesktopPageState extends State<RemoteDesktopPage> {
  WebRTCManager? _webrtcManager;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _remoteStream;
  bool _isConnecting = true;
  String? _connectionError;
  Timer? _mouseTimer;
  bool _isBottomBarVisible = true;

  @override
  void initState() {
    super.initState();
    // 设置为全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initConnection();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _mouseTimer?.cancel();
    _remoteRenderer?.dispose();
    _webrtcManager?.dispose();
    super.dispose();
  }

  /// 初始化连接
  Future<void> _initConnection() async {
    try {
      // 创建WebRTC管理器
      _webrtcManager = WebRTCManager();

      // 初始化WebRTC（作为连接方，需要创建Offer）
      await _webrtcManager!.initialize(isOffer: true);

      // 连接到信令服务器
      await _webrtcManager!.connectToSignaling(widget.targetIp, widget.targetPort);

      // 创建Offer
      await _webrtcManager!.createOffer();

      // 等待连接建立（最多等待10秒）
      bool streamReceived = false;
      
      final subscription = _webrtcManager!.remoteStream.listen((stream) {
        _remoteStream = stream;
        streamReceived = true;
        _initRenderer();
      });

      // 等待远程流建立，最多等待10秒
      int attempts = 0;
      const maxAttempts = 20; // 20 * 500ms = 10秒
      while (!streamReceived && attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      await subscription.cancel();

      if (!mounted) return;

      if (!streamReceived || _remoteStream == null) {
        throw Exception('连接超时：未能接收到远程流');
      }

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });
    }
  }

  /// 初始化视频渲染器
  Future<void> _initRenderer() async {
    if (_remoteStream == null) return;

    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    _remoteRenderer!.srcObject = _remoteStream;

    if (mounted) {
      setState(() {});
    }
  }

  /// 处理鼠标移动，显示底栏
  void _handleMouseMove() {
    if (!_isBottomBarVisible) {
      setState(() {
        _isBottomBarVisible = true;
      });
    }

    // 重置定时器
    _mouseTimer?.cancel();
    _mouseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isBottomBarVisible = false;
        });
      }
    });
  }

  /// 结束连接
  void _handleDisconnect() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _handleMouseMove(),
        onExit: (_) => _handleMouseMove(),
        child: Stack(
          children: [
            // 远程桌面视图或连接状态
            _buildContent(),
            // 底部悬浮条
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    if (_isConnecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              '正在尝试连接 ${IpParser.formatIpAndPort(widget.targetIp, widget.targetPort)}...',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_connectionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '连接失败',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _connectionError!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleDisconnect,
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    if (_remoteRenderer == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
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
  Widget _buildBottomBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _isBottomBarVisible ? 0 : -50,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '当前控制：${IpParser.formatIpAndPort(widget.targetIp, widget.targetPort)}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // 右侧：结束连接按钮
                TextButton(
                  onPressed: _handleDisconnect,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 18),
                      SizedBox(width: 4),
                      Text('结束连接'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

