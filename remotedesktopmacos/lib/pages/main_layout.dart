import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主布局页面
/// 仿向日葵风格的深色 UI
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final TextEditingController _partnerIpController = TextEditingController();

  @override
  void dispose() {
    _partnerIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 主背景色
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：固定宽度侧边栏
          _buildSidebar(),
          // 右侧：主内容区
          Expanded(
            child: _buildContentArea(),
          ),
        ],
      ),
    );
  }

  /// 构建侧边栏
  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFF1E1E1E), // 侧边栏颜色
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildNavItem(
            icon: Icons.computer,
            label: '远程协助',
            index: 0,
            isSelected: _selectedIndex == 0,
          ),
          _buildNavItem(
            icon: Icons.devices,
            label: '设备',
            index: 1,
            isSelected: _selectedIndex == 1,
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: '设置',
            index: 2,
            isSelected: _selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  /// 构建导航项
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    final textColor = isSelected ? const Color(0xFFFF4D4D) : Colors.grey;
    final bgColor = isSelected
        ? const Color(0xFFFF4D4D).withValues(alpha: 0.1)
        : Colors.transparent;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: textColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建主内容区
  Widget _buildContentArea() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 顶部模块：远程协助本机
        _buildLocalRemoteSection(),
        const SizedBox(height: 32),
        // 中部模块：远程协助他人
        _buildRemoteOthersSection(),
      ],
    );
  }

  /// 构建"远程协助本机"模块
  Widget _buildLocalRemoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '远程协助本机',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // IP 地址显示（带复制图标）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              '192.168.1.100',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.copy,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: '192.168.1.100'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('IP 地址已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: '复制 IP 地址',
            ),
          ],
        ),
      ],
    );
  }

  /// 构建"远程协助他人"模块
  Widget _buildRemoteOthersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '远程协助他人',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // 输入框和连接按钮
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _partnerIpController,
                decoration: InputDecoration(
                  hintText: '请输入伙伴 IP',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A3A4E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1890FF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                // 连接逻辑
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1890FF), // 蓝色
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
    );
  }
}
