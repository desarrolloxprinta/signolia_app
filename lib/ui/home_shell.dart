import 'package:flutter/material.dart';
import 'package:signolia_app/core/home_shell_scope.dart'; // <-- IMPORTANTE
import 'package:signolia_app/core/notification_service.dart';

// INICIO (Dashboard)
import 'package:signolia_app/features/home/dashboard_screen.dart';

// ✅ NOTICIAS V2 (nuevo listado)
import 'package:signolia_app/presentation/noticias/widgets/noticias_list_screen.dart';

// EVENTOS y OFERTAS (usa el nombre real que tengas en esos archivos)
import 'package:signolia_app/presentation/eventos/widgets/eventos_list_screen.dart'
    as eventos;
import 'package:signolia_app/presentation/ofertas/widgets/ofertas_list_screen.dart'
    as ofertas;

// PODCASTS (tu listado)
//import 'package:signolia_app/presentation/podcasts/widgets/podcasts_list_screen.dart'
 //   as podcasts;

// PROVEEDORES (antes Rotulistas)
import 'package:signolia_app/features/rotulistas/rotulistas_screen.dart';

// EGG
import '../common/easter_eggs.dart'; // KonamiTabWatcher

// AppBar centralizado y scope de título
import 'package:signolia_app/widgets/signolia_app_bar.dart';
import 'package:signolia_app/core/section_title_scope.dart';



class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.markAppReady();
    });
  }

  static const _tabTitles = <String>[
    'Inicio',
    'Noticias',
    'Eventos',
    'Ofertas',
    //'Podcast',
    'Proveedores',
  ];

  // ⚠️ SIN `const` delante de _KeepAlive si el hijo no es const.
  // ⚠️ Usa alias para garantizar que los símbolos existen.
  late final List<Widget> _pages = [
    const _KeepAlive(child: DashboardScreen()),
    const _KeepAlive(child: NoticiasListScreenV2()),
    _KeepAlive(child: eventos.EventosListScreen()), // si tu clase real se llama distinto, cámbiala aquí
    _KeepAlive(child: ofertas.OfertasListScreen()), // idem
    ////const _KeepAlive(child: podcasts.PodcastsListScreen()),
    const _KeepAlive(child: RotulistasScreen()),
  ];

  final _bucket = PageStorageBucket();
  final KonamiTabWatcher _konami = KonamiTabWatcher(sequence: [1, 2, 1, 2, 1]);

  void _onTapNav(int i) {
    setState(() => _index = i);
    _konami.onTap(i, context);
  }

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget? appBar =
        _index == 0 ? null : SignoliaAppBar(title: _tabTitles[_index], showBack: false);

    return PageStorage(
      bucket: _bucket,
      child: SectionTitleScope(
        title: _tabTitles[_index],
        child: HomeShellScope(
          setIndex: _onTapNav,                // 👈 expone el cambio de tab
        child: Scaffold(                    // 👈 TODO va dentro del child
          appBar: appBar,                   // null en Dashboard → usa su propio AppBar
          body: IndexedStack(
            index: _index,
            children: _pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: _onTapNav,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined),        label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.article_outlined),     label: 'Noticias'),
              BottomNavigationBarItem(icon: Icon(Icons.event_outlined),       label: 'Eventos'),
              BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Ofertas'),
              ////BottomNavigationBarItem(icon: Icon(Icons.mic_none_outlined),    label: 'Podcast'),
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined),         label: 'Proveedores'),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
