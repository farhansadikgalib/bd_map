import 'package:bd_map/bd_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const BangladeshMapApp());

class BangladeshMapApp extends StatelessWidget {
  const BangladeshMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangladesh Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF006A4E)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF006A4E),
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Region colors shared by every map in this app (and the screenshot test). Regions cycle through
/// the list, so any set of distinct colors works.
const kMapPalette = <Color>[
  Color(0xFF3F51B5), // indigo
  Color(0xFF009688), // teal
  Color(0xFFFF9800), // orange
  Color(0xFFE91E63), // pink
  Color(0xFF4CAF50), // green
  Color(0xFF9C27B0), // purple
  Color(0xFF00BCD4), // cyan
  Color(0xFFFFC107), // amber
  Color(0xFFF44336), // red
  Color(0xFF2196F3), // blue
  Color(0xFF8BC34A), // light green
  Color(0xFFFF5722), // deep orange
  Color(0xFF673AB7), // deep purple
];

/// Where the map data comes from. Both sources feed the maps through the
/// same one line: `BdMapData<num>.fromJsonString(body)`.
enum DataSource { jsonFile, apiList }

/// What an API typically returns: a list of regions with values, here as a
/// canned response body. Replace [_fetchFromApi] with a real request such
/// as `(await http.get(uri)).body` and nothing else changes.
const _sampleApiResponse = '''
{
  "title": "Population",
  "unit": "M",
  "data": [
    {"division": "Dhaka", "value": 44.2},
    {"division": "Chattogram", "value": 33.2},
    {"division": "Rajshahi", "value": 20.4},
    {"district": "Gazipur", "value": 3.4},
    {"district": "Cumilla", "value": 5.6},
    {"division": "Dhaka", "thana": "Savar", "value": 1.4}
  ]
}
''';

Future<String> _fetchFromApi() async => _sampleApiResponse;

/// A nested JSON file. Copy `assets/bd_data_full_country.json`, replace the
/// sample values with your own, and every region is already in place.
Future<String> _loadFromJsonFile() =>
    rootBundle.loadString('assets/bd_data_full_country.json');

class _HomePageState extends State<HomePage> {
  int _page = 0;
  bool _useBangla = false;
  DataSource _source = DataSource.jsonFile;
  BdMapData<num>? _data;

  @override
  void initState() {
    super.initState();
    _load(_source);
  }

  Future<void> _load(DataSource source) async {
    final body = switch (source) {
      DataSource.jsonFile => await _loadFromJsonFile(),
      DataSource.apiList => await _fetchFromApi(),
    };
    if (!mounted) return;
    setState(() {
      _source = source;
      _data = BdMapData<num>.fromJsonString(body);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BdMap(
        palette: kMapPalette,
        useBanglaNames: _useBangla,
        data: _data,
        showDataList: _data != null,
      ),
      _AtlasPage(useBangla: _useBangla, data: _data),
      const _ClassicPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_useBangla ? 'বাংলাদেশ' : 'Bangladesh'),
        actions: [
          PopupMenuButton<DataSource>(
            tooltip: 'Data source',
            icon: const Icon(Icons.storage),
            initialValue: _source,
            onSelected: _load,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: DataSource.jsonFile,
                child: Text('JSON file'),
              ),
              PopupMenuItem(
                value: DataSource.apiList,
                child: Text('API list'),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => setState(() => _useBangla = !_useBangla),
            icon: const Icon(Icons.translate, size: 18),
            label: Text(_useBangla ? 'EN' : 'বাংলা'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: pages[_page],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Atlas'),
          NavigationDestination(icon: Icon(Icons.flag), label: 'Classic'),
        ],
      ),
    );
  }
}

/// Full-country map, switchable between the four admin levels.
class _AtlasPage extends StatefulWidget {
  const _AtlasPage({required this.useBangla, this.data});

  final bool useBangla;
  final BdMapData? data;

  @override
  State<_AtlasPage> createState() => _AtlasPageState();
}

class _AtlasPageState extends State<_AtlasPage> {
  BdArea _level = BdArea.district;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<BdArea>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BdArea.division, label: Text('Division')),
            ButtonSegment(value: BdArea.district, label: Text('District')),
            ButtonSegment(value: BdArea.upazila, label: Text('Thana')),
            ButtonSegment(value: BdArea.union, label: Text('Union')),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BdCountryMap(
            _level,
            palette: kMapPalette,
            useBanglaNames: widget.useBangla,
            data: widget.data,
            showDataList: widget.data != null,
          ),
        ),
      ],
    );
  }
}

/// The original hand-drawn division map, still available as `Bangladesh()`.
class _ClassicPage extends StatelessWidget {
  const _ClassicPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SingleChildScrollView(child: Bangladesh()));
  }
}
