import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PagePenilaianPemain extends StatefulWidget {
  const PagePenilaianPemain({super.key});

  @override
  State<PagePenilaianPemain> createState() => _PagePenilaianPemainState();
}

class _PagePenilaianPemainState extends State<PagePenilaianPemain> {
  String? selectedPosisi;
  String? selectedPemain;
  String? selectedAspek;
  List<Map<String, dynamic>> aspekList = [];
  List<Map<String, dynamic>> kriteriaList = [];
  Map<String, TextEditingController> nilaiControllers = {};

  List<String> posisiList = [];
  List<String> pemainList = [];
  List<String> aspekNamaList = [];

  @override
  void initState() {
    super.initState();
    _loadPosisi();
    _loadAspek();
  }

  Future<void> _loadPosisi() async {
    final snapshot = await FirebaseFirestore.instance.collection('players').get();
    final posisiSet = <String>{};
    for (var doc in snapshot.docs) {
      posisiSet.add(doc['position'] ?? '');
    }
    setState(() {
      posisiList = posisiSet.where((e) => e.isNotEmpty).toList();
    });
  }

  Future<void> _loadPemain() async {
    if (selectedPosisi == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('players')
        .where('position', isEqualTo: selectedPosisi)
        .get();
    setState(() {
      pemainList = snapshot.docs.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> _loadAspek() async {
    final snapshot = await FirebaseFirestore.instance.collection('aspek').get();
    setState(() {
      aspekNamaList = snapshot.docs.map((e) => e['aspek'] as String).toList();
    });
  }

  Future<void> _loadKriteria() async {
    if (selectedAspek == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('kriteria')
        .where('aspek', isEqualTo: selectedAspek)
        .get();
    setState(() {
      kriteriaList = snapshot.docs.map((e) => e.data() as Map<String, dynamic>).toList();
      nilaiControllers.clear();
      for (var kriteria in kriteriaList) {
        nilaiControllers[kriteria['kriteria']] = TextEditingController();
      }
    });
  }

  Future<void> _simpanPenilaian() async {
    if (selectedPosisi == null || selectedPemain == null || selectedAspek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi semua pilihan terlebih dahulu!')),
      );
      return;
    }
    final nilaiMap = <String, dynamic>{};
    for (var kriteria in kriteriaList) {
      final key = kriteria['kriteria'];
      nilaiMap[key] = nilaiControllers[key]?.text ?? '0';
    }
    await FirebaseFirestore.instance.collection('penilaian').add({
      'posisi': selectedPosisi,
      'pemain': selectedPemain,
      'aspek': selectedAspek,
      'nilai': nilaiMap,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Penilaian berhasil disimpan')),
    );
    setState(() {
      for (var c in nilaiControllers.values) {
        c.clear();
      }
    });
  }

  Future<void> _editPenilaian(String docId, Map<String, dynamic> nilaiLama) async {
    for (var k in nilaiLama.keys) {
      nilaiControllers[k]?.text = nilaiLama[k].toString();
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Penilaian'),
        content: SingleChildScrollView(
          child: Column(
            children: kriteriaList.map((kriteria) {
              final key = kriteria['kriteria'];
              return TextFormField(
                controller: nilaiControllers[key],
                decoration: InputDecoration(labelText: key),
                keyboardType: TextInputType.number,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nilaiBaru = <String, dynamic>{};
              for (var kriteria in kriteriaList) {
                final key = kriteria['kriteria'];
                nilaiBaru[key] = nilaiControllers[key]?.text ?? '0';
              }
              await FirebaseFirestore.instance.collection('penilaian').doc(docId).update({
                'nilai': nilaiBaru,
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Penilaian berhasil diupdate')),
              );
              setState(() {});
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusPenilaian(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Penilaian'),
        content: const Text('Yakin ingin menghapus penilaian ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('penilaian').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penilaian berhasil dihapus')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'PENILAIAN PEMAIN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownLabel("Posisi"),
              _buildDropdown(
                value: selectedPosisi,
                hint: "Pilih Posisi",
                items: posisiList,
                onChanged: (val) async {
                  setState(() {
                    selectedPosisi = val;
                    selectedPemain = null;
                  });
                  await _loadPemain();
                },
              ),
              _buildDropdownLabel("Nama Pemain"),
              _buildDropdown(
                value: selectedPemain,
                hint: "Pilih Pemain",
                items: pemainList,
                onChanged: (val) {
                  setState(() {
                    selectedPemain = val;
                  });
                },
              ),
              _buildDropdownLabel("Nama Aspek"),
              _buildDropdown(
                value: selectedAspek,
                hint: "Pilih Aspek",
                items: aspekNamaList,
                onChanged: (val) async {
                  setState(() {
                    selectedAspek = val;
                  });
                  await _loadKriteria();
                },
              ),
              const SizedBox(height: 8),
              // Divider di bawah dropdown Nama Aspek DIHAPUS SESUAI PERMINTAAN
              // const Divider(thickness: 1),
              // const SizedBox(height: 8),
              if (selectedAspek != null && kriteriaList.isNotEmpty)
                ..._buildAspekInputList(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpanPenilaian,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text("Simpan Penilaian"),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 8),
              const Text("Riwayat Penilaian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('penilaian').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Terjadi error');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const Text('Belum ada penilaian');
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final nilai = data['nilai'] as Map<String, dynamic>? ?? {};
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('${data['pemain']} - ${data['aspek']}'),
                          subtitle: Text(nilai.entries.map((e) => '${e.key}: ${e.value}').join(', ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _editPenilaian(doc.id, nilai),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _hapusPenilaian(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          border: InputBorder.none,
        ),
        value: value,
        hint: Text(hint),
        items: items
            .map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ))
            .toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }

  // --- UPDATE: Grid 2x2 Core/Secondary Factor, Judul Aspek Dinamis + Label "Aspek" di kiri (warna sama, tanpa background) dan Divider ---
  List<Widget> _buildAspekInputList() {
    // Pisahkan kriteria core dan secondary
    final core = kriteriaList.where((k) =>
      (k['targetKriteria'] ?? '').toString().toLowerCase().contains('core')).toList();
    final secondary = kriteriaList.where((k) =>
      !(k['targetKriteria'] ?? '').toString().toLowerCase().contains('core')).toList();

    // Helper untuk buat grid row
    Widget gridRow(List<Map<String, dynamic>> items) {
      return Row(
        children: List.generate(2, (i) {
          if (i < items.length) {
            final kriteria = items[i];
            final key = kriteria['kriteria'];
            final factor = kriteria['targetKriteria'] ?? '';
            final color = factor.toString().toLowerCase().contains('core') ? Colors.orange : Colors.blue;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        factor,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nilaiControllers[key],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "Nilai",
                        filled: true,
                        fillColor: Color(0xFFF1F8E9),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Kosong jika tidak ada kriteria
            return const Expanded(child: SizedBox());
          }
        }),
      );
    }

    return [
      // Header: Label "Aspek" di kiri (tanpa background, warna sama dengan nama aspek), lalu nama aspek di kanan
      Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              "Aspek",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black, // Sama dengan nama aspek
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              selectedAspek ?? "Input Nilai Kriteria",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      // Divider di bawah header aspek
      const Divider(thickness: 1),
      const SizedBox(height: 8),
      if (core.isNotEmpty) gridRow(core.length > 2 ? core.sublist(0, 2) : core),
      if (core.length > 2) gridRow(core.sublist(2, core.length)),
      if (secondary.isNotEmpty) gridRow(secondary.length > 2 ? secondary.sublist(0, 2) : secondary),
      if (secondary.length > 2) gridRow(secondary.sublist(2, secondary.length)),
    ];
  }
}