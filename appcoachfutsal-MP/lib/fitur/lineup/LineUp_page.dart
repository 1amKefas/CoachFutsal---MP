import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LineUpPage extends StatefulWidget {
  const LineUpPage({super.key});

  @override
  State<LineUpPage> createState() => _LineUpPageState();
}

class _LineUpPageState extends State<LineUpPage> {
  // Setiap pemain di lapangan: {'player': Map, 'offset': Offset}
  List<Map<String, dynamic>?> fieldPlayers = List.filled(5, null);

  // Fungsi untuk menyingkat nama, contoh: Andra Maulana -> Andra M
  String shortenName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return parts[0];
    return '${parts.first} ${parts.last[0]}';
  }

  // Fungsi untuk mengambil nama depan saja
  String firstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  List<Offset> getDefaultOffsets(double width, double height) {
    return [
      Offset(width * 0.375, height * 0.15),   // depan
      Offset(width * 0.125, height * 0.45),   // kiri
      Offset(width * 0.625, height * 0.45),   // kanan
      Offset(width * 0.375, height * 0.6),    // tengah
      Offset(width * 0.375, height * 0.8),    // keeper
    ];
  }

  @override
  void initState() {
    super.initState();
    // Inisialisasi posisi default jika fieldPlayers kosong
    for (int i = 0; i < fieldPlayers.length; i++) {
      if (fieldPlayers[i] == null) {
        fieldPlayers[i] = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive ukuran lapangan: gunakan tinggi layar - appbar - padding - tinggi pemain cadangan
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final double cadanganHeight = 140; // tinggi area pemain cadangan
    final double verticalPadding = 16.0 * 2 + 24.0; // padding atas bawah + spacing
    final double fieldHeight = screenHeight - appBarHeight - cadanganHeight - verticalPadding;
    final double fieldWidth = screenWidth - 32;
    final List<Offset> defaultOffsets = getDefaultOffsets(fieldWidth, fieldHeight);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: const Text(
          'LINE UP',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Lapangan dan pemain utama (free drag)
            Container(
              width: fieldWidth,
              height: fieldHeight > 300 ? fieldHeight : 300, // minimal 300 biar ga terlalu kecil
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/images/lapangan.png', fit: BoxFit.cover),
                  ),
                  // Render pemain di lapangan (free drag)
                  ...List.generate(fieldPlayers.length, (i) {
                    final data = fieldPlayers[i];
                    if (data == null || data['player'] == null) return const SizedBox.shrink();
                    final Offset offset = data['offset'] ?? defaultOffsets[i];
                    final player = data['player'];
                    final color = i == 4 ? 'blue' : 'red';
                    return Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: Draggable<Map<String, dynamic>>(
                        data: {'index': i, 'player': player},
                        feedback: Material(
                          color: Colors.transparent,
                          child: fieldPlayerBox(firstName(player['name'] ?? ''), color, showInstruction: false),
                        ),
                        childWhenDragging: const SizedBox(width: 80, height: 90),
                        child: GestureDetector(
                          onLongPress: () {
                            setState(() {
                              fieldPlayers[i] = null;
                            });
                          },
                          child: fieldPlayerBox(firstName(player['name'] ?? ''), color, showInstruction: true),
                        ),
                        onDragEnd: (details) {
                          // Hitung posisi relatif terhadap lapangan
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final Offset local = box.globalToLocal(details.offset);
                          setState(() {
                            fieldPlayers[i] = {
                              'player': player,
                              'offset': Offset(
                                local.dx.clamp(0, fieldWidth - 80),
                                local.dy.clamp(0, fieldHeight - 90),
                              ),
                            };
                          });
                        },
                      ),
                    );
                  }),
                  // DragTarget area untuk menerima pemain baru dari cadangan
                  ...List.generate(fieldPlayers.length, (i) {
                    if (fieldPlayers[i] != null) return const SizedBox.shrink();
                    final Offset offset = defaultOffsets[i];
                    final color = i == 4 ? 'blue' : 'red';
                    return Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: DragTarget<Map<String, dynamic>>(
                        onWillAccept: (data) => true,
                        onAccept: (data) {
                          setState(() {
                            fieldPlayers[i] = {
                              'player': data,
                              'offset': offset,
                            };
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            width: 80,
                            height: 90,
                            alignment: Alignment.center,
                            child: Image.asset(
                              color == 'red'
                                  ? 'assets/images/jersey1.png'
                                  : 'assets/images/jersey2.png',
                              height: 70,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Pemain Cadangan (list dari Firestore)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pemain Cadangan',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                // DragTarget untuk menerima pemain dari lapangan ke cadangan
                DragTarget<Map<String, dynamic>>(
                  onWillAccept: (data) => true,
                  onAccept: (data) {
                    setState(() {
                      // Hapus dari fieldPlayers jika ada
                      for (int i = 0; i < fieldPlayers.length; i++) {
                        final fp = fieldPlayers[i];
                        if (fp != null && fp['player']?['id'] == data['id']) {
                          fieldPlayers[i] = null;
                        }
                      }
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('players')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Terjadi error');
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Text('Belum ada pemain');
                        }
                        // Filter pemain yang belum ada di field
                        final cadangan = docs.where((doc) {
                          final player = doc.data() as Map<String, dynamic>;
                          return !fieldPlayers.any((fp) => fp?['player']?['id'] == doc.id);
                        }).toList();

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(cadangan.length, (index) {
                              final doc = cadangan[index];
                              final player = doc.data() as Map<String, dynamic>;
                              final name = shortenName(player['name'] ?? '');
                              return Draggable<Map<String, dynamic>>(
                                data: {
                                  'id': doc.id,
                                  'name': player['name'] ?? '',
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: playerBox(name, index, isFeedback: true),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: playerBox(name, index),
                                ),
                                child: playerBox(name, index),
                              );
                            }),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Info drag ke cadangan
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget kotak pemain cadangan (dengan background putih dan shadow)
  Widget playerBox(String name, int index, {bool isFeedback = false}) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            index < 2
                ? 'assets/images/jersey2.png'
                : 'assets/images/jersey1.png',
            height: 40,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk pemain di lapangan (tanpa background putih, anti overflow)
  Widget fieldPlayerBox(String name, String color, {bool showInstruction = true}) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            color == 'red'
                ? 'assets/images/jersey1.png'
                : 'assets/images/jersey2.png',
            height: 50,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}