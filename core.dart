import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webfeed_plus/webfeed_plus.dart';

const ua = {'User-Agent': 'TechNewsApp/1.0'};

class Source {
  String name, url, type; // type: rss | reddit | hn
  bool on;
  Source(this.name, this.url, this.type, [this.on = true]);
  Map toJson() => {'n': name, 'u': url, 't': type, 'o': on};
  factory Source.fromJson(Map j) => Source(j['n'], j['u'], j['t'], j['o'] ?? true);
}

class Article {
  String title, summary, link, source, content;
  int date;
  String? image;
  Article({required this.title, this.summary = '', required this.link, required this.source, this.content = '', this.date = 0, this.image});
  Map toJson() => {'t': title, 's': summary, 'l': link, 'src': source, 'c': content, 'd': date, 'i': image};
  factory Article.fromJson(Map j) => Article(title: j['t'], summary: j['s'] ?? '', link: j['l'], source: j['src'] ?? '', content: j['c'] ?? '', date: j['d'] ?? 0, image: j['i']);
}

class Repo {
  String name, desc, lang;
  int stars;
  Repo(this.name, this.desc, this.lang, this.stars);
  Map toJson() => {'n': name, 'd': desc, 'l': lang, 's': stars};
  factory Repo.fromJson(Map j) => Repo(j['n'], j['d'] ?? '', j['l'] ?? '', j['s'] ?? 0);
}

String _txt(String? h) => h == null ? '' : (hp.parse(h).documentElement?.text.trim() ?? '');
String? _img(String? h) => h == null ? null : RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(h)?.group(1);

Future<List<Article>> _rss(Source s) async {
  final r = await http.get(Uri.parse(s.url), headers: ua).timeout(const Duration(seconds: 15));
  final body = utf8.decode(r.bodyBytes, allowMalformed: true);
  try {
    return RssFeed.parse(body)
        .items
        .map((i) => Article(
            title: _txt(i.title),
            summary: _txt(i.description),
            link: i.link ?? '',
            source: s.name,
            date: i.pubDate?.millisecondsSinceEpoch ?? 0,
            image: i.enclosure?.url ?? _img(i.content?.value ?? i.description)))
        .where((a) => a.link.isNotEmpty)
        .toList();
  } catch (_) {
    return AtomFeed.parse(body)
        .items
        .map((i) => Article(
            title: _txt(i.title),
            summary: _txt(i.summary),
            link: i.links?.first.href ?? '',
            source: s.name,
            date: i.updated?.millisecondsSinceEpoch ?? 0,
            image: _img(i.content ?? i.summary)))
        .where((a) => a.link.isNotEmpty)
        .toList();
  }
}

Future<List<Article>> _reddit(Source s) async {
  final r = await http.get(Uri.parse('https://www.reddit.com/r/${s.url}/hot.json?limit=25'), headers: ua).timeout(const Duration(seconds: 15));
  final ch = jsonDecode(r.body)['data']['children'] as List;
  return ch.map((c) {
    final d = c['data'];
    final th = d['thumbnail'];
    return Article(
        title: d['title'],
        summary: d['selftext'] ?? '',
        link: d['url'],
        source: s.name,
        date: ((d['created_utc'] as num) * 1000).toInt(),
        image: (th is String && th.startsWith('http')) ? th : null);
  }).toList();
}

Future<List<Article>> _hn(Source s) async {
  final ids = (jsonDecode((await http.get(Uri.parse('https://hacker-news.firebaseio.com/v0/topstories.json'))).body) as List).take(25);
  final items = await Future.wait(ids.map((id) async => jsonDecode((await http.get(Uri.parse('https://hacker-news.firebaseio.com/v0/item/$id.json'))).body)));
  return items
      .where((d) => d != null && d['title'] != null)
      .map((d) => Article(title: d['title'], link: d['url'] ?? 'https://news.ycombinator.com/item?id=${d['id']}', source: s.name, date: (d['time'] as int) * 1000))
      .toList();
}

Future<List<Article>> fetchSource(Source s) async {
  try {
    if (s.type == 'reddit') return await _reddit(s);
    if (s.type == 'hn') return await _hn(s);
    return await _rss(s);
  } catch (_) {
    return [];
  }
}

Future<String> readerText(String url) async {
  final r = await http.get(Uri.parse(url), headers: ua).timeout(const Duration(seconds: 15));
  final doc = hp.parse(utf8.decode(r.bodyBytes, allowMalformed: true));
  final root = doc.querySelector('article') ?? doc.body;
  if (root == null) return '';
  return root.querySelectorAll('p').map((p) => p.text.trim()).where((t) => t.length > 40).join('\n\n');
}

Future<List<Repo>> ghSearch(String q) async {
  final query = q.trim().isEmpty ? 'created:>${DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10)}' : q;
  final r = await http.get(Uri.parse('https://api.github.com/search/repositories?q=${Uri.encodeQueryComponent(query)}&sort=stars&per_page=30'), headers: ua).timeout(const Duration(seconds: 15));
  return (jsonDecode(r.body)['items'] as List).map((d) => Repo(d['full_name'], d['description'] ?? '', d['language'] ?? '', d['stargazers_count'] ?? 0)).toList();
}

final _tr = <String, List<String>>{
  'title': ['أخبار التقنية', 'Tech News'],
  'news': ['الأخبار', 'News'],
  'github': ['جيت هب', 'GitHub'],
  'saved': ['المحفوظات', 'Saved'],
  'settings': ['الإعدادات', 'Settings'],
  'search': ['ابحث...', 'Search...'],
  'empty': ['لا توجد بيانات', 'Nothing here yet'],
  'theme': ['المظهر', 'Theme'],
  'system': ['النظام', 'System'],
  'light': ['فاتح', 'Light'],
  'dark': ['داكن', 'Dark'],
  'language': ['اللغة', 'Language'],
  'notif': ['الإشعارات', 'Notifications'],
  'notif_sub': ['تنبيه عند وصول أخبار جديدة', 'Alert on new articles'],
  'sources': ['إدارة المصادر', 'Manage sources'],
  'add': ['إضافة', 'Add'],
  'cancel': ['إلغاء', 'Cancel'],
  'name': ['الاسم', 'Name'],
  'link': ['الرابط / اسم الـ subreddit', 'URL / subreddit name'],
  'contact': ['تواصل مع المطور', 'Contact developer'],
  'explore': ['استكشاف', 'Explore'],
  'favorites': ['المفضلة', 'Favorites'],
  'downloads': ['التحميلات', 'Downloads'],
  'translate': ['ترجمة', 'Translate'],
  'reader': ['وضع القراءة', 'Reader'],
  'open': ['فتح الأصل', 'Open original'],
  'share': ['مشاركة', 'Share'],
  'saved_to': ['تم الحفظ في', 'Saved to'],
  'failed': ['فشلت العملية', 'Failed'],
  'restore': ['استعادة المصادر الافتراضية', 'Restore default sources'],
  'offline': ['محفوظ للقراءة بدون انترنت', 'Saved for offline reading'],
};

class AppState extends ChangeNotifier {
  late SharedPreferences p;
  final _np = FlutterLocalNotificationsPlugin();
  List<Source> sources = [];
  List<Article> articles = [], saved = [];
  List<Repo> favRepos = [];
  ThemeMode themeMode = ThemeMode.dark;
  String lang = 'ar';
  bool notif = false, loading = false;

  void touch() => notifyListeners();
  bool get ar => lang == 'ar';
  String t(String k) => _tr[k]![ar ? 0 : 1];

  static List<Source> defaults() => [
        Source('TechCrunch', 'https://techcrunch.com/feed/', 'rss'),
        Source('The Verge', 'https://www.theverge.com/rss/index.xml', 'rss'),
        Source('Ars Technica', 'https://feeds.arstechnica.com/arstechnica/index', 'rss'),
        Source('Wired', 'https://www.wired.com/feed/rss', 'rss'),
        Source('Engadget', 'https://www.engadget.com/rss.xml', 'rss'),
        Source('عالم التقنية', 'https://aitnews.com/feed/', 'rss'),
        Source('Reddit r/technology', 'technology', 'reddit'),
        Source('Hacker News', 'top', 'hn'),
      ];

  List<T> _load<T>(String k, T Function(Map) f) => (jsonDecode(p.getString(k) ?? '[]') as List).map((e) => f(e as Map)).toList();
  Future<void> _save(String k, List l) => p.setString(k, jsonEncode(l.map((e) => e.toJson()).toList()));

  Future<void> init() async {
    p = await SharedPreferences.getInstance();
    sources = p.containsKey('sources') ? _load('sources', Source.fromJson) : defaults();
    articles = _load('cache', Article.fromJson);
    saved = _load('saved', Article.fromJson);
    favRepos = _load('repos', Repo.fromJson);
    lang = p.getString('lang') ?? 'ar';
    themeMode = ThemeMode.values[p.getInt('theme') ?? 2];
    notif = p.getBool('notif') ?? false;
    await _np.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    final res = await Future.wait(sources.where((s) => s.on).map(fetchSource));
    final all = res.expand((e) => e).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (all.isNotEmpty) {
      final old = articles.map((a) => a.link).toSet();
      final fresh = all.where((a) => !old.contains(a.link)).length;
      articles = all.take(200).toList();
      await _save('cache', articles);
      if (notif && old.isNotEmpty && fresh > 0) {
        await _np.show(1, t('title'), ar ? '$fresh أخبار جديدة' : '$fresh new articles',
            const NotificationDetails(android: AndroidNotificationDetails('news', 'News')));
      }
    }
    loading = false;
    notifyListeners();
  }

  bool isSaved(Article a) => saved.any((s) => s.link == a.link);

  Future<void> toggleSave(Article a) async {
    if (isSaved(a)) {
      saved.removeWhere((s) => s.link == a.link);
    } else {
      if (a.content.isEmpty) {
        try {
          a.content = await readerText(a.link);
        } catch (_) {}
      }
      saved.insert(0, a);
    }
    await _save('saved', saved);
    notifyListeners();
  }

  bool isFav(Repo r) => favRepos.any((e) => e.name == r.name);
  Future<void> toggleFav(Repo r) async {
    isFav(r) ? favRepos.removeWhere((e) => e.name == r.name) : favRepos.insert(0, r);
    await _save('repos', favRepos);
    notifyListeners();
  }

  Future<void> saveSources() async {
    await _save('sources', sources);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await p.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    lang = l;
    await p.setString('lang', l);
    notifyListeners();
  }

  Future<void> setNotif(bool v) async {
    if (v) {
      await _np.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    notif = v;
    await p.setBool('notif', v);
    notifyListeners();
  }

  Future<Directory> _dlDir() async {
    final b = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    return Directory('${b.path}/downloads').create(recursive: true);
  }

  Future<File> download(String full, void Function(double) cb) async {
    final dir = await _dlDir();
    final req = http.Request('GET', Uri.parse('https://github.com/$full/archive/HEAD.zip'))..headers.addAll(ua);
    final res = await http.Client().send(req);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final f = File('${dir.path}/${full.replaceAll('/', '_')}.zip');
    final sink = f.openWrite();
    int got = 0;
    final total = res.contentLength ?? 0;
    await for (final c in res.stream) {
      sink.add(c);
      got += c.length;
      if (total > 0) cb(got / total);
    }
    await sink.close();
    notifyListeners();
    return f;
  }

  Future<List<File>> listDownloads() async => (await _dlDir()).listSync().whereType<File>().toList();
}

final app = AppState();
