// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plant_fit/action/edit_history_page.dart';
import 'package:plant_fit/notification/notification_service.dart';
import 'package:plant_fit/view/calendar_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '植物浇水提醒',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
      supportedLocales: [
        const Locale('zh', 'CH'),
        const Locale('en', 'US'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: 
        (List<Locale>? locales, Iterable<Locale> supportedLocales) {return const Locale('zh');},
    );
  }
}

// 植物模型
class Plant {
  String plantId;
  String name;
  String imageUrl;
  String description;
  int waterCycle;
  DateTime lastWaterDate;

  Plant({
    required this.plantId,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.waterCycle,
    required this.lastWaterDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'plantId': plantId,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'waterCycle': waterCycle,
      'lastWaterDate': lastWaterDate.toIso8601String(),
    };
  }

  factory Plant.fromMap(Map<dynamic, dynamic> map) {
    return Plant(
      plantId: map['plantId'],
      name: map['name'],
      imageUrl: map['imageUrl'],
      description: map['description'],
      waterCycle: map['waterCycle'],
      lastWaterDate: DateTime.parse(map['lastWaterDate']),
    );
  }
}

// 浇水历史记录模型
class WaterHistory {
  String plantId;
  DateTime waterDate;
  String notes;
  String imagePath; // 新增图片路径字段

  WaterHistory({
    required this.plantId,
    required this.waterDate,
    this.notes = '',
    this.imagePath = '', // 初始化
  });

  Map<String, dynamic> toMap() {
    return {
      'plantId': plantId,
      'waterDate': waterDate.toIso8601String(),
      'notes': notes,
      'imagePath': imagePath, // 新增
    };
  }

  factory WaterHistory.fromMap(Map<dynamic, dynamic> map) {
    return WaterHistory(
      plantId: map['plantId'],
      waterDate: DateTime.parse(map['waterDate']),
      notes: map['notes'],
      imagePath: map['imagePath'] ?? '', // 新增
    );
  }
}

// 数据库帮助类
class DatabaseHelper {
  
  Future<Database> get db async {
    return await initDb();
  }

  initDb() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // String databasesPath = await getDatabasesPath();
    String path = join(documentsDirectory.path, 'plants.db');
    
    var db = await openDatabase(path, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
    return db;
  }

  void _onCreate(Database db, int newVersion) async {
    // 创建植物表
    await db.execute('''
      CREATE TABLE plants(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plantId TEXT,
        name TEXT,
        imageUrl TEXT,
        description TEXT,
        waterCycle INTEGER,
        lastWaterDate TEXT
      )
    ''');

    // 创建浇水历史表
    await db.execute('''
      CREATE TABLE water_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plantId INTEGER,
        waterDate TEXT,
        notes TEXT,
        FOREIGN KEY (plantId) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE water_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plantId INTEGER,
          waterDate TEXT,
          notes TEXT,
          FOREIGN KEY (plantId) REFERENCES plants (id) ON DELETE CASCADE
        )
      ''');
    }
    
    if (newVersion >= 3) {
      await db.execute('''
        ALTER TABLE water_history ADD COLUMN imagePath TEXT;
      ''');
    }
  }

  Future<int> insertPlant(Plant plant) async {
    var dbClient = await db;
    return await dbClient.insert('plants', plant.toMap());
  }

  Future<List<Plant>> getPlants() async {
    var dbClient = await db;
    List<Map> maps = await dbClient.query('plants', columns: [
      'plantId', 'name', 'imageUrl', 'description', 'waterCycle', 'lastWaterDate'
    ]);
    
    return maps.map((map) => Plant.fromMap(map)).toList();
  }

  Future<int> updatePlant(Plant plant) async {
    var dbClient = await db;
    return await dbClient.update(
      'plants',
      plant.toMap(),
      where: 'plantId = ?',
      whereArgs: [plant.plantId],
    );
  }

  Future<int> deletePlant(String plantId) async {
    var dbClient = await db;
    // 先删除相关的浇水历史记录
    await dbClient.delete(
      'water_history',
      where: 'plantId = ?',
      whereArgs: [plantId],
    );

    // 再删除植物
    return await dbClient.delete(
      'plants',
      where: 'plantId = ?',
      whereArgs: [plantId],
    );
  }

  // 浇水历史记录相关方法
  Future<int> insertWaterHistory(WaterHistory history) async {
    var dbClient = await db;
    return await dbClient.insert('water_history', history.toMap());
  }

  Future<List<WaterHistory>> getWaterHistory(String plantId) async {
    var dbClient = await db;
    List<Map> maps = await dbClient.query(
      'water_history',
      columns: ['id', 'plantId', 'waterDate', 'notes', 'imagePath'],
      where: 'plantId = ?',
      whereArgs: [plantId],
      orderBy: 'waterDate DESC',
    );
    return maps.map((map) => WaterHistory.fromMap(map)).toList();
  }

  Future<List<WaterHistory>> getWaterHistoryAll() async {
    var dbClient = await db;
    List<Map> maps = await dbClient.query(
      'water_history',
      columns: ['id', 'plantId', 'waterDate', 'notes', 'imagePath'],
    );
    return maps.map((map) => WaterHistory.fromMap(map)).toList();
  }

  Future<int> deleteWaterHistory(String id) async {
    var dbClient = await db;
    return await dbClient.delete(
      'water_history',
      where: 'plantId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateWaterHistory(WaterHistory history) async {
  var dbClient = await db;
  return await dbClient.update(
    'water_history',
    history.toMap(),
    where: 'plantId = ?',
    whereArgs: [history.plantId],
  );
}
}

// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Plant> plants = [];
  List<WaterHistory> waterHistory = [];
  DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _loadWaterHistory();
  }

  _loadPlants() async {
    List<Plant> plantList = await dbHelper.getPlants();
    setState(() {
      plants = plantList;
    });
  }

  _loadWaterHistory() async {
    List<WaterHistory> history = await dbHelper.getWaterHistoryAll();
    setState(() {
      waterHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的植物'),
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () {
                // 需要先获取所有浇水记录
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CalendarPage(
                      waterHistory: waterHistory, // 这里需要传递所有浇水记录
                    ),
                  ),
                );
              },
            ),
          ],
      ),
      body: plants.isEmpty
          ? Center(
              child: Text(
                '还没有添加植物\n点击下方+号添加',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: plants.length,
              itemBuilder: (context, index) {
                final plant = plants[index];
                final daysLeft = plant.lastWaterDate
                    .add(Duration(days: plant.waterCycle))
                    .difference(DateTime.now())
                    .inDays;
                
                return Dismissible(
                  key: Key(plant.plantId.toString()),
                  background: Container(color: Colors.red),
                  onDismissed: (direction) async {
                    await dbHelper.deletePlant(plant.plantId);
                    setState(() {
                      plants.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已删除${plant.name}')),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.local_florist, color: Colors.green),
                      ),
                      title: Text(plant.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('浇水周期: ${plant.waterCycle}天'),
                          Text('上次浇水: ${_formatDate(plant.lastWaterDate)}'),
                          Text(
                            '剩余天数: $daysLeft天',
                            style: TextStyle(
                              color: daysLeft <= 2 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showPlantDetail(context, plant),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _addPlant(context),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  _addPlant(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPlantPage()),
    ).then((value) {
      if (value == true) _loadPlants();
    });
  }

  _showPlantDetail(BuildContext context, Plant plant) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailPage(plant: plant),
      ),
    );
    
    if (result == true) _loadPlants();
  }
}

// 添加植物页面
class AddPlantPage extends StatefulWidget {
  const AddPlantPage({super.key});

  @override
  _AddPlantPageState createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final List<Plant> plantDatabase = [
    Plant(
      plantId: Uuid().v4(),
      name: '绿萝',
      imageUrl: '',
      description: '喜阴植物，适合室内种植',
      waterCycle: 7,
      lastWaterDate: DateTime.now()
    ),
    Plant(
      plantId: Uuid().v4(),
      name: '仙人掌',
      imageUrl: '',
      description: '耐旱植物，需要少量水',
      waterCycle: 30,
      lastWaterDate: DateTime.now()
    ),
    Plant(
      plantId: Uuid().v4(),
      name: '玫瑰',
      imageUrl: '',
      description: '需要充足阳光',
      waterCycle: 3,
      lastWaterDate: DateTime.now()
    ),
    Plant(
      plantId: Uuid().v4(),
      name: '兰花',
      imageUrl: '',
      description: '需要适当湿度和通风',
      waterCycle: 5,
      lastWaterDate: DateTime.now(),
    ),
    Plant(
      plantId: Uuid().v4(),
      name: '多肉植物',
      imageUrl: '',
      description: '耐旱，需要良好排水',
      waterCycle: 14,
      lastWaterDate: DateTime.now()
    ),
  ];

  TextEditingController searchController = TextEditingController();
  List<Plant> filteredPlants = [];

  @override
  void initState() {
    super.initState();
    filteredPlants = plantDatabase;
    searchController.addListener(_filterPlants);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  _filterPlants() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredPlants = plantDatabase.where((plant) {
        return plant.name.toLowerCase().contains(query) ||
            plant.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('选择植物'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: '搜索植物',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredPlants.length,
              itemBuilder: (context, index) {
                final plant = filteredPlants[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.local_florist, color: Colors.green),
                  ),
                  title: Text(plant.name),
                  subtitle: Text(plant.description),
                  trailing: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => _addToMyPlants(context, plant),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _addToMyPlants(BuildContext context, Plant plant) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantEditPage(plant: plant, isEditing: false),
      ),
    );
    
    if (result == true) Navigator.pop(context, true);
  }
}

// 植物详情页面
class PlantDetailPage extends StatefulWidget {
  final Plant plant;

  const PlantDetailPage({super.key, required this.plant});

  @override
  _PlantDetailPageState createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<WaterHistory> waterHistory = [];
  TextEditingController notesController = TextEditingController();
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadWaterHistory();
  }

  _loadWaterHistory() async {
    List<WaterHistory> history = await dbHelper.getWaterHistory(widget.plant.plantId);
    setState(() {
      waterHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = widget.plant.lastWaterDate
        .add(Duration(days: widget.plant.waterCycle))
        .difference(DateTime.now())
        .inDays;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plant.name),
          actions: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editPlant(context),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info), text: '详情'),
              Tab(icon: Icon(Icons.history), text: '浇水记录'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 详情标签页
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      radius: 40,
                      child: Icon(Icons.local_florist, size: 40, color: Colors.green),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    widget.plant.name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(widget.plant.description),
                  SizedBox(height: 20),
                  Text('浇水周期: ${widget.plant.waterCycle}天'),
                  SizedBox(height: 10),
                  Text('上次浇水: ${_formatDate(widget.plant.lastWaterDate)}'),
                  SizedBox(height: 10),
                  Text(
                    '剩余天数: $daysLeft天',
                    style: TextStyle(
                      color: daysLeft <= 2 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SwitchListTile(
                    title: Text('开启浇水提醒'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                        });
                        if (value) {
                      // 计算下次浇水时间并设置提醒
                          final nextWatering = widget.plant.lastWaterDate.add(
                      Duration(days: widget.plant.waterCycle)
                      );
                    NotificationService().scheduleWateringReminder(
                      widget.plant.plantId.hashCode,
                          widget.plant.name,
                          nextWatering,
                              );
                          } else {
                      // 取消提醒
                          NotificationService().cancelReminder(widget.plant.plantId.hashCode);
                      }
                      },
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.water_drop),
                      label: Text('记录浇水'),
                      onPressed: () => _recordWatering(context),
                    ),
                  ),
                ],
              ),
            ),
            
            // 浇水记录标签页
            waterHistory.isEmpty
                ? Center(
                    child: Text(
                      '还没有浇水记录',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: waterHistory.length,
                    itemBuilder: (context, index) {
                      final history = waterHistory[index];
                      return ListTile(
                        leading: Icon(Icons.water_drop, color: Colors.blue),
                        title: Text(_formatDate(history.waterDate)),
                        subtitle: history.notes.isNotEmpty 
                            ? Text(history.notes) 
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _editHistory(history, context),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _deleteHistory(history.plantId),
                            ),
                          ]
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  _recordWatering(BuildContext context) async {
    // 显示对话框输入备注
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('记录浇水'),
          content: TextField(
            controller: notesController,
            decoration: InputDecoration(
              hintText: '输入备注（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('确认'),
              onPressed: () async {
                // 保存浇水记录
                WaterHistory newHistory = WaterHistory(
                  plantId: widget.plant.plantId,
                  waterDate: DateTime.now(),
                  notes: notesController.text,
                );
                
                await dbHelper.insertWaterHistory(newHistory);
                
                // 更新植物的上次浇水时间
                Plant updatedPlant = Plant(
                  plantId: widget.plant.plantId,
                  name: widget.plant.name,
                  imageUrl: widget.plant.imageUrl,
                  description: widget.plant.description,
                  waterCycle: widget.plant.waterCycle,
                  lastWaterDate: DateTime.now(),
                );
                
                await dbHelper.updatePlant(updatedPlant);
                
                // 重新加载数据
                _loadWaterHistory();
                notesController.clear();
                
                Navigator.of(context).pop();
                setState(() {}); // 刷新页面
              },
            ),
          ],
        );
      },
    );
  }

  // 添加编辑方法
_editHistory(WaterHistory history, BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditHistoryPage(
        history: history,
        onSave: (updatedHistory) async {
          await dbHelper.updateWaterHistory(updatedHistory);
          _loadWaterHistory();
        },
      ),
    ),
  );
}

  _deleteHistory(String historyId) async {
    await dbHelper.deleteWaterHistory(historyId);
    _loadWaterHistory(); // 重新加载历史记录
  }

  _editPlant(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantEditPage(plant: widget.plant, isEditing: true),
      ),
    );
    
    if (result == true) Navigator.pop(context, true);
  }
}

// 植物编辑页面
class PlantEditPage extends StatefulWidget {
  final Plant plant;
  final bool isEditing;

  const PlantEditPage({super.key, required this.plant, this.isEditing = false});

  @override
  _PlantEditPageState createState() => _PlantEditPageState();
}

class _PlantEditPageState extends State<PlantEditPage> {
  TextEditingController cycleController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      cycleController.text = widget.plant.waterCycle.toString();
      selectedDate = widget.plant.lastWaterDate;
    } else {
      cycleController.text = widget.plant.waterCycle.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑植物' : '添加植物'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                backgroundColor: Colors.green[100],
                radius: 40,
                child: Icon(Icons.local_florist, size: 40, color: Colors.green),
              ),
            ),
            SizedBox(height: 20),
            Text(
              widget.plant.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(widget.plant.description),
            SizedBox(height: 20),
            TextField(
              controller: cycleController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '浇水周期（天）',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text('上次浇水时间: '),
                Text(
                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                TextButton(
                  child: Text('选择日期'),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                child: Text(widget.isEditing ? '更新' : '添加'),
                onPressed: () => _savePlant(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  _savePlant(BuildContext context) async {
    final waterCycle = int.tryParse(cycleController.text) ?? 7;
    
    Plant plantToSave = Plant(
      plantId: widget.isEditing ? widget.plant.plantId : Uuid().v4(),
      name: widget.plant.name,
      imageUrl: widget.plant.imageUrl,
      description: widget.plant.description,
      waterCycle: waterCycle,
      lastWaterDate: selectedDate
    );

    if (widget.isEditing) {
      await dbHelper.updatePlant(plantToSave);
    } else {
      await dbHelper.insertPlant(plantToSave);
    }
    
    Navigator.pop(context, true);
  }
}