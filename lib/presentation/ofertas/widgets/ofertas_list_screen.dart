import 'package:flutter/material.dart';
import '../../../features/ofertas/oferta_service.dart';
import '../../../features/ofertas/oferta_model.dart';
import 'oferta_card.dart';
// ajusta el import real

class OfertasListScreen extends StatefulWidget {
  const OfertasListScreen({super.key});

  @override
  State<OfertasListScreen> createState() => _OfertasListScreenState();
}

class _OfertasListScreenState extends State<OfertasListScreen> {
  late Future<List<Oferta>> _future;

  @override
  void initState() {
    super.initState();
    _future = OfertaService().fetchOfertas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: FutureBuilder<List<Oferta>>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return const Center(child: Text("Error al cargar ofertas"));
          }
          final data = s.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text("No hay ofertas disponibles"));
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) => OfertaCard(oferta: data[i]),
          );
        },
      ),
    );
  }
}
