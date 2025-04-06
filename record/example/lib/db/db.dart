import 'package:record_example/db/account.dart';
import 'package:record_example/db/favour_sentence.dart';
import 'package:record_example/db/star.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Db {
  static Database? _database;

  // 获取数据库实例
  static Future<Database> get database async {
    if (_database == null) {
      throw Exception("Database has not been initialized. Call Db.init() first.");
    }
    return _database!;
  }

  // 初始化数据库
  static Future<void> init() async {
    // 如果是桌面环境，确保初始化 FFI 工厂
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    String path = join(await getDatabasesPath(), 'app.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    await _initData();
  }

  static Future<void> _initData() async {
    await AccountMapper.init();
  }

  // 创建数据库表
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(FavourSentenceMapper.getCreateTableSql());
    await db.execute(AccountMapper.getCreateTableSql());
    await db.execute(StarMapper.getCreateTableSql());
  }

  // 执行查询（带参数）
  static Future<List<Map<String, dynamic>>> query(String sql, List<Object> params) async {
    final db = await database;
    return await db.rawQuery(sql, params);
  }

  // 执行SQL语句（带参数，如INSERT, UPDATE, DELETE）
  static Future<int> execute(String sql, List<Object> params) async {
    final db = await database;
    return await db.rawInsert(sql, params);
  }

  // 关闭数据库
  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
