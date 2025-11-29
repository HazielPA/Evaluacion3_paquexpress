import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir Google Maps

// ✅ CORRECCIÓN 1: Usar 127.0.0.1 para entorno web (Chrome)
const String baseUrl = 'http://127.0.0.1:8000'; // Para Chrome/Web
// const String baseUrl = 'http://10.0.2.2:8000'; // Para emulador Android

void main() => runApp(const PaquexpressApp());

class PaquexpressApp extends StatelessWidget {
  const PaquexpressApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquexpress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      // ✅ CORRECCIÓN 2: Inicio directo en PaquetesScreen
      home: const PaquetesScreen(), 
    );
  }
}

// ==================== LOGIN (AHORA IGNORADO COMO PANTALLA INICIAL) ====================
// La clase LoginScreen se deja por si quieres volver a usarla, pero ya no es la pantalla de inicio.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController(text: "juan@paquexpress.com");
  final passCtrl = TextEditingController(text: "12345"); // Asumiendo que usas "12345"
  bool loading = false;

  Future<void> login() async {
    // ... Lógica de Login (No se ejecuta al iniciar la app) ...
  }

  @override
  Widget build(BuildContext context) {
    // ... UI de Login ...
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("PAQUEXPRESS", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 50),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
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

// ==================== LISTA DE PAQUETES ====================
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
    // Usa el ID de agente 1 por defecto al saltar el login
    final agenteId = prefs.getInt('agente_id') ?? 1; 

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/paquetes/pendientes/$agenteId'),
        // ✅ CORRECCIÓN 3: Se elimina la cabecera de Authorization que no se usa en el backend
        // headers: {'Authorization': 'Bearer $token'}, 
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          paquetes = json.decode(response.body);
          loading = false;
        });
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al cargar paquetes: Código ${response.statusCode}")),
            );
          }
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de conexión al cargar paquetes: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paquetes Pendientes (Agente 1)"),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: cargarPaquetes)],
      ),
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
                        onTap: () async {
                           final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetallePaqueteScreen(paquete: p)),
                          );
                          if (result == true) {
                            cargarPaquetes();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// ==================== DETALLE DEL PAQUETE ====================
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
    if (picked != null) {
      setState(() => foto = picked);
    }
  }

  Future<void> obtenerGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Activa el GPS")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permiso de GPS denegado")));
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() => posicion = pos);
  }

  Future<void> abrirMapa() async {
    final lat = widget.paquete['latitud']?.toDouble() ?? 20.5941;
    final lng = widget.paquete['longitud']?.toDouble() ?? -100.3890;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir Google Maps")));
    }
  }

  Future<void> entregarPaquete() async {
    if (foto == null && !kIsWeb) return;
    if (posicion == null) return;

    setState(() => entregando = true);

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/entrega/completar'));
    // ✅ CORRECCIÓN 3: Se elimina la cabecera de Authorization
    // request.headers['Authorization'] = 'Bearer $token'; 
    
    // ✅ CORRECCIÓN 4: Se usa el campo 'id' de la DB, no 'id_paquete'
    request.fields['paquete_id'] = widget.paquete['id'].toString(); 
    request.fields['latitud'] = posicion!.latitude.toString();
    request.fields['longitud'] = posicion!.longitude.toString();

    if (foto != null) {
      final fileBytes = kIsWeb ? await foto!.readAsBytes() : await File(foto!.path).readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: foto!.name);
      request.files.add(multipartFile);
    }

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡ENTREGADO CON ÉXITO!"), backgroundColor: Colors.green));
        // Recarga la lista de paquetes
        Navigator.pop(context, true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $respStr")));
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: abrirMapa,
                icon: const Icon(Icons.map),
                label: const Text("Abrir en Google Maps"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: tomarFoto, icon: const Icon(Icons.camera_alt), label: const Text("Tomar foto")),
            if (foto != null) const Text("Foto lista", style: TextStyle(color: Colors.green)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: obtenerGPS, icon: const Icon(Icons.location_on), label: const Text("Capturar GPS")),
            if (posicion != null) Text("GPS: ${posicion!.latitude}, ${posicion!.longitude}", style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                // Solo habilitar si se cumplen las condiciones
                onPressed: entregando ? null : (foto != null && posicion != null) ? entregarPaquete : null, 
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