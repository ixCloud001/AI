/// IP地址和端口解析工具
class IpParser {
  /// 默认端口
  static const int defaultPort = 8888;

  /// 解析IP地址和端口
  /// 支持格式：
  /// - "192.168.1.5" -> (192.168.1.5, 8888)
  /// - "192.168.1.5:8080" -> (192.168.1.5, 8080)
  /// - "192.168.1.5:" -> (192.168.1.5, 8888)
  static ({String ip, int port}) parseIpAndPort(String input) {
    final trimmed = input.trim();
    
    // 检查是否包含端口
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length == 2) {
        final ip = parts[0].trim();
        final portStr = parts[1].trim();
        
        // 验证IP格式
        if (!_isValidIp(ip)) {
          throw FormatException('无效的IP地址格式: $ip');
        }
        
        // 解析端口
        int port = defaultPort;
        if (portStr.isNotEmpty) {
          port = int.tryParse(portStr) ?? defaultPort;
          if (port < 1 || port > 65535) {
            throw FormatException('端口号必须在1-65535之间: $portStr');
          }
        }
        
        return (ip: ip, port: port);
      } else {
        throw FormatException('无效的IP:端口格式: $trimmed');
      }
    } else {
      // 只有IP地址，使用默认端口
      if (!_isValidIp(trimmed)) {
        throw FormatException('无效的IP地址格式: $trimmed');
      }
      return (ip: trimmed, port: defaultPort);
    }
  }

  /// 验证IP地址格式
  static bool _isValidIp(String ip) {
    if (ip.isEmpty) return false;
    
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  /// 格式化IP和端口为显示字符串
  static String formatIpAndPort(String ip, int port) {
    if (port == defaultPort) {
      return ip;
    }
    return '$ip:$port';
  }
}




