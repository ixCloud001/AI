import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/ip_parser.dart';
import 'remote_desktop_page.dart';
// 暂时注释掉 globalController 的导入，因为它在 main.dart 中被注释掉了
// import '../main.dart';

/// 远程协助页面
/// 包含"远程协助本机"和"远程协助他人"两部分
class RemoteAssistPage extends StatefulWidget {
  const RemoteAssistPage({super.key});

  @override
  State<RemoteAssistPage> createState() => _RemoteAssistPageState();
}

class _RemoteAssistPageState extends State<RemoteAssistPage> {
  /// 本机识别码开关状态
  bool _isRemoteEnabled = false;

  /// 伙伴IP输入框控制器
  final TextEditingController _partnerIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 暂时注释掉 GlobalController 相关代码
    // // 监听GlobalController的变化
    // globalController.addListener(_onGlobalControllerChanged);
    // 
    // // 使用 Future.microtask 异步触发 IP 初始化，不阻塞 UI 渲染
    // Future.microtask(() {
    //   globalController.initialize().catchError((error) {
    //     // 如果初始化失败，设置默认值，确保应用能正常启动
    //     if (kDebugMode) {
    //       print('IP 初始化失败，使用默认值: $error');
    //     }
    //   });
    // });
  }

  @override
  void dispose() {
    _partnerIpController.dispose();
    // 暂时注释掉 GlobalController 相关代码
    // globalController.removeListener(_onGlobalControllerChanged);
    super.dispose();
  }

  /// GlobalController变化回调
  // void _onGlobalControllerChanged() {
  //   if (mounted) {
  //     setState(() {});
  //   }
  // }

  /// 处理连接按钮点击
  Future<void> _handleConnect() async {
    final input = _partnerIpController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入伙伴识别码'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 解析IP地址和端口
    String ip;
    int port;
    try {
      final parsed = IpParser.parseIpAndPort(input);
      ip = parsed.ip;
      port = parsed.port;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('识别码格式错误: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 跳转到远程桌面页面（页面内部处理连接逻辑）
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RemoteDesktopPage(
          targetIp: ip,
          targetPort: port,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212), // 更深的黑色背景
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模块A：远程协助本机
          _buildLocalRemoteSection(),
          // 模块B：远程协助他人
          _buildRemoteOthersSection(),
        ],
      ),
    );
  }

  /// 构建"远程协助本机"模块
  /// 左侧是大字号的本机 IP，右侧是一个开关按钮
  Widget _buildLocalRemoteSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // 左侧：大字号本机 IP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '远程协助本机',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                  // 大字号 IP 显示（暂时硬编码）
                const Text(
                  '127.0.0.1',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                // 暂时注释掉加载指示器
                // if (globalController.isLoadingIP)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧：开关按钮
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '开启远程协助',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Switch(
                value: _isRemoteEnabled,
                onChanged: (value) {
                  setState(() {
                    _isRemoteEnabled = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建"远程协助他人"模块
  /// 包含一个深灰色的圆角输入框和一个蓝色连接按钮
  Widget _buildRemoteOthersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '远程协助他人',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // 输入框和连接按钮
          Row(
            children: [
              // 深灰色圆角输入框
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A), // 深灰色
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _partnerIpController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: '请输入伙伴识别码',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 蓝色连接按钮
              ElevatedButton(
                onPressed: _handleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('连接'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
