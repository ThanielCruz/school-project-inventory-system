import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class Item {
  int? id;
  String name;
  int onhand;
  int tally;
  String? imagePath;

  Item({this.id, required this.name, this.onhand = 0, this.tally = 0, this.imagePath});

  int get variance => onhand - tally;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'onhand': onhand, 'tally': tally, 'imagePath': imagePath};
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      onhand: map['onhand'],
      tally: map['tally'],
      imagePath: map['imagePath'],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown, // Coffee theme!
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Database? db;
  List<Item> items = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    initDB();
  }

  Future<void> initDB() async {
    final databasesPath = await getDatabasesPath();
    final path = "$databasesPath/coffee_inventory.db"; 
    db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, onhand INTEGER, tally INTEGER, imagePath TEXT)'
      ),
    );
    loadItems();
  }

  Future<void> loadItems() async {
    if (db == null) return;
    final maps = await db!.query('items');
    setState(() {
      items = maps.map((e) => Item.fromMap(e)).toList();
    });
  }

  Future<void> updateItem(Item item) async {
    await db!.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    loadItems();
  }

  Future<void> deleteItem(int id) async {
    await db!.delete('items', where: 'id = ?', whereArgs: [id]);
    loadItems();
  }

  Future<void> pickImage(Item item) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Quality 50 saves space
    if (image != null) {
      item.imagePath = image.path;
      updateItem(item);
    }
  }

  Future<void> manualEditDialog(Item item, String field) async {
    final controller = TextEditingController(text: field == "onhand" ? item.onhand.toString() : item.tally.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Set $field"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              field == "onhand" ? item.onhand = val : item.tally = val;
              updateItem(item);
              Navigator.pop(ctx);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  Future<void> addItemDialog() async {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        child: AlertDialog(
          title: const Text("Add New Item"),
          content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Item Name"), autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  await db!.insert('items', Item(name: nameCtrl.text).toMap());
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  loadItems();
                }
              },
              child: const Text("Add"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ADAPTIVE SIZING LOGIC
    double width = MediaQuery.of(context).size.width;
    bool isTablet = width > 600;

    double imgSize = isTablet ? 70 : 35;
    double fontSize = isTablet ? 18 : 12;
    double headerSize = isTablet ? 16 : 10;
    double iconSize = isTablet ? 28 : 20;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CAFE INVENTORY"), 
        centerTitle: true, 
        backgroundColor: Colors.brown[100]
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: addItemDialog,
              icon: Icon(Icons.add, size: iconSize),
              label: Text("ADD NEW ITEM", style: TextStyle(fontSize: fontSize)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[400], 
                foregroundColor: Colors.white, 
                minimumSize: Size(double.infinity, isTablet ? 60 : 45)
              ),
            ),
          ),
          // Adaptive Header
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(" PRODUCT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: headerSize))),
                Expanded(flex: 2, child: Center(child: Text("ONHAND", style: TextStyle(fontWeight: FontWeight.bold, fontSize: headerSize)))),
                Expanded(flex: 2, child: Center(child: Text("TALLY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: headerSize)))),
                Expanded(flex: 1, child: Center(child: Text("VAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: headerSize)))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // ITEM & IMAGE (Adaptive Size)
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[300], size: iconSize), 
                              onPressed: () => deleteItem(item.id!)
                            ),
                            GestureDetector(
                              onTap: () => pickImage(item),
                              child: Container(
                                width: imgSize, height: imgSize,
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                child: item.imagePath == null 
                                  ? Icon(Icons.camera_alt, size: imgSize/2, color: Colors.grey) 
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8), 
                                      child: Image.file(File(item.imagePath!), fit: BoxFit.cover)
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      // ONHAND
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            GestureDetector(
                              onLongPress: () => manualEditDialog(item, "onhand"),
                              child: Text("${item.onhand}", style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(onTap: () { item.onhand++; updateItem(item); }, child: Icon(Icons.add_box, color: Colors.green, size: iconSize + 4)),
                                const SizedBox(width: 8),
                                InkWell(onTap: () { if(item.onhand > 0) item.onhand--; updateItem(item); }, child: Icon(Icons.indeterminate_check_box, color: Colors.orange, size: iconSize + 4)),
                              ],
                            )
                          ],
                        ),
                      ),
                      // TALLY
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            GestureDetector(
                              onLongPress: () => manualEditDialog(item, "tally"),
                              child: Text("${item.tally}", style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(onTap: () { item.tally++; updateItem(item); }, child: Icon(Icons.add_box, color: Colors.green, size: iconSize + 4)),
                                const SizedBox(width: 8),
                                InkWell(onTap: () { if(item.tally > 0) item.tally--; updateItem(item); }, child: Icon(Icons.indeterminate_check_box, color: Colors.orange, size: iconSize + 4)),
                              ],
                            )
                          ],
                        ),
                      ),
                      // VARIANCE
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            "${item.variance}", 
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: item.variance < 0 ? Colors.red : Colors.brown[700])
                          )
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}