// ============================================================
// FORGE FITNESS TRACKER — Single-file Flutter App
// Stack: Flutter + Hive (local DB) + Provider (state)
// Theme: Quiet Luxury — Matte black, brushed copper, neutrals
// ============================================================
// pubspec.yaml dependencies needed:
//   hive: ^2.2.3
//   hive_flutter: ^1.1.0
//   provider: ^6.1.1
//   fl_chart: ^0.66.0
//   table_calendar: ^3.1.0
//   image_picker: ^1.0.7
//   path_provider: ^2.1.2
//   share_plus: ^7.2.1
//   intl: ^0.19.0
//   google_fonts: ^6.1.0
//   uuid: ^4.3.3
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

// ============================================================
// CONSTANTS & THEME
// ============================================================

const _copper = Color(0xFFB87333);
const _copperLight = Color(0xFFD4956A);
const _black = Color(0xFF0A0A0A);
const _surface = Color(0xFF141414);
const _card = Color(0xFF1C1C1C);
const _cardHigh = Color(0xFF242424);
const _textPrimary = Color(0xFFF0EDE8);
const _textSecondary = Color(0xFF8A8480);
const _divider = Color(0xFF2A2A2A);

ThemeData get appTheme => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      colorScheme: const ColorScheme.dark(
        primary: _copper,
        secondary: _copperLight,
        surface: _surface,
        onSurface: _textPrimary,
      ),
      textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.cormorantGaramond(
            color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 32),
        displayMedium: GoogleFonts.cormorantGaramond(
            color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 24),
        titleLarge: GoogleFonts.lato(
            color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: GoogleFonts.lato(
            color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
        bodyLarge: GoogleFonts.lato(color: _textPrimary, fontSize: 14),
        bodyMedium: GoogleFonts.lato(color: _textSecondary, fontSize: 13),
        labelSmall: GoogleFonts.lato(
            color: _textSecondary,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cormorantGaramond(
            color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w400),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _copper,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: _divider,
      cardColor: _card,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _copper, width: 1),
        ),
        labelStyle: GoogleFonts.lato(color: _textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.lato(color: _textSecondary, fontSize: 13),
      ),
    );

// ============================================================
// HIVE MODEL CONSTANTS
// ============================================================
const _exerciseBox = 'exercises';
const _workoutLogBox = 'workout_logs';
const _templateBox = 'templates';
const _profileBox = 'profile';
const _progressPhotoBox = 'progress_photos';

// ============================================================
// DATA MODELS (Plain Dart — Hive without codegen via Map)
// We store everything as Map<String,dynamic> in Hive for
// single-file simplicity (no build_runner needed).
// ============================================================

class Exercise {
  final String id;
  String name;
  String description;
  String category;

  Exercise({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'General',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
      };

  factory Exercise.fromMap(Map m) => Exercise(
        id: m['id'],
        name: m['name'],
        description: m['description'] ?? '',
        category: m['category'] ?? 'General',
      );
}

class ExerciseSet {
  double weight; // kg
  int reps;

  ExerciseSet({this.weight = 0, this.reps = 0});

  Map<String, dynamic> toMap() => {'weight': weight, 'reps': reps};
  factory ExerciseSet.fromMap(Map m) =>
      ExerciseSet(weight: (m['weight'] ?? 0).toDouble(), reps: m['reps'] ?? 0);
}

class LoggedExercise {
  final String exerciseId;
  final String exerciseName;
  List<ExerciseSet> sets;

  LoggedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory LoggedExercise.fromMap(Map m) => LoggedExercise(
        exerciseId: m['exerciseId'],
        exerciseName: m['exerciseName'],
        sets: (m['sets'] as List? ?? [])
            .map((s) => ExerciseSet.fromMap(s))
            .toList(),
      );

  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + s.weight * s.reps);
  double get maxWeight =>
      sets.isEmpty ? 0 : sets.map((s) => s.weight).reduce(max);
}

class WorkoutLog {
  final String id;
  final DateTime date;
  List<LoggedExercise> exercises;
  String? templateId;
  String notes;

  WorkoutLog({
    required this.id,
    required this.date,
    required this.exercises,
    this.templateId,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'templateId': templateId,
        'notes': notes,
      };

  factory WorkoutLog.fromMap(Map m) => WorkoutLog(
        id: m['id'],
        date: DateTime.parse(m['date']),
        exercises: (m['exercises'] as List? ?? [])
            .map((e) => LoggedExercise.fromMap(e))
            .toList(),
        templateId: m['templateId'],
        notes: m['notes'] ?? '',
      );
}

class WorkoutTemplate {
  final String id;
  String name;
  List<String> exerciseIds; // ordered list

  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'exerciseIds': exerciseIds,
      };

  factory WorkoutTemplate.fromMap(Map m) => WorkoutTemplate(
        id: m['id'],
        name: m['name'],
        exerciseIds: List<String>.from(m['exerciseIds'] ?? []),
      );
}

class UserProfile {
  String name;
  String email;
  int? age;
  double? weightKg;
  double? heightCm;
  String goals;
  String? avatarPath;

  UserProfile({
    this.name = '',
    this.email = '',
    this.age,
    this.weightKg,
    this.heightCm,
    this.goals = '',
    this.avatarPath,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'goals': goals,
        'avatarPath': avatarPath,
      };

  factory UserProfile.fromMap(Map m) => UserProfile(
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        age: m['age'],
        weightKg: m['weightKg']?.toDouble(),
        heightCm: m['heightCm']?.toDouble(),
        goals: m['goals'] ?? '',
        avatarPath: m['avatarPath'],
      );
}

// ============================================================
// STATE / STORE (Provider)
// ============================================================

class AppStore extends ChangeNotifier {
  // Boxes
  late Box _exerciseBox;
  late Box _logBox;
  late Box _templateBox;
  late Box _profileBox;
  late Box _photoBox;

  List<Exercise> exercises = [];
  List<WorkoutLog> logs = [];
  List<WorkoutTemplate> templates = [];
  UserProfile profile = UserProfile();
  List<String> progressPhotos = [];

  final _uuid = const Uuid();

  Future<void> init() async {
    _exerciseBox = await Hive.openBox('exercises');
    _logBox = await Hive.openBox('workout_logs');
    _templateBox = await Hive.openBox('templates');
    _profileBox = await Hive.openBox('profile');
    _photoBox = await Hive.openBox('progress_photos');
    _load();
  }

  void _load() {
    exercises = _exerciseBox.values
        .map((v) => Exercise.fromMap(Map<String, dynamic>.from(v)))
        .toList();
    logs = _logBox.values
        .map((v) => WorkoutLog.fromMap(Map<String, dynamic>.from(v)))
        .toList();
    templates = _templateBox.values
        .map((v) => WorkoutTemplate.fromMap(Map<String, dynamic>.from(v)))
        .toList();
    final p = _profileBox.get('user');
    if (p != null) profile = UserProfile.fromMap(Map<String, dynamic>.from(p));
    progressPhotos = List<String>.from(_photoBox.get('photos') ?? []);
    notifyListeners();
  }

  String newId() => _uuid.v4();

  // ── Exercises ──
  Future<void> saveExercise(Exercise e) async {
    await _exerciseBox.put(e.id, e.toMap());
    final idx = exercises.indexWhere((x) => x.id == e.id);
    if (idx >= 0) exercises[idx] = e; else exercises.add(e);
    notifyListeners();
  }

  Future<void> deleteExercise(String id) async {
    await _exerciseBox.delete(id);
    exercises.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── Logs ──
  Future<void> saveLog(WorkoutLog log) async {
    await _logBox.put(log.id, log.toMap());
    final idx = logs.indexWhere((l) => l.id == log.id);
    if (idx >= 0) logs[idx] = log; else logs.add(log);
    notifyListeners();
  }

  Future<void> deleteLog(String id) async {
    await _logBox.delete(id);
    logs.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  WorkoutLog? logForDate(DateTime date) {
    final d = DateUtils.dateOnly(date);
    try {
      return logs.firstWhere((l) => DateUtils.dateOnly(l.date) == d);
    } catch (_) {
      return null;
    }
  }

  bool hasLogForDate(DateTime date) => logForDate(date) != null;

  // ── Templates ──
  Future<void> saveTemplate(WorkoutTemplate t) async {
    await _templateBox.put(t.id, t.toMap());
    final idx = templates.indexWhere((x) => x.id == t.id);
    if (idx >= 0) templates[idx] = t; else templates.add(t);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _templateBox.delete(id);
    templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── Profile ──
  Future<void> saveProfile(UserProfile p) async {
    profile = p;
    await _profileBox.put('user', p.toMap());
    notifyListeners();
  }

  // ── Progress Photos ──
  Future<void> addProgressPhoto(String path) async {
    progressPhotos.add(path);
    await _photoBox.put('photos', progressPhotos);
    notifyListeners();
  }

  Future<void> removeProgressPhoto(String path) async {
    progressPhotos.remove(path);
    await _photoBox.put('photos', progressPhotos);
    notifyListeners();
  }

  // ── Graphs ──
  /// Returns (date, maxWeight) points for an exercise
  List<MapEntry<DateTime, double>> progressForExercise(
      String exerciseId,
      {int? month,
      int? year}) {
    final points = <MapEntry<DateTime, double>>[];
    for (final log in logs) {
      if (month != null && log.date.month != month) continue;
      if (year != null && log.date.year != year) continue;
      for (final ex in log.exercises) {
        if (ex.exerciseId == exerciseId && ex.sets.isNotEmpty) {
          points.add(MapEntry(log.date, ex.maxWeight));
        }
      }
    }
    points.sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

  // ── Export ──
  Future<void> exportBackup() async {
    try {
      final data = jsonEncode({
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'logs': logs.map((l) => l.toMap()).toList(),
        'templates': templates.map((t) => t.toMap()).toList(),
        'profile': profile.toMap(),
        'exportedAt': DateTime.now().toIso8601String(),
      });
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/forge_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(data);
      await Share.shareXFiles([XFile(file.path)], text: 'Forge Fitness Backup');
    } catch (e) {
      debugPrint('Export failed: $e');
    }
  }
}

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Hive.initFlutter();
  final store = AppStore();
  await store.init();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const ForgeApp(),
    ),
  );
}

class ForgeApp extends StatelessWidget {
  const ForgeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const RootShell(),
    );
  }
}

// ============================================================
// ROOT SHELL (Bottom Nav + FAB)
// ============================================================

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  static const _tabs = [
    HomeScreen(),
    ExercisesScreen(),
    GraphsScreen(),
    ProfileScreen(),
  ];

  static const _labels = ['Home', 'Exercises', 'Graphs', 'Profile'];
  static const _icons = [
    Icons.calendar_month_outlined,
    Icons.fitness_center_outlined,
    Icons.show_chart_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _tabs),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: List.generate(
            4,
            (i) => BottomNavigationBarItem(
              icon: Icon(_icons[i], size: 22),
              label: _labels[i],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _onFAB,
      backgroundColor: _copper,
      foregroundColor: _black,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.add, size: 26),
    );
  }

  void _onFAB() {
    switch (_tab) {
      case 0:
        _showQuickLog(context);
        break;
      case 1:
        _showExerciseForm(context, null);
        break;
      case 2:
        break;
      case 3:
        _showAddPhoto(context);
        break;
    }
  }

  void _showQuickLog(BuildContext ctx) {
    final today = DateTime.now();
    _openDaySheet(ctx, today);
  }
}

// ============================================================
// HOME / CALENDAR SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FORGE', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text('Training Log',
                    style: Theme.of(context).textTheme.displayLarge),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCalendar(store),
          const Divider(height: 1),
          Expanded(child: _buildDayDetail(store)),
        ],
      ),
    );
  }

  Widget _buildCalendar(AppStore store) {
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focused,
      selectedDayPredicate: (d) =>
          _selected != null && isSameDay(d, _selected!),
      onDaySelected: (sel, foc) {
        setState(() {
          _selected = sel;
          _focused = foc;
        });
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (ctx, day, _) => _dayCell(day, store, false),
        todayBuilder: (ctx, day, _) => _dayCell(day, store, true),
        selectedBuilder: (ctx, day, _) => _dayCell(day, store, false, selected: true),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: GoogleFonts.cormorantGaramond(
            color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w400),
        leftChevronIcon:
            const Icon(Icons.chevron_left, color: _textSecondary, size: 20),
        rightChevronIcon:
            const Icon(Icons.chevron_right, color: _textSecondary, size: 20),
        headerPadding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: GoogleFonts.lato(
            color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        weekendStyle: GoogleFonts.lato(
            color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: EdgeInsets.all(3),
      ),
    );
  }

  Widget _dayCell(DateTime day, AppStore store, bool isToday,
      {bool selected = false}) {
    final hasLog = store.hasLogForDate(day);
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected
            ? _copper
            : isToday
                ? _cardHigh
                : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday && !selected
            ? Border.all(color: _copper.withOpacity(0.6), width: 1)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: GoogleFonts.lato(
                color: selected ? _black : _textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          if (hasLog)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? _black : _copper,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayDetail(AppStore store) {
    final date = _selected ?? DateTime.now();
    final log = store.logForDate(date);
    final isToday = isSameDay(date, DateTime.now());
    final isPast = date.isBefore(DateUtils.dateOnly(DateTime.now()));
    final isFuture = date.isAfter(DateUtils.dateOnly(DateTime.now()));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(date).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    DateFormat('MMMM d, yyyy').format(date),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              if (isToday || isFuture || log == null)
                _CopperButton(
                  label: log == null ? '+ Log' : 'Edit',
                  onTap: () => _openDaySheet(context, date),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (log == null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(
                      isFuture
                          ? Icons.flag_outlined
                          : Icons.fitness_center_outlined,
                      color: _textSecondary,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isFuture ? 'No goal set' : 'No workout logged',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ] else
            _LogDetail(log: log),
        ],
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  final WorkoutLog log;
  const _LogDetail({required this.log});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: log.exercises.map((ex) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ex.exerciseName,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(
                      label: 'SETS', value: '${ex.sets.length}'),
                  const SizedBox(width: 8),
                  _StatChip(
                      label: 'MAX KG',
                      value: ex.maxWeight.toStringAsFixed(1)),
                  const SizedBox(width: 8),
                  _StatChip(
                      label: 'VOL',
                      value: ex.totalVolume.toStringAsFixed(0)),
                ],
              ),
              const SizedBox(height: 8),
              ...ex.sets.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text('Set ${e.key + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 12)),
                          const SizedBox(width: 12),
                          Text(
                            '${e.value.weight} kg × ${e.value.reps} reps',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _cardHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: _copper, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================
// EXERCISES SCREEN
// ============================================================

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final filtered = store.exercises
        .where((e) =>
            e.name.toLowerCase().contains(_query.toLowerCase()) ||
            e.category.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Exercises',
                      style: Theme.of(context).textTheme.displayMedium),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: Icon(Icons.search, color: _textSecondary, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Templates chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text('WORKOUT TEMPLATES',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showTemplateList(context, store),
                  child: Text('Manage →',
                      style: GoogleFonts.lato(
                          color: _copper, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No exercises yet. Tap + to add.',
                        style: Theme.of(context).textTheme.bodyMedium))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) =>
                        _ExerciseCard(exercise: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(exercise.name,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(exercise.category,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _copper)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: _textSecondary, size: 18),
              onPressed: () => _showExerciseForm(context, exercise),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: _textSecondary, size: 18),
              onPressed: () async {
                final ok = await _confirm(context, 'Delete ${exercise.name}?');
                if (ok) await store.deleteExercise(exercise.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GRAPHS SCREEN
// ============================================================

class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});
  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  String? _selectedId;
  bool _isLine = true;
  late DateTime _selectedMonth;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  List<int> _yearOptions(AppStore store) {
    final now = DateTime.now();
    final years = <int>{now.year - 1, now.year, now.year + 1};
    for (final log in store.logs) {
      years.add(log.date.year);
    }
    final minYear = years.isEmpty ? now.year - 1 : years.reduce(min);
    final maxYear = years.isEmpty ? now.year + 1 : years.reduce(max);
    return [for (var year = minYear; year <= maxYear; year++) year];
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.exercises.isEmpty) {
      return const Center(
          child: Text('Add exercises to see progress.',
              style: TextStyle(color: _textSecondary)));
    }

    _selectedId ??= store.exercises.first.id;
    final points = store.progressForExercise(
      _selectedId!,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );
    final selEx = store.exercises.firstWhere((e) => e.id == _selectedId,
        orElse: () => store.exercises.first);
    final years = _yearOptions(store);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress',
                          style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth.month,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                    ),
                    dropdownColor: _cardHigh,
                    style: GoogleFonts.lato(color: _textPrimary, fontSize: 13),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthNames[i]),
                      ),
                    ),
                    onChanged: (month) {
                      if (month == null) return;
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, month);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth.year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                    ),
                    dropdownColor: _cardHigh,
                    style: GoogleFonts.lato(color: _textPrimary, fontSize: 13),
                    items: years
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ))
                        .toList(),
                    onChanged: (year) {
                      if (year == null) return;
                      setState(() {
                        _selectedMonth = DateTime(year, _selectedMonth.month);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Progress',
                style: Theme.of(context).textTheme.displayMedium),
          ),
          // Exercise selector
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: store.exercises.length,
              itemBuilder: (ctx, i) {
                final ex = store.exercises[i];
                final sel = ex.id == _selectedId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedId = ex.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _copper : _card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ex.name,
                      style: GoogleFonts.lato(
                          color: sel ? _black : _textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(selEx.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _ToggleChip(
                    label: 'Line',
                    active: _isLine,
                    onTap: () => setState(() => _isLine = true)),
                const SizedBox(width: 6),
                _ToggleChip(
                    label: 'Bar',
                    active: !_isLine,
                    onTap: () => setState(() => _isLine = false)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: points.length < 2
                ? Center(
                    child: Text(
                    'Log at least 2 sessions to see trends.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
                    child: _isLine
                        ? _LineGraph(points: points)
                        : _BarGraph(points: points),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _copper : _card,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
              color: active ? _black : _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LineGraph extends StatelessWidget {
  final List<MapEntry<DateTime, double>> points;
  const _LineGraph({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final maxY = (points.map((e) => e.value).reduce(max) * 1.15).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: _divider, strokeWidth: 0.5),
          getDrawingVerticalLine: (v) =>
              FlLine(color: _divider, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: GoogleFonts.lato(color: _textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= points.length || i < 0) return const SizedBox();
                return Text(
                  DateFormat('MM/dd').format(points[i].key),
                  style: GoogleFonts.lato(color: _textSecondary, fontSize: 9),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _copper,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: _copper,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _copper.withOpacity(0.08),
            ),
          )
        ],
      ),
    );
  }
}

class _BarGraph extends StatelessWidget {
  final List<MapEntry<DateTime, double>> points;
  const _BarGraph({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY = (points.map((e) => e.value).reduce(max) * 1.15).ceilToDouble();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: _divider, strokeWidth: 0.5),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: GoogleFonts.lato(color: _textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= points.length || i < 0) return const SizedBox();
                return Text(
                  DateFormat('MM/dd').format(points[i].key),
                  style: GoogleFonts.lato(color: _textSecondary, fontSize: 9),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: points.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: _copper,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: _cardHigh,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// PROFILE SCREEN
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Profile',
                    style: Theme.of(context).textTheme.displayMedium),
                const Spacer(),
                _CopperButton(
                    label: 'Edit',
                    onTap: () => _showProfileForm(context, store)),
                const SizedBox(width: 8),
                _CopperButton(
                    label: 'Export',
                    onTap: () => store.exportBackup()),
              ],
            ),
            const SizedBox(height: 24),
            // Avatar + info
            Row(
              children: [
                GestureDetector(
                  onTap: () => _pickAvatar(context, store),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: _card,
                    backgroundImage: p.avatarPath != null
                        ? FileImage(File(p.avatarPath!))
                        : null,
                    child: p.avatarPath == null
                        ? const Icon(Icons.person_outline,
                            color: _textSecondary, size: 36)
                        : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name.isEmpty ? 'Your Name' : p.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (p.email.isNotEmpty)
                        Text(p.email,
                            style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (p.age != null)
                            _InfoChip(label: '${p.age}y'),
                          if (p.weightKg != null) ...[
                            const SizedBox(width: 6),
                            _InfoChip(label: '${p.weightKg}kg'),
                          ],
                          if (p.heightCm != null) ...[
                            const SizedBox(width: 6),
                            _InfoChip(label: '${p.heightCm}cm'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.goals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GOALS',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Text(p.goals,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Text('PROGRESS PHOTOS',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => _addPhoto(context, store),
                  child: const Icon(Icons.add_circle_outline,
                      color: _copper, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            store.progressPhotos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No photos yet',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: store.progressPhotos.length,
                    itemBuilder: (ctx, i) {
                      final path = store.progressPhotos[i];
                      return GestureDetector(
                        onLongPress: () async {
                          final ok = await _confirm(context, 'Remove photo?');
                          if (ok) await store.removeProgressPhoto(path);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(path), fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext ctx, AppStore store) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      final p = store.profile;
      p.avatarPath = img.path;
      await store.saveProfile(p);
    }
  }

  Future<void> _addPhoto(BuildContext ctx, AppStore store) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) await store.addProgressPhoto(img.path);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _cardHigh, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: GoogleFonts.lato(
              color: _copper, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ============================================================
// SHARED BOTTOM SHEET HELPERS
// These are top-level functions, called from FAB + cards
// ============================================================

void _openDaySheet(BuildContext ctx, DateTime date) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ChangeNotifierProvider.value(
      value: ctx.read<AppStore>(),
      child: _DayLogSheet(date: date),
    ),
  );
}

class _DayLogSheet extends StatefulWidget {
  final DateTime date;
  const _DayLogSheet({required this.date});
  @override
  State<_DayLogSheet> createState() => _DayLogSheetState();
}

class _DayLogSheetState extends State<_DayLogSheet> {
  late List<LoggedExercise> _logged;
  late WorkoutLog? _existing;
  String _notes = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _existing = store.logForDate(widget.date);
    _logged = _existing?.exercises
            .map((e) => LoggedExercise(
                  exerciseId: e.exerciseId,
                  exerciseName: e.exerciseName,
                  sets: e.sets.map((s) => ExerciseSet(weight: s.weight, reps: s.reps)).toList(),
                ))
            .toList() ??
        [];
    _notes = _existing?.notes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final height = MediaQuery.of(context).size.height * 0.9;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE').format(widget.date).toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(DateFormat('MMM d').format(widget.date),
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const Spacer(),
                if (store.templates.isNotEmpty)
                  TextButton(
                    onPressed: () => _pickTemplate(store),
                    child: Text('Use Template',
                        style: GoogleFonts.lato(
                            color: _copper, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logged.isEmpty
                ? Center(
                    child: Text('No exercises added.',
                        style: Theme.of(context).textTheme.bodyMedium))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logged.length,
                    itemBuilder: (ctx, i) => _LoggedExerciseEditor(
                      loggedExercise: _logged[i],
                      onRemove: () => setState(() => _logged.removeAt(i)),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addExercise(store),
                        icon: const Icon(Icons.add, size: 16, color: _copper),
                        label: Text('Add Exercise',
                            style: GoogleFonts.lato(
                                color: _copper, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _copper),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _copper,
                          foregroundColor: _black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: _black, strokeWidth: 2))
                            : Text('Save',
                                style: GoogleFonts.lato(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTemplate(AppStore store) async {
    final t = await showDialog<WorkoutTemplate>(
      context: context,
      builder: (ctx) => _TemplatePickDialog(templates: store.templates),
    );
    if (t == null) return;

    // Load exercises from template
    final newLogged = <LoggedExercise>[];
    for (final eid in t.exerciseIds) {
      try {
        final ex = store.exercises.firstWhere((e) => e.id == eid);
        newLogged.add(LoggedExercise(
          exerciseId: eid,
          exerciseName: ex.name,
          sets: [ExerciseSet()],
        ));
      } catch (_) {}
    }
    setState(() {
      _logged = [...newLogged, ..._logged];
    });
  }

  Future<void> _addExercise(AppStore store) async {
    if (store.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create exercises first in the Exercises tab.')),
      );
      return;
    }
    final ex = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => _ExercisePickDialog(exercises: store.exercises),
    );
    if (ex == null) return;
    setState(() {
      _logged.add(LoggedExercise(
        exerciseId: ex.id,
        exerciseName: ex.name,
        sets: [ExerciseSet()],
      ));
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final store = context.read<AppStore>();
      final log = WorkoutLog(
        id: _existing?.id ?? store.newId(),
        date: widget.date,
        exercises: _logged,
        notes: _notes,
      );
      await store.saveLog(log);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _LoggedExerciseEditor extends StatefulWidget {
  final LoggedExercise loggedExercise;
  final VoidCallback onRemove;
  const _LoggedExerciseEditor(
      {required this.loggedExercise, required this.onRemove});

  @override
  State<_LoggedExerciseEditor> createState() => _LoggedExerciseEditorState();
}

class _LoggedExerciseEditorState extends State<_LoggedExerciseEditor> {
  @override
  Widget build(BuildContext context) {
    final le = widget.loggedExercise;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(le.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                icon: const Icon(Icons.close, color: _textSecondary, size: 18),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Set rows
          ...le.sets.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: _cardHigh, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${i + 1}',
                          style: GoogleFonts.lato(
                              color: _textSecondary, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactInput(
                      hint: 'kg',
                      initial: s.weight > 0 ? '${s.weight}' : '',
                      onChanged: (v) =>
                          s.weight = double.tryParse(v) ?? s.weight,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactInput(
                      hint: 'reps',
                      initial: s.reps > 0 ? '${s.reps}' : '',
                      onChanged: (v) => s.reps = int.tryParse(v) ?? s.reps,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: _textSecondary, size: 18),
                    onPressed: le.sets.length > 1
                        ? () => setState(() => le.sets.removeAt(i))
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => le.sets.add(ExerciseSet())),
            icon: const Icon(Icons.add, size: 14, color: _copper),
            label: Text('Add Set',
                style: GoogleFonts.lato(color: _copper, fontSize: 12)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

class _CompactInput extends StatelessWidget {
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  const _CompactInput({
    required this.hint,
    required this.initial,
    required this.onChanged,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textAlign: TextAlign.center,
      style: GoogleFonts.lato(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

// ============================================================
// EXERCISE FORM
// ============================================================

void _showExerciseForm(BuildContext ctx, Exercise? existing) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ChangeNotifierProvider.value(
      value: ctx.read<AppStore>(),
      child: _ExerciseFormSheet(existing: existing),
    ),
  );
}

class _ExerciseFormSheet extends StatefulWidget {
  final Exercise? existing;
  const _ExerciseFormSheet({this.existing});
  @override
  State<_ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<_ExerciseFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late String _category;
  bool _saving = false;

  static const _categories = [
    'General', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core', 'Cardio'
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _desc = TextEditingController(text: widget.existing?.description ?? '');
    _category = widget.existing?.category ?? 'General';
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: _divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              widget.existing == null ? 'New Exercise' : 'Edit Exercise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              dropdownColor: _cardHigh,
              style: GoogleFonts.lato(color: _textPrimary, fontSize: 14),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _copper,
                  foregroundColor: _black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: _black, strokeWidth: 2))
                    : Text('Save',
                        style: GoogleFonts.lato(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final store = context.read<AppStore>();
      final ex = Exercise(
        id: widget.existing?.id ?? store.newId(),
        name: _name.text.trim(),
        description: _desc.text.trim(),
        category: _category,
      );
      await store.saveExercise(ex);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ============================================================
// PROFILE FORM
// ============================================================

void _showProfileForm(BuildContext ctx, AppStore store) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ChangeNotifierProvider.value(
      value: store,
      child: const _ProfileFormSheet(),
    ),
  );
}

class _ProfileFormSheet extends StatefulWidget {
  const _ProfileFormSheet();
  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late TextEditingController _name, _email, _age, _weight, _height, _goals;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppStore>().profile;
    _name = TextEditingController(text: p.name);
    _email = TextEditingController(text: p.email);
    _age = TextEditingController(text: p.age?.toString() ?? '');
    _weight = TextEditingController(text: p.weightKg?.toString() ?? '');
    _height = TextEditingController(text: p.heightCm?.toString() ?? '');
    _goals = TextEditingController(text: p.goals);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    _goals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: _divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Edit Profile',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(controller: _age,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: _weight,
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: _height,
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _goals,
                decoration: const InputDecoration(labelText: 'Goals'),
                maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _copper,
                  foregroundColor: _black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Save',
                    style: GoogleFonts.lato(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final p = UserProfile(
      name: _name.text.trim(),
      email: _email.text.trim(),
      age: int.tryParse(_age.text),
      weightKg: double.tryParse(_weight.text),
      heightCm: double.tryParse(_height.text),
      goals: _goals.text.trim(),
      avatarPath: store.profile.avatarPath,
    );
    await store.saveProfile(p);
    if (mounted) Navigator.pop(context);
  }
}

// ============================================================
// TEMPLATE MANAGEMENT
// ============================================================

void _showTemplateList(BuildContext ctx, AppStore store) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ChangeNotifierProvider.value(
      value: store,
      child: const _TemplateListSheet(),
    ),
  );
}

class _TemplateListSheet extends StatelessWidget {
  const _TemplateListSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (ctx, ctrl) => Column(
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                  color: _divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Templates',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: _copper),
                  onPressed: () => _showTemplateForm(context, store, null),
                ),
              ],
            ),
          ),
          Expanded(
            child: store.templates.isEmpty
                ? Center(
                    child: Text('No templates',
                        style: Theme.of(context).textTheme.bodyMedium))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: store.templates.length,
                    itemBuilder: (ctx, i) {
                      final t = store.templates[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                      '${t.exerciseIds.length} exercise(s)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: _textSecondary, size: 18),
                              onPressed: () =>
                                  _showTemplateForm(context, store, t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: _textSecondary, size: 18),
                              onPressed: () async {
                                final ok = await _confirm(
                                    context, 'Delete template?');
                                if (ok) await store.deleteTemplate(t.id);
                              },
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

void _showTemplateForm(
    BuildContext ctx, AppStore store, WorkoutTemplate? existing) {
  showDialog(
    context: ctx,
    builder: (_) => ChangeNotifierProvider.value(
      value: store,
      child: _TemplateFormDialog(existing: existing),
    ),
  );
}

class _TemplateFormDialog extends StatefulWidget {
  final WorkoutTemplate? existing;
  const _TemplateFormDialog({this.existing});
  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  late TextEditingController _name;
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIds = List.from(widget.existing?.exerciseIds ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return AlertDialog(
      backgroundColor: _surface,
      title: Text(
          widget.existing == null ? 'New Template' : 'Edit Template',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Template name'),
            ),
            const SizedBox(height: 12),
            Text('Exercises', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: ListView(
                children: store.exercises.map((ex) {
                  final sel = _selectedIds.contains(ex.id);
                  return CheckboxListTile(
                    value: sel,
                    title: Text(ex.name,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontSize: 13)),
                    activeColor: _copper,
                    checkColor: _black,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedIds.add(ex.id);
                        } else {
                          _selectedIds.remove(ex.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: GoogleFonts.lato(color: _textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _copper, foregroundColor: _black),
          child: Text('Save', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final store = context.read<AppStore>();
    await store.saveTemplate(WorkoutTemplate(
      id: widget.existing?.id ?? store.newId(),
      name: _name.text.trim(),
      exerciseIds: _selectedIds,
    ));
    if (mounted) Navigator.pop(context);
  }
}

// ============================================================
// PICK DIALOGS
// ============================================================

class _ExercisePickDialog extends StatelessWidget {
  final List<Exercise> exercises;
  const _ExercisePickDialog({required this.exercises});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      title: Text('Pick Exercise',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: exercises.length,
          itemBuilder: (ctx, i) {
            final ex = exercises[i];
            return ListTile(
              title: Text(ex.name,
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(ex.category,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: _copper)),
              onTap: () => Navigator.pop(context, ex),
              dense: true,
            );
          },
        ),
      ),
    );
  }
}

class _TemplatePickDialog extends StatelessWidget {
  final List<WorkoutTemplate> templates;
  const _TemplatePickDialog({required this.templates});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      title: Text('Use Template',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: double.maxFinite,
        height: 200,
        child: ListView.builder(
          itemCount: templates.length,
          itemBuilder: (ctx, i) {
            final t = templates[i];
            return ListTile(
              title: Text(t.name,
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text('${t.exerciseIds.length} exercises',
                  style: Theme.of(context).textTheme.bodyMedium),
              onTap: () => Navigator.pop(context, t),
              dense: true,
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// ADD PHOTO (profile tab FAB)
// ============================================================

Future<void> _showAddPhoto(BuildContext ctx) async {
  final store = ctx.read<AppStore>();
  final picker = ImagePicker();
  final img = await picker.pickImage(source: ImageSource.gallery);
  if (img != null) await store.addProgressPhoto(img.path);
}

// ============================================================
// SHARED UTILS
// ============================================================

Future<bool> _confirm(BuildContext ctx, String message) async {
  return await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: _surface,
          content: Text(message,
              style: const TextStyle(color: _textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.lato(color: _textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirm',
                  style: GoogleFonts.lato(color: _copper)),
            ),
          ],
        ),
      ) ??
      false;
}

class _CopperButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CopperButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _copper.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _copper.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
              color: _copper, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}