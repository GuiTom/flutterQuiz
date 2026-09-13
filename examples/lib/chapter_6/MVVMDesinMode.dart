import 'package:flutter/material.dart';

// ==========================================
// 1. Model (模型层)
// ==========================================
class User {
  final String name;
  final int age;
  final String avatar;

  User({required this.name, required this.age, required this.avatar});
}

// 模拟 API 数据源
class UserService {
  Future<User> fetchUserData() async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(seconds: 1));
    return User(
      name: "Flutter Expert",
      age: 8,
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=Flutter",
    );
  }
}

// ==========================================
// 2. ViewModel (视图模型层)
// ==========================================
class UserViewModel extends ChangeNotifier {
  final UserService _service = UserService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // 暴露给 View 的只读数据
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 业务逻辑方法：获取用户数据
  Future<void> loadUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // 通知 View 正在加载中

    try {
      _user = await _service.fetchUserData();
    } catch (e) {
      _errorMessage = "数据加载失败: $e";
    } finally {
      _isLoading = false;
      notifyListeners(); // 通知 View 加载完成
    }
  }

  // 业务逻辑方法：修改本地用户名
  void updateUserName(String newName) {
    if (_user != null) {
      _user = User(
        name: newName,
        age: _user!.age,
        avatar: _user!.avatar,
      );
      notifyListeners(); // 即使是同步修改也要通知 UI
    }
  }
}

// ==========================================
// 3. View (视图层)
// ==========================================
class MVVMDesignModePage extends StatefulWidget {
  const MVVMDesignModePage({super.key});

  @override
  State<MVVMDesignModePage> createState() => _MVVMDesignModePageState();
}

class _MVVMDesignModePageState extends State<MVVMDesignModePage> {
  // 简单起见，这里直接持有 ViewModel 实例。
  // 在复杂应用中，通常会结合 Provider, Riverpod 或 GetIt 使用单例。
  final UserViewModel _viewModel = UserViewModel();

  @override
  void initState() {
    super.initState();
    // 初始化时加载数据
    _viewModel.loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MVVM 设计模式'),
      ),
      // ListenableBuilder 是 Flutter 3.10 引入的现代组件，用于监听 Listenable
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          // 根据 ViewModel 的状态分发渲染逻辑
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_viewModel.errorMessage!),
                  ElevatedButton(
                    onPressed: () => _viewModel.loadUser(),
                    child: const Text("重试"),
                  ),
                ],
              ),
            );
          }

          final user = _viewModel.user;
          if (user == null) {
            return const Center(child: Text("暂无用户信息"));
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, size: 60),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(label: "姓名", value: user.name),
                  _InfoRow(label: "年龄", value: "${user.age} 岁"),
                  const SizedBox(height: 48),
                  
                  // 发送 Command 给 ViewModel
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("重新请求 API"),
                      onPressed: () => _viewModel.loadUser(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text("本地更新名称"),
                      onPressed: () {
                        _viewModel.updateUserName("MVVM 达人 ${DateTime.now().second}");
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 辅助小组件：展示信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(value, style: const TextStyle(fontSize: 18, color: Colors.blue)),
        ],
      ),
    );
  }
}
