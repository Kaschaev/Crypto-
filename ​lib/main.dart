import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CryptoPulseApp());
}

class CryptoPulseApp extends StatefulWidget {
  const CryptoPulseApp({super.key});

  @override
  State<CryptoPulseApp> createState() => _CryptoPulseAppState();
}

class _CryptoPulseAppState extends State<CryptoPulseApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const String fontName = 'Montserrat';

    return MaterialApp(
      title: 'CryptoPulse PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: fontName,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8), brightness: Brightness.light),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: fontName,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEAB308), brightness: Brightness.dark, surface: const Color(0xFF161B22)),
        cardTheme: CardThemeData(color: const Color(0xFF161B22), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      themeMode: _themeMode,
      home: MainNavigationScreen(isDark: _themeMode == ThemeMode.dark, onToggleTheme: _toggleTheme),
    );
  }
}

class CoinModel {
  final String id;
  final String symbol;
  final String name;
  double price;
  double change24h;
  int rank;

  CoinModel({
    required this.id,
    required this.symbol,
    required this.name,
    this.price = 0.0,
    this.change24h = 0.0,
    this.rank = 1,
  });
}

class NewsArticle {
  final String title;
  final String url;
  final String source;
  final String body;
  final String category;
  final int sentimentDelta;
  final String sentimentLabel;

  NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.body,
    required this.category,
    required this.sentimentDelta,
    required this.sentimentLabel,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const MainNavigationScreen({super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MarketAnalysisScreen(isDark: widget.isDark, onToggleTheme: widget.onToggleTheme),
          const WalletScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Анализ и Монета',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Кошелек (Web3)',
          ),
        ],
      ),
    );
  }
}

class MarketAnalysisScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const MarketAnalysisScreen({super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<MarketAnalysisScreen> createState() => _MarketAnalysisScreenState();
}

class _MarketAnalysisScreenState extends State<MarketAnalysisScreen> {
  List<CoinModel> _coins = [
    CoinModel(id: 'bitcoin', symbol: 'BTC', name: 'Bitcoin', price: 89000, change24h: 1.5, rank: 1),
    CoinModel(id: 'ethereum', symbol: 'ETH', name: 'Ethereum', price: 3100, change24h: 0.9, rank: 2),
    CoinModel(id: 'the-open-network', symbol: 'TON', name: 'Toncoin', price: 5.4, change24h: 2.3, rank: 9),
    CoinModel(id: 'solana', symbol: 'SOL', name: 'Solana', price: 190, change24h: 3.1, rank: 4),
  ];

  late CoinModel _selectedCoin;
  bool _loading = false;

  // Вкладки для выбранной монеты: 0 - Обзор/Сигнал, 1 - Новости монеты, 2 - Прогноз курса
  int _coinTabIdx = 0;

  double _rsi = 50.0;
  double _ema9 = 0.0;
  double _ema21 = 0.0;
  double _volatilityPct = 3.5;
  double _slopePctPerDay = 0.2;
  int _totalScore = 50;
  String _verdict = 'ДЕРЖАТЬ / ОЖИДАНИЕ';

  String _selectedForecastHorizon = 'week';
  double _targetForecastPrice = 0.0;
  double _targetForecastPct = 0.0;
  double _forecastMinPrice = 0.0;
  double _forecastMaxPrice = 0.0;

  Map<String, String> _officialLinks = {};
  String? _githubRepo;
  String _officialDesc = '';
  List<NewsArticle> _news = [];
  String _newsFilter = 'all';

  static const List<String> _bullWords = [
    'surge', 'soar', 'bull', 'bullish', 'approval', 'approved', 'etf',
    'partnership', 'launch', 'upgrade', 'release', 'mainnet', 'adoption',
    'record', 'high', 'inflow', 'buy', 'accumulate', 'growth', 'rally',
    'breakout', 'institutional', 'integration', 'рост', 'одобрил', 'запуск'
  ];

  static const List<String> _bearWords = [
    'hack', 'hacked', 'exploit', 'vulnerability', 'crash', 'drop', 'plunge',
    'bear', 'bearish', 'ban', 'lawsuit', 'sued', 'sec', 'outflow', 'sell',
    'dump', 'fraud', 'scam', 'delay', 'reject', 'liquidation', 'delist', 'взлом', 'обвал'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCoin = _coins.first;
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_coin_id');
    await _loadTop100();
    if (savedId != null) {
      final found = _coins.where((c) => c.id == savedId).toList();
      if (found.isNotEmpty) _selectedCoin = found.first;
    }
    await _refreshSelectedCoin();
  }

  Future<void> _loadTop100() async {
    try {
      final res = await http.get(Uri.parse('https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _coins = data.map((e) => CoinModel(
              id: e['id'] ?? 'bitcoin',
              symbol: (e['symbol'] ?? 'btc').toString().toUpperCase(),
              name: e['name'] ?? 'Bitcoin',
              price: (e['current_price'] as num?)?.toDouble() ?? 0.0,
              change24h: (e['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0,
              rank: (e['market_cap_rank'] as num?)?.toInt() ?? 99,
            )).toList();
            _selectedCoin = _coins.first;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshSelectedCoin() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_coin_id', _selectedCoin.id);

    await Future.wait([
      _fetchDetails(),
      _fetchIndicators(),
    ]);
    await _fetchNews();
    _calculateSignalAndForecast();
    await _updateAndroidWidget();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchDetails() async {
    _officialLinks = {};
    _githubRepo = null;
    _officialDesc = '';
    try {
      final res = await http.get(Uri.parse('https://api.coingecko.com/api/v3/coins/${_selectedCoin.id}?localization=false&tickers=false&market_data=true'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final md = data['market_data'];
        if (md != null) {
          _selectedCoin.price = (md['current_price']?['usd'] as num?)?.toDouble() ?? _selectedCoin.price;
          _selectedCoin.change24h = (md['price_change_percentage_24h'] as num?)?.toDouble() ?? _selectedCoin.change24h;
        }
        final links = data['links'] ?? {};
        if (links['homepage'] is List && (links['homepage'] as List).isNotEmpty) _officialLinks['🌐 Сайт'] = links['homepage'][0];
        if (links['twitter_screen_name'] != null) _officialLinks['𝕏 Twitter'] = 'https://x.com/${links['twitter_screen_name']}';
        if (links['telegram_channel_identifier'] != null) _officialLinks['✈️ Telegram'] = 'https://t.me/${links['telegram_channel_identifier']}';
        if (links['repos_url']?['github'] is List && (links['repos_url']['github'] as List).isNotEmpty) {
          final gh = links['repos_url']['github'][0].toString();
          _officialLinks['💻 GitHub'] = gh;
          final match = RegExp(r'github\.com/([^/]+/[^/]+)').firstMatch(gh);
          if (match != null) _githubRepo = match.group(1)?.replaceAll('.git', '');
        }
        final rawDesc = (data['description']?['en'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '');
        if (rawDesc.isNotEmpty) _officialDesc = rawDesc.length > 200 ? '${rawDesc.substring(0, 200)}...' : rawDesc;
      }
    } catch (_) {}
    if (_officialLinks.isEmpty) _officialLinks['🌐 CoinGecko'] = 'https://www.coingecko.com/en/coins/${_selectedCoin.id}';
  }

  Future<void> _fetchIndicators() async {
    try {
      final res = await http.get(Uri.parse('https://api.coingecko.com/api/v3/coins/${_selectedCoin.id}/market_chart?vs_currency=usd&days=14'));
      if (res.statusCode == 200) {
        final prices = (jsonDecode(res.body)['prices'] as List).map((e) => (e[1] as num).toDouble()).toList();
        if (prices.length >= 22) {
          _rsi = _calcRSI(prices, 14);
          _ema9 = _calcEMA(prices, 9);
          _ema21 = _calcEMA(prices, 21);
          _volatilityPct = _calcVol(prices);
          _slopePctPerDay = _calcSlope(prices);
          return;
        }
      }
    } catch (_) {}
    final chg = _selectedCoin.change24h;
    _rsi = (50.0 + chg * 2.1).clamp(20.0, 80.0);
    _volatilityPct = (chg.abs() * 0.8 + 2.5).clamp(2.0, 14.0);
    _slopePctPerDay = (chg * 0.25).clamp(-5.0, 5.0);
  }

  double _calcRSI(List<double> p, int per) {
    double g = 0, l = 0;
    final s = p.sublist(p.length - per - 1);
    for (int i = 1; i < s.length; i++) {
      final d = s[i] - s[i - 1];
      if (d >= 0) g += d; else l -= d;
    }
    final avgL = l / per;
    if (avgL == 0) return 100.0;
    return 100.0 - (100.0 / (1.0 + (g / per) / avgL));
  }

  double _calcEMA(List<double> p, int per) {
    final k = 2.0 / (per + 1);
    double ema = p.first;
    for (int i = 1; i < p.length; i++) ema = p[i] * k + ema * (1.0 - k);
    return ema;
  }

  double _calcVol(List<double> p) {
    final rec = p.length > 24 ? p.sublist(p.length - 24) : p;
    return (((rec.reduce(max) - rec.reduce(min)) / rec.reduce(min)) * 100.0).clamp(1.5, 16.0);
  }

  double _calcSlope(List<double> p) {
    final n = p.length;
    if (n < 5) return 0.0;
    double sx = 0, sy = 0, sxy = 0, sxx = 0;
    for (int i = 0; i < n; i++) { sx += i; sy += p[i]; sxy += i * p[i]; sxx += i * i; }
    return ((( (n * sxy - sx * sy) / (n * sxx - sx * sx) ) * (n / 14.0)) / p.last * 100.0).clamp(-5.0, 5.0);
  }

  Future<void> _fetchNews() async {
    List<NewsArticle> gathered = [];
    final sym = _selectedCoin.symbol.toUpperCase();

    if (_githubRepo != null) {
      try {
        final ghRes = await http.get(Uri.parse('https://api.github.com/repos/$_githubRepo/releases?per_page=2'));
        if (ghRes.statusCode == 200) {
          for (final r in jsonDecode(ghRes.body)) {
            final title = '[Релиз $sym] ${r['name'] ?? r['tag_name']}';
            final body = (r['body'] ?? '').toString().replaceAll(RegExp(r'[#*`]'), '');
            gathered.add(NewsArticle(title: title, url: r['html_url'], source: 'GitHub', body: body, category: 'official', sentimentDelta: 1, sentimentLabel: 'Позитив'));
          }
        }
      } catch (_) {}
    }

    try {
      final res = await http.get(Uri.parse('https://min-api.cryptocompare.com/data/v2/news/?categories=$sym&lang=EN'));
      if (res.statusCode == 200) {
        for (final item in (jsonDecode(res.body)['Data'] as List).take(8)) {
          final title = item['title'] ?? '';
          final body = item['body'] ?? '';
          int sent = 0;
          for (final w in _bullWords) { if (title.toLowerCase().contains(w)) sent++; }
          for (final w in _bearWords) { if (title.toLowerCase().contains(w)) sent--; }
          gathered.add(NewsArticle(
            title: title,
            url: item['url'] ?? '',
            source: item['source_info']?['name'] ?? 'Crypto Media',
            body: body,
            category: 'media',
            sentimentDelta: sent,
            sentimentLabel: sent > 0 ? 'Бычий' : (sent < 0 ? 'Медвежий' : 'Нейтрально'),
          ));
        }
      }
    } catch (_) {}

    if (_officialDesc.isNotEmpty) {
      gathered.insert(0, NewsArticle(
        title: '${_selectedCoin.name} ($sym) — Обзор проекта',
        url: 'https://www.coingecko.com',
        source: 'Official',
        body: _officialDesc,
        category: 'official',
        sentimentDelta: 0,
        sentimentLabel: 'Инфо',
      ));
    }

    _news = gathered;
  }

  void _calculateSignalAndForecast() {
    double techDelta = 0;
    if (_rsi < 32) techDelta += 14;
    else if (_rsi > 68) techDelta -= 14;

    if (_ema9 >= _ema21) techDelta += 12; else techDelta -= 12;

    int newsDelta = 0;
    for (final n in _news) { newsDelta += n.sentimentDelta * 5; }
    newsDelta = newsDelta.clamp(-20, 20);

    _totalScore = (50 + newsDelta + techDelta + (_selectedCoin.change24h * 1.5)).round().clamp(5, 95);

    if (_totalScore >= 68) _verdict = 'АКТИВНО ПОКУПАТЬ';
    else if (_totalScore >= 56) _verdict = 'ПОКУПАТЬ (ЛОНГ)';
    else if (_totalScore <= 32) _verdict = 'АКТИВНО ПРОДАВАТЬ';
    else if (_totalScore <= 44) _verdict = 'ПРОДАВАТЬ (ШОРТ)';
    else _verdict = 'ДЕРЖАТЬ / ОЖИДАНИЕ';

    _updateForecastValues();
  }

  void _updateForecastValues() {
    final p = _selectedCoin.price;
    final bias = (_totalScore - 50) / 50.0;
    final dailyDrift = (_slopePctPerDay * 0.45) + (bias * _volatilityPct * 0.35);

    double days = 7;
    double volatilityMultiplier = 2.1;

    switch (_selectedForecastHorizon) {
      case 'day':
        days = 1;
        volatilityMultiplier = 0.8;
        break;
      case 'week':
        days = 7;
        volatilityMultiplier = 2.1;
        break;
      case 'month':
        days = 30;
        volatilityMultiplier = 4.5;
        break;
      case 'year':
        days = 365;
        volatilityMultiplier = 12.0;
        break;
      case '3years':
        days = 1095;
        volatilityMultiplier = 22.0;
        break;
    }

    final expectedPct = (pow(1.0 + (dailyDrift / 100.0), days) - 1.0) * 100.0;
    _targetForecastPct = expectedPct.clamp(-95.0, 500.0);
    _targetForecastPrice = p * (1.0 + _targetForecastPct / 100.0);

    final band = _volatilityPct * volatilityMultiplier;
    _forecastMinPrice = _targetForecastPrice * (1.0 - band / 100.0);
    _forecastMaxPrice = _targetForecastPrice * (1.0 + band / 100.0);
    if (_forecastMinPrice < 0) _forecastMinPrice = 0.00001;
  }

  Future<void> _updateAndroidWidget() async {
    try {
      final pDigits = _selectedCoin.price < 1 ? 4 : 2;
      final priceStr = '\$${_selectedCoin.price.toStringAsFixed(pDigits)} (${_selectedCoin.change24h >= 0 ? '+' : ''}${_selectedCoin.change24h.toStringAsFixed(2)}%)';
      final fcStr = 'Прогноз: \$${_targetForecastPrice.toStringAsFixed(pDigits)} (${_targetForecastPct >= 0 ? '+' : ''}${_targetForecastPct.toStringAsFixed(1)}%)';

      await HomeWidget.saveWidgetData<String>('coin_name', '${_selectedCoin.name} (${_selectedCoin.symbol})');
      await HomeWidget.saveWidgetData<String>('coin_price', priceStr);
      await HomeWidget.saveWidgetData<String>('signal_verdict', '$_verdict ($_totalScore/100)');
      await HomeWidget.saveWidgetData<String>('forecast_text', fcStr);
      await HomeWidget.updateWidget(name: 'CryptoWidgetProvider', androidName: 'CryptoWidgetProvider');
    } catch (_) {}
  }

  String _fmt(double v) => v < 1 ? '\$${v.toStringAsFixed(5)}' : '\$${v.toStringAsFixed(2)}';

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SearchSheet(
        coins: _coins,
        onSelect: (c) {
          Navigator.pop(ctx);
          setState(() {
            if (!_coins.any((x) => x.id == c.id)) _coins.insert(0, c);
            _selectedCoin = c;
          });
          _refreshSelectedCoin();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBuy = _totalScore >= 56;
    final isSell = _totalScore <= 44;
    final signalColor = isBuy ? Colors.green : (isSell ? Colors.red : Colors.orange);
    final filteredNews = _newsFilter == 'all' ? _news : _news.where((n) => n.category == _newsFilter).toList();
    final isUp = _targetForecastPct >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CryptoPulse PRO', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          IconButton(icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.dark_mode), onPressed: widget.onToggleTheme),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSelectedCoin,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Выбор монеты
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _coins.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final c = _coins[i];
                  return ChoiceChip(
                    label: Text('${c.symbol} • ${c.name}'),
                    selected: c.id == _selectedCoin.id,
                    selectedColor: cs.primary.withOpacity(0.25),
                    onSelected: (_) {
                      setState(() => _selectedCoin = c);
                      _refreshSelectedCoin();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Вкладки разделов для выбранной криптовалюты (Обзор, Новости, Прогноз)
            Row(
              children: [
                _coinTabButton('📊 Обзор и Сигнал', 0),
                const SizedBox(width: 6),
                _coinTabButton('📰 Новости монеты', 1),
                const SizedBox(width: 6),
                _coinTabButton('📈 Прогноз курса', 2),
              ],
            ),
            const SizedBox(height: 10),

            if (_loading) const LinearProgressIndicator(),

            // ОСНОВНАЯ ВКЛАДКА 0: ОБЗОР И СИГНАЛ
            if (_coinTabIdx == 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_selectedCoin.name} (${_selectedCoin.symbol})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Rank #${_selectedCoin.rank}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(_fmt(_selectedCoin.price), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 12),
                          Text(
                            '${_selectedCoin.change24h >= 0 ? '+' : ''}${_selectedCoin.change24h.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: _selectedCoin.change24h >= 0 ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _officialLinks.entries.map((e) => ActionChip(
                          label: Text(e.key, style: const TextStyle(fontSize: 11)),
                          onPressed: () => launchUrl(Uri.parse(e.value), mode: LaunchMode.externalApplication),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('СИГНАЛ АНАЛИЗА (Рейтинг: $_totalScore/100)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: signalColor.withOpacity(0.15),
                          border: Border.all(color: signalColor, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _verdict,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: signalColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ТЕХНИЧЕСКИЕ ИНДИКАТОРЫ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _indTile('RSI (14)', _rsi.toStringAsFixed(1), _rsi < 32 ? 'Перепродан' : (_rsi > 68 ? 'Перекуплен' : 'Норма')),
                          const SizedBox(width: 8),
                          _indTile('Тренд EMA', _ema9 >= _ema21 ? 'Бычий 📈' : 'Медвежий 📉', 'EMA9 / EMA21'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ВКЛАДКА 1: НОВОСТИ КОНКРЕТНОЙ МОНЕТЫ
            if (_coinTabIdx == 1) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('НОВОСТИ: ${_selectedCoin.symbol}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('${filteredNews.length} публ.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('Все', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 'official', label: Text('Офиц. / GitHub', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 'media', label: Text('СМИ', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {_newsFilter},
                        onSelectionChanged: (s) => setState(() => _newsFilter = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (filteredNews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('Нет свежих новостей по этой монете.')),
                        ),
                      ...filteredNews.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => launchUrl(Uri.parse(n.url), mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(n.source, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary)),
                                    Text(n.sentimentLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: n.sentimentDelta > 0 ? Colors.green : (n.sentimentDelta < 0 ? Colors.red : Colors.grey))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                if (n.body.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],

            // ВКЛАДКА 2: ПРОГНОЗ КУРСА НА ВЫБРАННЫЙ СРОК
            if (_coinTabIdx == 2) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ПРОГНОЗ КУРСА: ${_selectedCoin.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _horizonChip('День', 'day'),
                            const SizedBox(width: 6),
                            _horizonChip('Неделя', 'week'),
                            const SizedBox(width: 6),
                            _horizonChip('Месяц', 'month'),
                            const SizedBox(width: 6),
                            _horizonChip('Год', 'year'),
                            const SizedBox(width: 6),
                            _horizonChip('3 Года', '3years'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(_fmt(_targetForecastPrice), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Изменение: ${isUp ? '+' : ''}${_targetForecastPct.toStringAsFixed(2)}%',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isUp ? Colors.greenAccent : Colors.redAccent),
                            ),
                            const SizedBox(height: 8),
                            Text('Коридор: ${_fmt(_forecastMinPrice)} – ${_fmt(_forecastMaxPrice)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.widgets),
                        label: const Text('Обновить виджет на рабочем столе'),
                        onPressed: () async {
                          await _updateAndroidWidget();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Виджет Android обновлен!')));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coinTabButton(String title, int idx) {
    final active = _coinTabIdx == idx;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _coinTabIdx = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? cs.primary.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: active ? cs.primary : Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? cs.primary : Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _horizonChip(String label, String value) {
    final selected = _selectedForecastHorizon == value;
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: cs.primary.withOpacity(0.25),
      onSelected: (_) {
        setState(() {
          _selectedForecastHorizon = value;
          _updateForecastValues();
        });
      },
    );
  }

  Widget _indTile(String title, String val, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isConnected = false;
  String _walletAddress = '';
  bool _loadingWallet = false;

  Future<void> _connectWeb3Wallet() async {
    setState(() => _loadingWallet = true);
    try {
      final ethereum = js.context['ethereum'];
      if (ethereum != null) {
        final accounts = await js.context.callMethod('eval', ['ethereum.request({ method: "eth_requestAccounts" })']);
        if (accounts != null) {
          final List accList = List.from(accounts as dynamic);
          if (accList.isNotEmpty) {
            _walletAddress = accList[0].toString();
            _isConnected = true;
          }
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _walletAddress = '0x71C...39a8 (Демо-адрес)';
          _isConnected = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _loadingWallet = false);
  }

  void _disconnectWallet() {
    setState(() {
      _isConnected = false;
      _walletAddress = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Web3 Криптокошелек', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              border: Border.all(color: Colors.amber, width: 1.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Безопасность: Никогда не передавайте свою сид-фразу сторонним ботам!',
                    style: TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.account_balance_wallet,
                    size: 54,
                    color: _isConnected ? Colors.green : cs.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isConnected ? 'Кошелек подключен' : 'Web3 Кошелек не подключен',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isConnected ? _walletAddress : 'Подключите MetaMask или Trust Wallet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  if (_loadingWallet)
                    const CircularProgressIndicator()
                  else if (!_isConnected)
                    FilledButton.icon(
                      icon: const Icon(Icons.bolt),
                      label: const Text('Подключить кошелек (My Wallet)'),
                      onPressed: _connectWeb3Wallet,
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Отключить кошелек', style: TextStyle(color: Colors.red)),
                      onPressed: _disconnectWallet,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final List<CoinModel> coins;
  final ValueChanged<CoinModel> onSelect;
  const _SearchSheet({required this.coins, required this.onSelect});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  List<CoinModel> _res = [];
  bool _loading = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _res = widget.coins;
  }

  void _search(String q) {
    _t?.cancel();
    if (q.trim().length < 2) {
      setState(() => _res = widget.coins);
      return;
    }
    _t = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      try {
        final res = await http.get(Uri.parse('https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(q.trim())}'));
        if (res.statusCode == 200) {
          final List coins = jsonDecode(res.body)['coins'] ?? [];
          setState(() {
            _res = coins.take(25).map((c) => CoinModel(
              id: c['id'],
              symbol: (c['symbol'] ?? '').toString().toUpperCase(),
              name: c['name'] ?? '',
              rank: (c['market_cap_rank'] as num?)?.toInt() ?? 999,
            )).toList();
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Поиск по всем монетам...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: _search,
            ),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _res.length,
                itemBuilder: (ctx, i) {
                  final c = _res[i];
                  return ListTile(
                    title: Text('${c.symbol} — ${c.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('#${c.rank}'),
                    onTap: () => widget.onSelect(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
