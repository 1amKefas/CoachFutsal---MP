import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_place/google_place.dart' as gp;
import 'dart:async'; 
import 'dart:math';



class AturJadwalPage extends StatefulWidget {
  const AturJadwalPage({Key? key}) : super(key: key);

  @override
  State<AturJadwalPage> createState() => _AturJadwalPageState();
}

class _AturJadwalPageState extends State<AturJadwalPage> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  TextEditingController lokasiController = TextEditingController();

  String? editingId;
  List<String> lokasiList = [];
  String? selectedLokasi;
  LatLng? pickedLocation;

  String get formattedDate =>
      selectedDate != null ? DateFormat('dd MMMM yyyy').format(selectedDate!) : 'Isi Tanggal';

  String get formattedTime =>
      selectedTime != null ? selectedTime!.format(context) : 'Isi waktu';

  @override
  void initState() {
    super.initState();
    _loadLokasiList();
  }

  Future<void> _loadLokasiList() async {
    final snapshot = await FirebaseFirestore.instance.collection('lokasi').get();
    setState(() {
      lokasiList = snapshot.docs.map((e) => e['nama'] as String).toList();
    });
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      setState(() {
        selectedTime = time;
      });
    }
  }

  Future<void> _isiLokasiDariGPS() async {
    var status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi diperlukan untuk fitur ini')),
      );
      return;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS belum aktif')),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak permanen')),
        );
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String name = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          lokasiController.text = _shortenPlaceName(name);
        });
      } else {
        setState(() {
          lokasiController.text =
              '${position.latitude}, ${position.longitude}';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
      );
    }
  }

  Future<void> _pickLocationFromMap() async {
    MapLocationResult? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapPickerPage()),
    );
    if (result != null) {
      await FirebaseFirestore.instance.collection('lokasi').add({
        'nama': result.placeName,
        'lat': result.latLng.latitude,
        'lng': result.latLng.longitude,
      });
      setState(() {
        pickedLocation = result.latLng;
        selectedLokasi = result.placeName;
        lokasiList.add(result.placeName);
        lokasiController.text = result.placeName;
      });
    }
  }

  Future<void> _tambahAtauUpdateJadwal() async {
    final lokasiValue = lokasiController.text.isNotEmpty
        ? lokasiController.text
        : (selectedLokasi ?? '');
    if (selectedDate != null && selectedTime != null && lokasiValue.isNotEmpty) {
      final jadwalData = {
        'tanggal': selectedDate,
        'jam': selectedTime!.format(context),
        'lokasi': lokasiValue,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (editingId == null) {
        await FirebaseFirestore.instance.collection('jadwal').add(jadwalData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal berhasil ditambahkan')),
        );
      } else {
        await FirebaseFirestore.instance.collection('jadwal').doc(editingId).update(jadwalData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal berhasil diupdate')),
        );
        editingId = null;
      }
      setState(() {
        selectedDate = null;
        selectedTime = null;
        lokasiController.clear();
        selectedLokasi = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua data terlebih dahulu')),
      );
    }
  }

  Future<void> _hapusJadwal(String id) async {
    await FirebaseFirestore.instance.collection('jadwal').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jadwal berhasil dihapus')),
    );
  }

  // Tambahkan fungsi untuk menghapus lokasi tersimpan dari Firestore dan list lokal
  Future<void> _hapusLokasiTersimpan(String namaLokasi) async {
    // Cari dokumen lokasi berdasarkan nama
    final snapshot = await FirebaseFirestore.instance
        .collection('lokasi')
        .where('nama', isEqualTo: namaLokasi)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      lokasiList.remove(namaLokasi);
      if (selectedLokasi == namaLokasi) {
        selectedLokasi = null;
        lokasiController.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lokasi berhasil dihapus')),
    );
  }

  void _isiFormDariJadwal(DocumentSnapshot doc) {
    setState(() {
      editingId = doc.id;
      selectedDate = (doc['tanggal'] as Timestamp).toDate();
      final jamStr = doc['jam'] as String;
      final jamParts = jamStr.split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(jamParts[0]),
        minute: int.parse(jamParts[1]),
      );
      lokasiController.text = doc['lokasi'];
      selectedLokasi = doc['lokasi'];
    });
  }

  String _shortenPlaceName(String name) {
    List<String> parts = name.split(',');
    String short = parts.take(2).join(',').trim();
    if (short.length > 30) {
      return short.substring(0, 30) + "...";
    }
    return short;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATUR JADWAL', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const BackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const Text('Jam', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: _pickTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const Text('Tempat / Lokasi', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isiLokasiDariGPS,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Isi Lokasi Otomatis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _pickLocationFromMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Pilih di Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                controller: lokasiController,
                readOnly: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  hintText: 'Masukkan Lokasi',
                ),
                style: const TextStyle(
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
           Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedLokasi,
                      hint: const Text('Pilih Lokasi Tersimpan'),
                      items: lokasiList
                          .map((e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(
                                  _shortenPlaceName(e),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedLokasi = val;
                          lokasiController.text = val ?? '';
                        });
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                      ),
                    ),
                  ),
                  // Tombol hapus lokasi
                  if (selectedLokasi != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Hapus lokasi ini',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Lokasi'),
                            content: Text('Yakin ingin menghapus lokasi "$selectedLokasi"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && selectedLokasi != null) {
                          await _hapusLokasiTersimpan(selectedLokasi!);
                        }
                      },
                    ),
                ],
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: _tambahAtauUpdateJadwal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(editingId == null ? 'Tambah Jadwal' : 'Update Jadwal', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Daftar Jadwal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jadwal').orderBy('tanggal').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Terjadi error');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Text('Belum ada jadwal');
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final tanggal = (doc['tanggal'] as Timestamp).toDate();
                      final jam = doc['jam'];
                      final lokasi = doc['lokasi'];
                      return Card(
                        child: ListTile(
                          title: Text('${DateFormat('dd MMM yyyy').format(tanggal)} - $jam'),
                          subtitle: Text(
                            _shortenPlaceName(lokasi),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _isiFormDariJadwal(doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _hapusJadwal(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class MapLocationResult {
  final LatLng latLng;
  final String placeName;
  MapLocationResult({required this.latLng, required this.placeName});
}

class MapPickerPage extends StatefulWidget {
  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

const String googleApiKey = 'AIzaSyAhCh0iMCrhIYikIBQAr-S35FPImAi9Xmg'; // Ganti dengan API key kamu

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? mapController;
  LatLng picked = const LatLng(-6.200000, 106.816666); // Default Jakarta
  String placeName = "Pilih lokasi di peta";
  TextEditingController searchController = TextEditingController();
  LatLng? currentLatLng; // Simpan lokasi user

  late gp.GooglePlace googlePlace;
  List<gp.AutocompletePrediction> predictions = [];
  Set<Polyline> polylines = {};
  StreamSubscription<Position>? positionStream;
  LatLng? userLatLng;

  @override
  void initState() {
    super.initState();
    googlePlace = gp.GooglePlace(googleApiKey);
    _setInitialLocation();
    // Tambahkan ini untuk real-time tracking
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      setState(() {
        userLatLng = LatLng(position.latitude, position.longitude);
        currentLatLng = userLatLng;
      });
      // Optional: update rute jika sudah ada tujuan
      if (picked != null && picked != userLatLng) {
        _showRoute(picked);
      }
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  void autoCompleteSearch(String value) async {
    if (value.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(
        value,
        location: currentLatLng != null
            ? gp.LatLon(currentLatLng!.latitude, currentLatLng!.longitude)
            : null,
        radius: 100000,
        language: 'id',
      );
      print('Place API status: ${result?.status}');
      // print('Place API error: ${result?.errorMessage}'); // Hapus baris ini jika error
      setState(() {
        predictions = result?.predictions ?? [];
      });
    } else {
      setState(() {
        predictions = [];
      });
    }
  }

  Future<void> _selectPrediction(gp.AutocompletePrediction p) async {
    var detail = await googlePlace.details.get(p.placeId!);
    if (detail != null && detail.result != null && detail.result!.geometry != null) {
      final loc = detail.result!.geometry!.location!;
      final latLng = LatLng(loc.lat!, loc.lng!);
      mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      setState(() {
        picked = latLng;
        placeName = p.description ?? '';
        predictions = [];
      });
      await _showRoute(latLng);
    }
  }

  // Fungsi untuk menampilkan rute dari posisi user ke lokasi tujuan
  Future<void> _showRoute(LatLng destination) async {
    if (currentLatLng == null) return;
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey,
      PointLatLng(currentLatLng!.latitude, currentLatLng!.longitude),
      PointLatLng(destination.latitude, destination.longitude),
    );
    if (result.points.isNotEmpty) {
      setState(() {
        polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.blue,
            width: 5,
            points: result.points.map((e) => LatLng(e.latitude, e.longitude)).toList(),
          ),
        };
      });
    }
  }

  Future<void> _setInitialLocation() async {
    try {
      var status = await Permission.location.request();
      if (!status.isGranted) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        picked = userLatLng;
        currentLatLng = userLatLng;
      });
      await _updatePlaceName(userLatLng);

      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(userLatLng));
      }
    } catch (_) {
      // Biarkan default Jakarta jika gagal
    }
  }

  // Fungsi untuk menghitung jarak antara dua titik (dalam kilometer)
  double _distanceInKm(LatLng a, LatLng b) {
    const double earthRadius = 6371; // km
    double dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180.0);
    double dLon = (b.longitude - a.longitude) * (3.141592653589793 / 180.0);

    double lat1 = a.latitude * (3.141592653589793 / 180.0);
    double lat2 = b.latitude * (3.141592653589793 / 180.0);

    double aVal = 
      (sin(dLat / 2) * sin(dLat / 2)) +
      (sin(dLon / 2) * sin(dLon / 2)) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return earthRadius * c;
  }

  Future<List<String>> _getPlaceSuggestions(String pattern) async {
    if (pattern.isEmpty) return [];
    try {
      // Gunakan Google Place Autocomplete agar hasil lebih akurat dan lengkap
      final googlePlace = gp.GooglePlace(googleApiKey);
      final result = await googlePlace.autocomplete.get(
        pattern,
        location: currentLatLng != null
            ? gp.LatLon(currentLatLng!.latitude, currentLatLng!.longitude)
            : null,
        radius: 100000, // 100km
        language: 'id',
      );
      if (result != null && result.predictions != null) {
        return result.predictions!
            .map((p) => p.description ?? '')
            .where((desc) => desc.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _updatePlaceName(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String name = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          placeName = name.length > 40 ? name.substring(0, 40) + "..." : name;
        });
      } else {
        setState(() {
          placeName = "${latLng.latitude}, ${latLng.longitude}";
        });
      }
    } catch (e) {
      setState(() {
        placeName = "${latLng.latitude}, ${latLng.longitude}";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Lokasi di Map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: picked,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              _setInitialLocation();
            },
            onTap: (latLng) {
              setState(() {
                picked = latLng;
              });
              _updatePlaceName(latLng);
            },
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: picked,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              )
            },
            polylines: polylines,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    placeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Cari lokasi...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search)
                        ),
                        onChanged: autoCompleteSearch,
                      ),
                      if (predictions.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: predictions.length,
                            itemBuilder: (context, index) {
                              final p = predictions[index];
                              return ListTile(
                                title: Text(p.description ?? ''),
                                onTap: () => _selectPrediction(p),
                              );
                            },
                          ),
                        ),
                      if (predictions.isEmpty && searchController.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Tidak ada hasil ditemukan.'),
                        ),  
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, MapLocationResult(latLng: picked, placeName: placeName));
        },
        icon: const Icon(Icons.check),
        label: const Text('Pilih Lokasi'),
      ),
    );
  }
}
// ...existing code...