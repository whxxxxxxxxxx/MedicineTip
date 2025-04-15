import 'package:flutter/material.dart';
import 'package:medicinetip/services/ai_service.dart';
import 'package:medicinetip/services/storage_service.dart';
import 'services/reminder_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/add_reminder_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/reminder_detail_screen.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  await storageService.init();
  
  final reminderService = ReminderService(
    storageService: storageService,
  );
  reminderService.init(); // 初始化 ReminderServic
  
  await reminderService.loadData();
  
  runApp(MyApp(
    reminderService: reminderService,
  ));
}

class MyApp extends StatelessWidget {
  final ReminderService reminderService;

  const MyApp({
    super.key,
    required this.reminderService,
  });

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: '用药提醒',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: MyHomePage(
        reminderService: reminderService,
      ),
      routes: {
        AppConstants.addReminderRoute: (context) => AddReminderScreen(
          aiService: AIService(),
          reminderService: reminderService,
        ),
        AppConstants.historyRoute: (context) => HistoryScreen(
          reminderService: reminderService,
        ),
        AppConstants.settingsRoute: (context) => SettingsScreen(
          reminderService: reminderService,
        ),
        AppConstants.reminderDetailRoute: (context) => ReminderDetailScreen(
          reminderId: ModalRoute.of(context)!.settings.arguments as String,
          reminderService: reminderService,
        ),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final ReminderService reminderService;

  const MyHomePage({
    super.key,
    required this.reminderService,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = HomeScreen(reminderService: widget.reminderService);
        break;
      case 1:
        page = AddReminderScreen(
          aiService: AIService(),
          reminderService: widget.reminderService,
        );
        break;
      case 2:
        page = HistoryScreen(reminderService: widget.reminderService);
        break;
      case 3:
        page = SettingsScreen(
          reminderService: widget.reminderService,
        );
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  backgroundColor: theme.colorScheme.primary.withAlpha(25),
                  selectedIconTheme: IconThemeData(
                    color: theme.colorScheme.primary,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  extended: constraints.maxWidth >= 600,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('首页'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add),
                      label: Text('添加提醒'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text('历史记录'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: theme.colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
