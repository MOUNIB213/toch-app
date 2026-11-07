import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';

const devEmail = 'developer@example.com'; // عدّلها
const devTelegram = 'https://t.me/your_username'; // عدّلها

Future<void> openUrl(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);

String ago(int ms) {
  if (ms == 0) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes}${app.ar ? ' د' : 'm'}';
  if (d.inHours < 24) return '${d.inHours}${app.ar ? ' س' : 'h'}';
  return '${d.inDays}${app.ar ? ' ي' : 'd'}';
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Row(children: [Image.asset('assets/logo.png', height: 32), const SizedBox(width: 8), Text(app.t('title'))])),
          body: IndexedStack(index: i, children: const [NewsPage(), GithubPage(), SavedPage(), SettingsPage()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.newspaper), label: app.t('news')),
              NavigationDestination(icon: const Icon(Icons.code), label: app.t('github')),
              NavigationDestination(icon: const Icon(Icons.bookmark), label: app.t('saved')),
              NavigationDestination(icon: const Icon(Icons.settings), label: app.t('settings')),
            ],
          ),
        ),
      );
}

class ArticleTile extends StatelessWidget {
  final Article a;
  const ArticleTile(this.a, {super.key});
  @override
  Widget build(BuildContext c) => Card(
        child: ListTile(
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ArticlePage(a))),
          leading: a.image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(a.image!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64)))
              : null,
          title: Text(a.title, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text('${a.source} • ${ago(a.date)}'),
          trailing: IconButton(icon: Icon(app.isSaved(a) ? Icons.bookmark : Icons.bookmark_border), onPressed: () => app.toggleSave(a)),
        ),
      );
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsState();
}

class _NewsState extends State<NewsPage> {
  String q = '';
  @override
  void initState() {
    super.initState();
    app.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final l = app.articles.where((a) => q.isEmpty || a.title.toLowerCase().contains(q.toLowerCase())).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: app.t('search'), isDense: true, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30)))),
                onChanged: (v) => setState(() => q = v),
              ),
            ),
            if (app.loading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: app.refresh,
                child: l.isEmpty
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(app.t('empty'))))])
                    : ListView.builder(itemCount: l.length, itemBuilder: (_, i) => ArticleTile(l[i])),
              ),
            ),
          ]);
        },
      );
}

class ArticlePage extends StatefulWidget {
  final Article a;
  const ArticlePage(this.a, {super.key});
  @override
  State<ArticlePage> createState() => _ArticleState();
}

class _ArticleState extends State<ArticlePage> {
  late String title = widget.a.title;
  late String body = widget.a.content.isNotEmpty ? widget.a.content : widget.a.summary;
  bool busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('failed'))));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> reader() => _run(() async {
        final t = await readerText(widget.a.link);
        if (t.isNotEmpty) body = t;
      });

  Future<void> translate() => _run(() async {
        final tr = GoogleTranslator();
        title = (await tr.translate(widget.a.title, to: 'ar')).text;
        final src = body.length > 4000 ? body.substring(0, 4000) : body;
        body = (await tr.translate(src, to: 'ar')).text;
      });

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return ListenableBuilder(
      listenable: app,
      builder: (_, __) => Scaffold(
        appBar: AppBar(actions: [
          IconButton(icon: Icon(app.isSaved(a) ? Icons.bookmark : Icons.bookmark_border), onPressed: () => app.toggleSave(a)),
          IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share('${a.title}\n${a.link}')),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (busy) const LinearProgressIndicator(),
          if (a.image != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(a.image!, errorBuilder: (_, __, ___) => const SizedBox())),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${a.source} • ${ago(a.date)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ActionChip(avatar: const Icon(Icons.chrome_reader_mode, size: 18), label: Text(app.t('reader')), onPressed: busy ? null : reader),
            ActionChip(avatar: const Icon(Icons.translate, size: 18), label: Text(app.t('translate')), onPressed: busy ? null : translate),
            ActionChip(avatar: const Icon(Icons.open_in_browser, size: 18), label: Text(app.t('open')), onPressed: () => openUrl(a.link)),
          ]),
          const SizedBox(height: 12),
          if (a.content.isNotEmpty && app.isSaved(a)) Text(app.t('offline'), style: Theme.of(context).textTheme.labelSmall),
          SelectableText(body, style: const TextStyle(fontSize: 16, height: 1.7)),
        ]),
      ),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => app.saved.isEmpty
            ? Center(child: Text(app.t('empty')))
            : ListView.builder(itemCount: app.saved.length, itemBuilder: (_, i) => ArticleTile(app.saved[i])),
      );
}

class RepoTile extends StatelessWidget {
  final Repo r;
  const RepoTile(this.r, {super.key});

  Future<void> dl(BuildContext c) async {
    final p = ValueNotifier<double>(0);
    showDialog(
      context: c,
      barrierDismissible: false,
      builder: (_) => AlertDialog(title: Text(r.name), content: ValueListenableBuilder<double>(valueListenable: p, builder: (_, v, __) => LinearProgressIndicator(value: v > 0 ? v : null))),
    );
    String msg;
    try {
      final f = await app.download(r.name, (v) => p.value = v);
      msg = '${app.t('saved_to')} ${f.path}';
    } catch (_) {
      msg = app.t('failed');
    }
    if (c.mounted) {
      Navigator.pop(c);
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext c) => Card(
        child: ListTile(
          onTap: () => openUrl('https://github.com/${r.name}'),
          title: Text(r.name),
          subtitle: Text('${r.desc}\n⭐ ${r.stars}${r.lang.isEmpty ? '' : '  •  ${r.lang}'}', maxLines: 4, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(app.isFav(r) ? Icons.favorite : Icons.favorite_border), onPressed: () => app.toggleFav(r)),
            IconButton(icon: const Icon(Icons.download), onPressed: () => dl(c)),
          ]),
        ),
      );
}

class GithubPage extends StatefulWidget {
  const GithubPage({super.key});
  @override
  State<GithubPage> createState() => _GhState();
}

class _GhState extends State<GithubPage> {
  List<Repo> res = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    search('');
  }

  Future<void> search(String q) async {
    setState(() => busy = true);
    try {
      res = await ghSearch(q);
    } catch (_) {
      res = [];
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          TabBar(tabs: [Tab(text: app.t('explore')), Tab(text: app.t('favorites')), Tab(text: app.t('downloads'))]),
          Expanded(
            child: TabBarView(children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    onSubmitted: search,
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: app.t('search'), isDense: true, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30)))),
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                Expanded(child: ListenableBuilder(listenable: app, builder: (_, __) => ListView(children: res.map(RepoTile.new).toList()))),
              ]),
              ListenableBuilder(
                listenable: app,
                builder: (_, __) => app.favRepos.isEmpty ? Center(child: Text(app.t('empty'))) : ListView(children: app.favRepos.map(RepoTile.new).toList()),
              ),
              ListenableBuilder(
                listenable: app,
                builder: (_, __) => FutureBuilder<List<File>>(
                  future: app.listDownloads(),
                  builder: (_, s) {
                    final l = s.data ?? [];
                    if (l.isEmpty) return Center(child: Text(app.t('empty')));
                    return ListView(
                      children: l
                          .map((f) => ListTile(
                                leading: const Icon(Icons.folder_zip),
                                title: Text(f.path.split('/').last),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(f.path)])),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await f.delete();
                                      app.touch();
                                    },
                                  ),
                                ]),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ]),
          ),
        ]),
      );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => ListView(padding: const EdgeInsets.all(8), children: [
          ListTile(title: Text(app.t('theme'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(app.t('system'))),
                ButtonSegment(value: ThemeMode.light, label: Text(app.t('light'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(app.t('dark'))),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setTheme(s.first),
            ),
          ),
          ListTile(title: Text(app.t('language'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {app.lang},
              onSelectionChanged: (s) => app.setLang(s.first),
            ),
          ),
          const Divider(),
          SwitchListTile(title: Text(app.t('notif')), subtitle: Text(app.t('notif_sub')), value: app.notif, onChanged: app.setNotif),
          ListTile(leading: const Icon(Icons.rss_feed), title: Text(app.t('sources')), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesPage()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.email), title: Text(app.t('contact')), subtitle: const Text(devEmail), onTap: () => openUrl('mailto:$devEmail')),
          ListTile(leading: const Icon(Icons.send), title: const Text('Telegram'), onTap: () => openUrl(devTelegram)),
        ]),
      );
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  Future<void> add(BuildContext c) async {
    final n = TextEditingController(), u = TextEditingController();
    String type = 'rss';
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, decoration: InputDecoration(labelText: app.t('name'))),
            TextField(controller: u, decoration: InputDecoration(labelText: app.t('link'))),
            DropdownButton<String>(
              value: type,
              isExpanded: true,
              items: const [DropdownMenuItem(value: 'rss', child: Text('RSS / Atom')), DropdownMenuItem(value: 'reddit', child: Text('Reddit')), DropdownMenuItem(value: 'hn', child: Text('Hacker News'))],
              onChanged: (v) => set(() => type = v!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('cancel'))),
            FilledButton(
              onPressed: () {
                if (n.text.trim().isNotEmpty && (u.text.trim().isNotEmpty || type == 'hn')) {
                  app.sources.add(Source(n.text.trim(), u.text.trim().isEmpty ? 'top' : u.text.trim(), type));
                  app.saveSources();
                  app.refresh();
                }
                Navigator.pop(ctx);
              },
              child: Text(app.t('add')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(app.t('sources')), actions: [
            IconButton(
              tooltip: app.t('restore'),
              icon: const Icon(Icons.restore),
              onPressed: () {
                app.sources = AppState.defaults();
                app.saveSources();
              },
            ),
          ]),
          floatingActionButton: FloatingActionButton(onPressed: () => add(context), child: const Icon(Icons.add)),
          body: ListView(
            children: [
              for (final s in app.sources)
                ListTile(
                  title: Text(s.name),
                  subtitle: Text('${s.type} • ${s.url}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  leading: Switch(value: s.on, onChanged: (v) { s.on = v; app.saveSources(); }),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { app.sources.remove(s); app.saveSources(); }),
                ),
            ],
          ),
        ),
      );
}
