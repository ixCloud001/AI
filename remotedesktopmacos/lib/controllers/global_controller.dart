import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// 全局控制器
/// 管理应用全局状态，如本机IP地址
class GlobalController extends ChangeNotifier {
  /// NetworkInfo实例
  final NetworkInfo _networkInfo = NetworkInfo();

  /// 本机IP地址（默认值为 127.0.0.1，直到获取到真实 IP）
  String? _localIpAddress = '127.0.0.1';

  /// 是否正在获取IP
  bool _isLoadingIP = false;

  /// 是否已联网
  bool _isNetworkConnected = false;

  /// 获取本机IP地址
  String? get localIpAddress => _localIpAddress;

  /// 获取IP显示文本（如果未联网显示"未连接网络"）
  String get localIpDisplayText {
    if (_isLoadingIP) {
      return '正在获取...';
    }
    if (!_isNetworkConnected || _localIpAddress == null) {
      return '未连接网络';
    }
    return _localIpAddress!;
  }

  /// 是否正在加载
  bool get isLoadingIP => _isLoadingIP;

  /// 是否已联网
  bool get isNetworkConnected => _isNetworkConnected;

  /// 初始化并获取IP地址
  Future<void> initialize() async {
    await fetchLocalIPAddress();
  }

  /// 获取本机局域网IP地址
  Future<void> fetchLocalIPAddress() async {
    if (_isLoadingIP) {
      return;
    }

    _isLoadingIP = true;
    notifyListeners();

    try {
      // 方法1：尝试使用 network_info_plus 获取 WiFi IP
      String? ipAddress = await _networkInfo.getWifiIP();

      // 方法2：如果方法1失败，遍历系统网络接口获取局域网 IP
      if (ipAddress.isEmpty ||
          ipAddress == '0.0.0.0' ||
          ipAddress == '127.0.0.1') {
        ipAddress = await _getLocalNetworkIP();
      }

      // 验证IP地址有效性
      if (ipAddress == null ||
          ipAddress.isEmpty ||
          ipAddress == '0.0.0.0' ||
          ipAddress == '127.0.0.1') {
        // 获取失败，未联网，保持默认值
        _localIpAddress = '127.0.0.1';
        _isNetworkConnected = false;
      } else {
        // 获取成功
        _localIpAddress = ipAddress;
        _isNetworkConnected = true;
      }
    } catch (e) {
      // 获取IP失败，保持默认值，确保应用能正常运行
      _localIpAddress = '127.0.0.1';
      _isNetworkConnected = false;
      if (kDebugMode) {
        print('获取IP地址失败: $e');
      }
    } finally {
      _isLoadingIP = false;
      notifyListeners();
    }
  }

  /// 遍历系统网络接口，获取局域网 IPv4 地址（192.168. 或 10. 开头）
  Future<String?> _getLocalNetworkIP() async {
    try {
      // 获取所有网络接口
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      // 遍历接口，查找局域网 IP
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          
          // 检查是否为局域网 IP（192.168.x.x 或 10.x.x.x）
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            if (kDebugMode) {
              print('找到局域网 IP: $ip (接口: ${interface.name})');
            }
            return ip;
          }
        }
      }

      // 如果没找到 192.168. 或 10. 开头的，尝试找其他非回环地址
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          
          // 排除回环地址和无效地址
          if (ip != '127.0.0.1' && 
              ip != '0.0.0.0' && 
              !ip.startsWith('169.254.')) { // 排除 APIPA 地址
            if (kDebugMode) {
              print('找到备用 IP: $ip (接口: ${interface.name})');
            }
            return ip;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('遍历网络接口失败: $e');
      }
    }

    return null;
  }

  /// 刷新IP地址
  Future<void> refreshIP() async {
    await fetchLocalIPAddress();
  }
}

