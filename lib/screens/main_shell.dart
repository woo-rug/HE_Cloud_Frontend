import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';
import 'cloud_browser_screen.dart';
import 'search_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // 화면 리스트
  final List<Widget> _screens = [
    const HomeScreen(),
    const CloudBrowserScreen(),
    const SearchScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // 드로어 닫기
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authState = provider.authState;
    final userEmail = provider.userEmail;

    // 로그인 안 되어 있으면 로그인 화면으로
    if (authState != AuthState.loggedIn) {
      return const LoginScreen();
    }

    return Scaffold(
      // [수정] AppBar 색상을 사이드바와 통일하고 제목 크기 키움
      appBar: AppBar(
        backgroundColor: Colors.indigo, // 사이드바 포인트 색상과 일치
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "HE Cloud",
          style: TextStyle(
            fontSize: 28, // [수정] 폰트 크기 키움
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              context.read<AppProvider>().logout();
            },
          ),
        ],
      ),
      // 사이드바 (Drawer)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // [수정] 드로어 헤더도 동일한 색상 적용
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Colors.indigo, // AppBar와 색상 통일
              ),
              accountName: Text(
                userEmail,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text("보안 연결됨"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.shield, size: 40, color: Colors.indigo),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('홈'),
              selected: _selectedIndex == 0,
              selectedColor: Colors.indigo,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('클라우드 탐색기'),
              selected: _selectedIndex == 1,
              selectedColor: Colors.indigo,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('보안 검색'),
              selected: _selectedIndex == 2,
              selectedColor: Colors.indigo,
              onTap: () => _onItemTapped(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () {
                // 설정 화면 이동 (추후 구현)
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}
