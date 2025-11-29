import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:html' as html; // ← ESTE ES EL IMPORT CLAVE PARA WEB

const String baseUrl = 'http://127.0.0.1:8000'; // ← PARA CHROME/WEB
// const String baseUrl = 'http://10.0.2.2:8000'; // ← Para emulador Android

void main() => runApp(const PaquexpressApp());

class PaquexpressApp extends StatelessWidget {
  const PaquexpressApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquexpress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

// ==================== LOGIN ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController(text: "juan@paquexpress.com");
  final passCtrl = TextEditingController(text: "123456");
  bool loading = false;

  Future<void> login() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'username=${emailCtrl.text}&password=${passCtrl.text}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        await prefs.setInt('agente_id', data['agente_id']);

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaquetesScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Credenciales incorrectas")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("PAQUEXPRESS", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 50),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 16),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock))),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Iniciar Sesión", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LISTA PAQUETES ====================
class PaquetesScreen extends StatefulWidget {
  const PaquetesScreen({super.key});
  @override
  State<PaquetesScreen> createState() => _PaquetesScreenState();
}

class _PaquetesScreenState extends State<PaquetesScreen> {
  List paquetes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarPaquetes();
  }

  Future<void> cargarPaquetes() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final agenteId = prefs.getInt('agente_id') ?? 1;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/paquetes/pendientes/$agenteId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          paquetes = json.decode(response.body);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paquetes Pendientes"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: cargarPaquetes)]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : paquetes.isEmpty
              ? const Center(child: Text("No hay paquetes pendientes"))
              : ListView.builder(
                  itemCount: paquetes.length,
                  itemBuilder: (_, i) {
                    final p = paquetes[i];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping, size: 50, color: Colors.orange),
                        title: Text(p['codigo_seguimiento'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${p['destinatario'] ?? ''}\n${p['direccion'] ?? ''}"),
                        isThreeLine: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetallePaqueteScreen(paquete: p))),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== DETALLE + ENTREGA ====================
class DetallePaqueteScreen extends StatefulWidget {
  final Map paquete;
  const DetallePaqueteScreen({super.key, required this.paquete});
  @override
  State<DetallePaqueteScreen> createState() => _DetallePaqueteScreenState();
}

class _DetallePaqueteScreenState extends State<DetallePaqueteScreen> {
  XFile? foto;
  Position? posicion;
  bool entregando = false;

  Future<void> tomarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera);
    if (picked != null) setState(() => foto = picked);
  }

  Future<void> obtenerGPS() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) await Geolocator.requestPermission();
    final pos = await Geolocator.getCurrentPosition();
    setState(() => posicion = pos);
  }

  Future<void> entregarPaquete() async {
    if (foto == null && !kIsWeb) return;
    if (posicion == null) return;

    setState(() => entregando = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/entrega/completar'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['paquete_id'] = widget.paquete['id_paquete'].toString();
    request.fields['latitud'] = posicion!.latitude.toString();
    request.fields['longitud'] = posicion!.longitude.toString();

    if (foto != null) {
      final bytes = kIsWeb ? await foto!.readAsBytes() : await File(foto!.path).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: foto!.name));
    }

    try {
      final response = await request.send();
      final resp = await response.stream.bytesToString();
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡ENTREGADO!"), backgroundColor: Colors.green));
        Navigator.popUntil(context, (route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $resp")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => entregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.paquete['latitud']?.toDouble() ?? 20.5941;
    final lng = widget.paquete['longitud']?.toDouble() ?? -100.3890;

    return Scaffold(
      appBar: AppBar(title: Text("Paquete ${widget.paquete['codigo_seguimiento']}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Destinatario: ${widget.paquete['destinatario']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Dirección: ${widget.paquete['direccion']}"),
            const SizedBox(height: 20),

            // BOTÓN QUE ABRE GOOGLE MAPS EN CHROME Y MÓVIL
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                  if (kIsWeb) {
                    html.window.open(url, '_blank');
                  } else {
                    // En móvil puedes usar url_launcher si quieres, pero con html.window.open también funciona
                    html.window.open(url, '_blank');
                  }
                },
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text("ABRIR EN GOOGLE MAPS"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: tomarFoto, icon: const Icon(Icons.camera_alt), label: const Text("Tomar foto")),
            if (foto != null) const Text("Foto lista", style: TextStyle(color: Colors.green)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: obtenerGPS, icon: const Icon(Icons.location_on), label: const Text("Capturar GPS")),
            if (posicion != null) Text("GPS: ${posicion!.latitude}, ${posicion!.longitude}", style: TextStyle(color: Colors.green)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: entregando ? null : entregarPaquete,
                child: entregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PAQUETE ENTREGADO", style: TextStyle(fontSize: 22, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}